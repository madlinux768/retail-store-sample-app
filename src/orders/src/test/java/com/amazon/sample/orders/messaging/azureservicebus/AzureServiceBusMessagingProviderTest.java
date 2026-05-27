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

package com.amazon.sample.orders.messaging.azureservicebus;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import com.amazon.sample.events.orders.Order;
import com.amazon.sample.events.orders.OrderCancelledEvent;
import com.amazon.sample.events.orders.OrderCreatedEvent;
import com.amazon.sample.orders.entities.OrderItemEntity;
import com.azure.messaging.servicebus.ServiceBusMessage;
import com.azure.messaging.servicebus.ServiceBusSenderClient;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.networknt.schema.JsonSchema;
import com.networknt.schema.JsonSchemaFactory;
import com.networknt.schema.SpecVersion;
import com.networknt.schema.ValidationMessage;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.io.IOException;
import java.io.Serializable;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArrayList;
import org.apache.logging.log4j.Level;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.core.Filter;
import org.apache.logging.log4j.core.Layout;
import org.apache.logging.log4j.core.LogEvent;
import org.apache.logging.log4j.core.Logger;
import org.apache.logging.log4j.core.LoggerContext;
import org.apache.logging.log4j.core.appender.AbstractAppender;
import org.apache.logging.log4j.core.config.Configuration;
import org.apache.logging.log4j.core.config.LoggerConfig;
import org.apache.logging.log4j.core.config.Property;
import org.apache.logging.log4j.core.layout.PatternLayout;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * Unit tests for {@link AzureServiceBusMessagingProvider}.
 *
 * <p>These tests cover the five oracles named in the design (round-trip
 * parity, schema validity, single-counter-per-failure, never-rethrow-with-
 * raw-Azure-exception, no secret material in logs).
 */
class AzureServiceBusMessagingProviderTest {

  private static final String QUEUE_NAME = "orders-events";

  private ServiceBusSenderClient sender;
  private ObjectMapper mapper;
  private MeterRegistry registry;
  private AzureServiceBusMessagingProvider provider;

  @BeforeEach
  void setUp() {
    sender = mock(ServiceBusSenderClient.class);
    mapper = new ObjectMapper();
    registry = new SimpleMeterRegistry();
    provider = new AzureServiceBusMessagingProvider(
      sender,
      mapper,
      registry,
      QUEUE_NAME
    );
  }

  // ------------------------------------------------------------------
  // 7.1 Message shape: contentType, applicationProperties.eventType, body
  // ------------------------------------------------------------------

  @Test
  void publishOrderCreatedEvent_setsContentTypeEventTypeAndJsonBody()
    throws IOException {
    OrderCreatedEvent event = sampleOrderCreatedEvent();

    provider.publishEvent(event);

    ServiceBusMessage sent = captureSentMessage();
    assertThat(sent.getContentType()).isEqualTo("application/json");
    assertThat(sent.getApplicationProperties())
      .containsEntry("eventType", "OrderCreatedEvent");
    assertThat(sent.getBody().toString())
      .isEqualTo(mapper.writeValueAsString(event));
  }

  @Test
  void publishOrderCancelledEvent_setsContentTypeEventTypeAndJsonBody()
    throws IOException {
    OrderCancelledEvent event = sampleOrderCancelledEvent();

    provider.publishEvent(event);

    ServiceBusMessage sent = captureSentMessage();
    assertThat(sent.getContentType()).isEqualTo("application/json");
    assertThat(sent.getApplicationProperties())
      .containsEntry("eventType", "OrderCancelledEvent");
    assertThat(sent.getBody().toString())
      .isEqualTo(mapper.writeValueAsString(event));
  }

  // ------------------------------------------------------------------
  // 7.2 Failure path: counter increments exactly once and exception rethrown
  // ------------------------------------------------------------------

  @Test
  void publishEvent_whenSenderThrows_incrementsCounterOnceAndRethrows() {
    RuntimeException brokerError = new RuntimeException("simulated broker error");
    doThrow(brokerError).when(sender).sendMessage(any(ServiceBusMessage.class));

    OrderCreatedEvent event = sampleOrderCreatedEvent();

    assertThatThrownBy(() -> provider.publishEvent(event))
      .isInstanceOf(MessagingPublishException.class)
      .hasCause(brokerError);

    Counter counter = registry
      .get("orders.azure.publish.failures")
      .tag("queue", QUEUE_NAME)
      .counter();
    assertThat(counter.count()).isEqualTo(1.0d);
    verify(sender, times(1)).sendMessage(any(ServiceBusMessage.class));
  }

  // ------------------------------------------------------------------
  // 7.3 No secret in logs on failure
  // ------------------------------------------------------------------

  @Test
  void publishEvent_failureLogs_neverContainConnectionStringOrSharedAccessKey() {
    // The Azure SDK can wrap a connection-string fragment into the exception
    // message it throws (for example, an authentication error). We simulate
    // that worst-case by making the underlying cause's message contain
    // both forbidden tokens, so the assertion proves the provider does NOT
    // forward exception messages or stack traces into its log line.
    String forbiddenSecret =
      "Endpoint=sb://example.servicebus.windows.net/;SharedAccessKeyName=fake;"
      + "SharedAccessKey=ZmFrZQ==";
    RuntimeException brokerError = new RuntimeException(
      "auth failed: " + forbiddenSecret
    );
    doThrow(brokerError).when(sender).sendMessage(any(ServiceBusMessage.class));

    CapturingAppender appender = CapturingAppender.attach(
      AzureServiceBusMessagingProvider.class
    );
    try {
      OrderCreatedEvent event = sampleOrderCreatedEvent();
      assertThatThrownBy(() -> provider.publishEvent(event))
        .isInstanceOf(MessagingPublishException.class);

      String captured = appender.renderedText();
      assertThat(captured)
        .as("error log should contain the queue name and event type")
        .contains(QUEUE_NAME)
        .contains("OrderCreatedEvent");
      assertThat(captured)
        .as("error log must never contain `Endpoint=sb://`")
        .doesNotContain("Endpoint=sb://");
      assertThat(captured)
        .as("error log must never contain `SharedAccessKey=`")
        .doesNotContain("SharedAccessKey=");
    } finally {
      appender.detach();
    }
  }

  // ------------------------------------------------------------------
  // 7.4 JSON round-trip parity for both event types
  // ------------------------------------------------------------------

  @Test
  void publishOrderCreatedEvent_jsonBodyRoundTripsToEqualOrderIdAndItems()
    throws IOException {
    OrderCreatedEvent event = sampleOrderCreatedEvent();
    provider.publishEvent(event);

    String body = captureSentMessage().getBody().toString();
    OrderCreatedEvent decoded = mapper.readValue(body, OrderCreatedEvent.class);

    assertThat(decoded.getOrder().getId()).isEqualTo(event.getOrder().getId());
    // OrderItemEntity has no equals() override, so use AssertJ's recursive
    // comparison on the field values to express element-wise equality.
    assertThat(decoded.getOrder().getOrderItems())
      .usingRecursiveComparison()
      .isEqualTo(event.getOrder().getOrderItems());
  }

  @Test
  void publishOrderCancelledEvent_jsonBodyRoundTripsToEqualOrderIdAndItems()
    throws IOException {
    OrderCancelledEvent event = sampleOrderCancelledEvent();
    provider.publishEvent(event);

    String body = captureSentMessage().getBody().toString();
    OrderCancelledEvent decoded = mapper.readValue(
      body,
      OrderCancelledEvent.class
    );

    assertThat(decoded.getOrder().getId()).isEqualTo(event.getOrder().getId());
    assertThat(decoded.getOrder().getOrderItems())
      .usingRecursiveComparison()
      .isEqualTo(event.getOrder().getOrderItems());
  }

  // ------------------------------------------------------------------
  // 7.5 JSON-schema validity for produced bodies
  // ------------------------------------------------------------------

  @Test
  void publishOrderCreatedEvent_jsonBodyValidatesAgainstSchema()
    throws IOException {
    OrderCreatedEvent event = sampleOrderCreatedEvent();
    provider.publishEvent(event);

    String body = captureSentMessage().getBody().toString();
    Set<ValidationMessage> errors = validateAgainst(
      "events/order-created-event.schema.json",
      body
    );

    assertThat(errors)
      .as("body should validate against order-created-event.schema.json")
      .isEmpty();
  }

  @Test
  void publishOrderCancelledEvent_jsonBodyValidatesAgainstSchema()
    throws IOException {
    OrderCancelledEvent event = sampleOrderCancelledEvent();
    provider.publishEvent(event);

    String body = captureSentMessage().getBody().toString();
    Set<ValidationMessage> errors = validateAgainst(
      "events/order-cancelled-event.schema.json",
      body
    );

    assertThat(errors)
      .as("body should validate against order-cancelled-event.schema.json")
      .isEmpty();
  }

  // ------------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------------

  private ServiceBusMessage captureSentMessage() {
    ArgumentCaptor<ServiceBusMessage> captor = ArgumentCaptor.forClass(
      ServiceBusMessage.class
    );
    verify(sender).sendMessage(captor.capture());
    return captor.getValue();
  }

  private static OrderCreatedEvent sampleOrderCreatedEvent() {
    OrderCreatedEvent e = new OrderCreatedEvent();
    e.setOrder(sampleOrder("order-created-id"));
    return e;
  }

  private static OrderCancelledEvent sampleOrderCancelledEvent() {
    OrderCancelledEvent e = new OrderCancelledEvent();
    e.setOrder(sampleOrder("order-cancelled-id"));
    return e;
  }

  private static Order sampleOrder(String id) {
    Order order = new Order();
    order.setId(id);
    List<OrderItemEntity> items = new ArrayList<>();
    items.add(new OrderItemEntity("product-1", 2, 50, 100));
    items.add(new OrderItemEntity("product-2", 1, 25, 25));
    order.setOrderItems(items);
    return order;
  }

  /**
   * Loads the JSON schema from the source tree (orders/events/) and
   * validates the given JSON document against it. The schemas use
   * {@code $ref} to a sibling {@code order.schema.json}, which the
   * networknt validator resolves through the file system handler when
   * the schema is loaded by URI.
   */
  private static Set<ValidationMessage> validateAgainst(
    String schemaRelativePath,
    String json
  ) throws IOException {
    Path schemaFile = Path.of(schemaRelativePath).toAbsolutePath();
    JsonSchemaFactory factory = JsonSchemaFactory.getInstance(
      SpecVersion.VersionFlag.V7
    );
    JsonSchema schema = factory.getSchema(schemaFile.toUri());
    JsonNode node = new ObjectMapper().readTree(json);
    return schema.validate(node);
  }

  /**
   * Minimal Log4j2 appender that captures formatted log events. Attached
   * to a specific logger via {@link #attach(Class)} for the duration of a
   * single test.
   */
  private static final class CapturingAppender extends AbstractAppender {

    private final List<String> messages = new CopyOnWriteArrayList<>();
    private final LoggerContext context;
    private final LoggerConfig loggerConfig;
    private final Level previousLevel;

    private CapturingAppender(
      String name,
      Layout<? extends Serializable> layout,
      LoggerContext context,
      LoggerConfig loggerConfig,
      Level previousLevel
    ) {
      super(name, (Filter) null, layout, true, Property.EMPTY_ARRAY);
      this.context = context;
      this.loggerConfig = loggerConfig;
      this.previousLevel = previousLevel;
    }

    static CapturingAppender attach(Class<?> loggerClass) {
      LoggerContext ctx = (LoggerContext) LogManager.getContext(false);
      Configuration cfg = ctx.getConfiguration();
      Logger logger = ctx.getLogger(loggerClass.getName());

      // Use a dedicated LoggerConfig for this logger so that adding our
      // appender doesn't pollute the root logger config with a permanent
      // appender reference.
      LoggerConfig existing = cfg.getLoggerConfig(loggerClass.getName());
      LoggerConfig dedicated;
      Level previousLevel;
      if (existing.getName().equals(loggerClass.getName())) {
        dedicated = existing;
        previousLevel = existing.getLevel();
      } else {
        previousLevel = existing.getLevel();
        dedicated = new LoggerConfig(
          loggerClass.getName(),
          Level.ALL,
          true
        );
        cfg.addLogger(loggerClass.getName(), dedicated);
      }

      Layout<? extends Serializable> layout = PatternLayout
        .newBuilder()
        .withPattern("%level %msg%n")
        .build();
      CapturingAppender appender = new CapturingAppender(
        "Capturing-" + loggerClass.getSimpleName(),
        layout,
        ctx,
        dedicated,
        previousLevel
      );
      appender.start();
      cfg.addAppender(appender);
      dedicated.addAppender(appender, Level.ALL, null);
      ctx.updateLoggers();

      // Make sure the captor sees ERROR-level events even when the
      // global root level is set higher.
      logger.setLevel(Level.ALL);
      return appender;
    }

    void detach() {
      loggerConfig.removeAppender(getName());
      stop();
      context.updateLoggers();
      // Best-effort: restore previous level so other tests are not affected.
      if (previousLevel != null) {
        loggerConfig.setLevel(previousLevel);
      }
    }

    String renderedText() {
      return String.join("\n", messages);
    }

    @Override
    public void append(LogEvent event) {
      messages.add(new String(getLayout().toByteArray(event)));
    }
  }
}
