/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

package com.amazon.sample.orders.config.messaging;

import com.amazon.sample.orders.messaging.MessagingProvider;
import com.amazon.sample.orders.messaging.azureservicebus.AzureServiceBusHealthIndicator;
import com.amazon.sample.orders.messaging.azureservicebus.AzureServiceBusMessagingProvider;
import com.azure.messaging.servicebus.ServiceBusClientBuilder;
import com.azure.messaging.servicebus.ServiceBusSenderClient;
import com.azure.messaging.servicebus.administration.ServiceBusAdministrationClient;
import com.azure.messaging.servicebus.administration.ServiceBusAdministrationClientBuilder;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.cloudwatch2.CloudWatchConfig;
import io.micrometer.cloudwatch2.CloudWatchMeterRegistry;
import io.micrometer.core.instrument.Clock;
import io.micrometer.core.instrument.Meter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.config.MeterFilter;
import io.micrometer.core.instrument.config.MeterFilterReply;
import io.micrometer.core.instrument.config.NamingConvention;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.BeanCreationException;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.services.cloudwatch.CloudWatchAsyncClient;

/**
 * Wires the Azure Service Bus {@link MessagingProvider} when
 * {@code retail.orders.messaging.provider=azureservicebus}.
 *
 * <p>Bean wiring (mirrors the existing RabbitMQ and SQS configurations):
 * <ul>
 *   <li>{@link ServiceBusClientBuilder} — built from
 *       {@code properties.getConnectionString()}. The Azure SDK uses
 *       AMQP-over-TLS by default for any {@code Endpoint=sb://} connection
 *       string; no transport override is configured (requirement 4.5).</li>
 *   <li>{@link ServiceBusSenderClient} — synchronous sender bound to
 *       {@code properties.getQueueName()}.</li>
 *   <li>{@link ServiceBusAdministrationClient} — used solely by the health
 *       indicator to call {@code getQueueRuntimeProperties}.</li>
 *   <li>{@link MessagingProvider} — the Azure provider wired with the sender,
 *       Jackson {@link ObjectMapper}, {@link MeterRegistry}, and queue
 *       name.</li>
 *   <li>{@code azureServiceBus} {@link HealthIndicator} — Spring uses the
 *       bean name as the health component name, so this surfaces under
 *       {@code /actuator/health/azureServiceBus} (requirement 5.1).</li>
 * </ul>
 *
 * <p>Constructor-time validation (requirement 1.5, 4.5, 4.6, 9.2): the
 * connection string MUST start with {@code Endpoint=sb://}. The
 * {@link jakarta.validation.constraints.NotBlank @NotBlank} on
 * {@link AzureServiceBusProperties#getConnectionString()} rejects empty
 * values, but Spring Boot binding throws a {@code BindValidationException}
 * whose message does not name the property cleanly; the explicit prefix
 * check here fails fast with a {@link BeanCreationException} that names the
 * offending property and rules out non-TLS endpoints in a single step.
 *
 * <p>This configuration is absent when the active provider is anything
 * other than {@code azureservicebus} (requirement 5.4, 8.4).
 */
@Configuration
@Slf4j
@EnableConfigurationProperties(AzureServiceBusProperties.class)
@ConditionalOnProperty(
  prefix = MessagingProperties.PREFIX,
  name = "provider",
  havingValue = "azureservicebus"
)
public class AzureServiceBusMessagingConfig {

  private static final String CONNECTION_STRING_PROPERTY =
    "retail.orders.messaging.azureservicebus.connectionString";

  private static final String REQUIRED_CONNECTION_STRING_PREFIX =
    "Endpoint=sb://";

  /** CloudWatch namespace for orders-service metrics (requirement 6.1). */
  private static final String CLOUDWATCH_NAMESPACE = "RetailStore/Orders";

  /** Source Micrometer meter name registered by the provider. */
  private static final String FAILURES_METER_NAME =
    "orders.azure.publish.failures";

  /** CloudWatch metric name the alarm in Terraform targets. */
  private static final String CLOUDWATCH_METRIC_NAME =
    "OrdersAzurePublishFailures";

  private final AzureServiceBusProperties properties;

  public AzureServiceBusMessagingConfig(AzureServiceBusProperties properties) {
    this.properties = properties;
    validateConnectionString(properties.getConnectionString());
  }

  /**
   * Fails fast at bean construction so the offending property is named in
   * the startup error. Catches both the missing-secret invariant
   * (requirement 1.5) and the TLS-only invariant (requirement 4.5, 4.6):
   * any value that does not start with {@code Endpoint=sb://} either is
   * blank, points at a non-Service-Bus host, or attempts a non-TLS scheme.
   */
  private static void validateConnectionString(String connectionString) {
    if (
      connectionString == null ||
      !connectionString.startsWith(REQUIRED_CONNECTION_STRING_PREFIX)
    ) {
      throw new BeanCreationException(
        "Invalid Azure Service Bus configuration: " +
        CONNECTION_STRING_PROPERTY +
        " must be set and must start with '" +
        REQUIRED_CONNECTION_STRING_PREFIX +
        "' (TLS-only AMQPS endpoint). The value itself is not logged."
      );
    }
  }

  @Bean
  public ServiceBusClientBuilder serviceBusClientBuilder() {
    log.info("Using Azure Service Bus messaging");
    // No transportType override: the SDK defaults to AMQP-over-TLS for
    // Endpoint=sb:// connection strings (requirement 4.5).
    return new ServiceBusClientBuilder()
      .connectionString(properties.getConnectionString());
  }

  @Bean
  public ServiceBusSenderClient serviceBusSenderClient(
    ServiceBusClientBuilder builder
  ) {
    return builder
      .sender()
      .queueName(properties.getQueueName())
      .buildClient();
  }

  @Bean
  public ServiceBusAdministrationClient serviceBusAdministrationClient() {
    // The administration client is built from a separate builder because
    // ServiceBusClientBuilder does not expose a management client.
    return new ServiceBusAdministrationClientBuilder()
      .connectionString(properties.getConnectionString())
      .buildClient();
  }

  @Bean
  public MessagingProvider messagingProvider(
    ServiceBusSenderClient sender,
    ObjectMapper mapper,
    MeterRegistry registry
  ) {
    return new AzureServiceBusMessagingProvider(
      sender,
      mapper,
      registry,
      properties.getQueueName()
    );
  }

  /**
   * Bean named {@code azureServiceBus} so Spring Boot Actuator surfaces it
   * under that component name on {@code /actuator/health}
   * (requirement 5.1).
   */
  @Bean(name = "azureServiceBus")
  public HealthIndicator azureServiceBusHealthIndicator(
    ServiceBusAdministrationClient admin
  ) {
    return new AzureServiceBusHealthIndicator(
      admin,
      properties.getQueueName()
    );
  }

  /**
   * Exports only the {@code orders.azure.publish.failures} counter to
   * CloudWatch under namespace {@code RetailStore/Orders} as metric name
   * {@code OrdersAzurePublishFailures} (requirement 6.1).
   *
   * <p>The IAM permission to call {@code cloudwatch:PutMetricData} is
   * granted today by the AWS-managed {@code CloudWatchAgentServerPolicy}
   * already attached to the orders ECS task role whenever
   * {@code application_signals_enabled = true} (the default in
   * {@code terraform/ecs/default/}). See
   * {@code terraform/lib/ecs/service/iam.tf} →
   * {@code aws_iam_role_policy_attachment.cloudwatch_agent_server_policy}.
   * No additional IAM action is required for this feature today; if
   * Application Signals is ever turned off, a follow-up IAM task is needed
   * to grant {@code cloudwatch:PutMetricData} on its own.
   */
  @Bean
  public CloudWatchAsyncClient cloudWatchAsyncClient() {
    return CloudWatchAsyncClient.create();
  }

  @Bean
  public CloudWatchMeterRegistry cloudWatchMeterRegistry(
    CloudWatchAsyncClient cloudWatchAsyncClient
  ) {
    CloudWatchConfig config = new CloudWatchConfig() {
      private final Map<String, String> values = Map.of(
        "cloudwatch.namespace",
        CLOUDWATCH_NAMESPACE,
        // Default Micrometer step is 1 minute; explicit for clarity.
        "cloudwatch.step",
        "PT1M"
      );

      @Override
      public String get(String key) {
        return values.get(key);
      }
    };

    CloudWatchMeterRegistry registry = new CloudWatchMeterRegistry(
      config,
      Clock.SYSTEM,
      cloudWatchAsyncClient
    );

    // Identity naming so the renamed meter id is published to CloudWatch
    // verbatim (no dot-to-camel-case mangling).
    registry.config().namingConvention(NamingConvention.identity);

    // Allowlist filter: rename the failures counter and deny everything
    // else so unrelated Micrometer meters (HTTP, JVM, Spring Boot
    // actuator, etc.) are NOT exported to CloudWatch (requirement 6.2).
    registry.config().meterFilter(new MeterFilter() {
      @Override
      public Meter.Id map(Meter.Id id) {
        if (FAILURES_METER_NAME.equals(id.getName())) {
          return id.withName(CLOUDWATCH_METRIC_NAME);
        }
        return id;
      }

      @Override
      public MeterFilterReply accept(Meter.Id id) {
        return CLOUDWATCH_METRIC_NAME.equals(id.getName())
          ? MeterFilterReply.ACCEPT
          : MeterFilterReply.DENY;
      }
    });

    return registry;
  }
}
