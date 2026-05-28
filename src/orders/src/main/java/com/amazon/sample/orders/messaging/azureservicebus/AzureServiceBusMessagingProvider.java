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

import com.amazon.sample.orders.messaging.MessagingProvider;
import com.azure.messaging.servicebus.ServiceBusMessage;
import com.azure.messaging.servicebus.ServiceBusSenderClient;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.extern.slf4j.Slf4j;

/**
 * Publishes order events to an Azure Service Bus queue.
 *
 * <p>On any failure (Jackson serialization or Azure SDK runtime exception)
 * the provider increments a Micrometer counter, emits a single ERROR log
 * line with {@code queueName}, {@code eventType}, and {@code errorClass}
 * only (never the connection string, the exception message, or the stack
 * trace), and rethrows as {@link MessagingPublishException} so the caller
 * observes the failure (requirement 2.5).
 *
 * <p>The connection string is intentionally never held by this class and
 * must never be logged. The Azure SDK reads it from the injected
 * {@link ServiceBusSenderClient}.
 */
@Slf4j
public class AzureServiceBusMessagingProvider implements MessagingProvider {

  private final ServiceBusSenderClient sender;
  private final ObjectMapper mapper;
  private final Counter publishFailures;
  private final String queueName;

  public AzureServiceBusMessagingProvider(
    ServiceBusSenderClient sender,
    ObjectMapper mapper,
    MeterRegistry registry,
    String queueName
  ) {
    this.sender = sender;
    this.mapper = mapper;
    this.queueName = queueName;
    this.publishFailures = Counter.builder("orders.azure.publish.failures")
      .tag("queue", queueName)
      .description(
        "Count of failed publish attempts to the Azure Service Bus queue"
      )
      .register(registry);
  }

  @Override
  public void publishEvent(Object event) {
    String eventType = event.getClass().getSimpleName();
    try {
      String body = mapper.writeValueAsString(event);
      ServiceBusMessage msg = new ServiceBusMessage(body).setContentType(
        "application/json"
      );
      msg.getApplicationProperties().put("eventType", eventType);
      sender.sendMessage(msg);
    } catch (Exception e) {
      // Increment exactly once per failure (requirement 6.1, 6.6).
      publishFailures.increment();
      // Structured log with safe fields only. Never include the connection
      // string, the exception message, or the stack trace -- any of those
      // could leak `Endpoint=sb://...` or `SharedAccessKey=...` from a
      // wrapped Azure SDK exception (requirement 6.2).
      log.error(
        "Azure Service Bus publish failed: queue={}, eventType={}, errorClass={}",
        queueName,
        eventType,
        e.getClass().getSimpleName()
      );
      throw new MessagingPublishException(
        "Azure Service Bus publish failed",
        e
      );
    }
  }
}
