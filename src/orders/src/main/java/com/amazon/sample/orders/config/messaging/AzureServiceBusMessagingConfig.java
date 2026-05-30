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
 *   <li>{@link MessagingProvider} — the Azure provider wired with the sender,
 *       Jackson {@link ObjectMapper}, {@link MeterRegistry}, and queue
 *       name.</li>
 *   <li>{@code azureServiceBus} {@link HealthIndicator} — probes the cached
 *       {@link ServiceBusSenderClient} via {@code createMessageBatch()}
 *       (Send-only SAS compatible). Spring uses the bean name as the health
 *       component name, so this surfaces under
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
    return new ServiceBusClientBuilder().connectionString(
      properties.getConnectionString()
    );
  }

  @Bean
  public ServiceBusSenderClient serviceBusSenderClient(
    ServiceBusClientBuilder builder
  ) {
    return builder.sender().queueName(properties.getQueueName()).buildClient();
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
    ServiceBusSenderClient sender
  ) {
    return new AzureServiceBusHealthIndicator(sender, properties.getQueueName());
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

    CloudWatchMeterRegistry registry = new SuffixStrippingCloudWatchMeterRegistry(
      config,
      cloudWatchAsyncClient
    );

    // Allowlist filter: rename the failures counter and deny everything
    // else so unrelated Micrometer meters (HTTP, JVM, Spring Boot
    // actuator, etc.) are NOT exported to CloudWatch (requirement 6.2).
    registry
      .config()
      .meterFilter(
        new MeterFilter() {
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
        }
      );

    return registry;
  }

  /**
   * {@link CloudWatchMeterRegistry} subclass that strips the Micrometer
   * meter-type suffix (e.g. {@code .count}, {@code .value},
   * {@code .sum}) from the literal allowlist metric name
   * {@value #CLOUDWATCH_METRIC_NAME} before the {@link MetricDatum} is
   * built, so the published CloudWatch metric exactly matches the name
   * the Terraform alarm watches.
   *
   * <p><b>Why this exists.</b> Micrometer's
   * {@code CloudWatchMeterRegistry.Batch.getMetricName(Meter.Id, String)}
   * (1.15.3) constructs the published metric name as
   * {@code id.getName() + "." + suffix} and then runs the result through
   * {@link NamingConvention#name(String,
   * io.micrometer.core.instrument.Meter.Type, String)}. The suffix is
   * appended <i>after</i> our production {@link MeterFilter#map(Meter.Id)}
   * has already renamed
   * {@code orders.azure.publish.failures} to
   * {@value #CLOUDWATCH_METRIC_NAME}, so without this override the
   * registry would publish the allowlist name with a {@code .count}
   * suffix appended &mdash; a name the Terraform alarm
   * {@code retail-store-ecs-orders-azure-publish-failures} (which targets
   * the unsuffixed metric name with no dimension filter) does not match.
   *
   * <p><b>Which meters are affected.</b> Only the renamed allowlist
   * counter. The {@link MeterFilter} above DENIES every meter whose name
   * is not {@value #CLOUDWATCH_METRIC_NAME}, so by the time this
   * convention's {@link NamingConvention#name(String,
   * io.micrometer.core.instrument.Meter.Type, String)} is invoked, the
   * input is guaranteed to be either the literal
   * {@value #CLOUDWATCH_METRIC_NAME} (no suffix needed) or
   * {@value #CLOUDWATCH_METRIC_NAME} followed by {@code "." + suffix}
   * appended by {@code Batch.getMetricName}. Names that match neither
   * form are passed through unchanged, so this override cannot
   * accidentally rewrite some other meter's name if the allowlist is
   * ever broadened.
   *
   * <p><b>Why suffix removal is safe.</b> The {@link MeterFilter} is the
   * production source of truth for the published metric name; the
   * Micrometer-default suffixing is a naming convention that fights the
   * production design (it presumes a multi-meter Cartesian product like
   * {@code base.count}, {@code base.sum}, {@code base.avg} — none of
   * which the orders publisher emits, since only a single
   * {@link io.micrometer.core.instrument.Counter} is registered, and the
   * allowlist filter denies everything else).
   *
   * <p><b>Why a {@link NamingConvention} and not a
   * {@code metricData(Counter)} override.</b> In Micrometer 1.15.3
   * {@code CloudWatchMeterRegistry.metricData()},
   * {@code CloudWatchMeterRegistry.Batch}, and
   * {@code Batch.getMetricName(Meter.Id, String)} are all
   * package-private and cannot be overridden from outside
   * {@code io.micrometer.cloudwatch2}. The only public override surface
   * the registry exposes is {@code config().namingConvention(...)}, and
   * because {@code Batch.getMetricName} routes the already-suffixed name
   * through that convention, this is the smallest viable Approach A
   * intercept point for this pinned version.
   *
   * @see AzureServiceBusCloudWatchMetricNameTest
   */
  static final class SuffixStrippingCloudWatchMeterRegistry
    extends CloudWatchMeterRegistry {

    private static final String SUFFIX_PREFIX = CLOUDWATCH_METRIC_NAME + ".";

    SuffixStrippingCloudWatchMeterRegistry(
      CloudWatchConfig config,
      CloudWatchAsyncClient cloudWatchAsyncClient
    ) {
      super(config, Clock.SYSTEM, cloudWatchAsyncClient);
      // Identity naming for everything else (no dot-to-camel-case
      // mangling), with one targeted exception: strip the Micrometer
      // meter-type suffix from the literal allowlist metric name so the
      // CloudWatch alarm matches.
      config()
        .namingConvention(
          new NamingConvention() {
            @Override
            public String name(
              String name,
              Meter.Type type,
              String baseUnit
            ) {
              if (name == null) {
                return null;
              }
              if (CLOUDWATCH_METRIC_NAME.equals(name)) {
                return CLOUDWATCH_METRIC_NAME;
              }
              if (name.startsWith(SUFFIX_PREFIX)) {
                return CLOUDWATCH_METRIC_NAME;
              }
              return name;
            }
          }
        );
    }
  }
}
