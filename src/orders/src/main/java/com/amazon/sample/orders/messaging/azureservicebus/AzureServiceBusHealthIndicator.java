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

import com.azure.messaging.servicebus.administration.ServiceBusAdministrationClient;
import com.azure.messaging.servicebus.administration.models.QueueRuntimeProperties;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;

/**
 * Spring Boot Actuator {@link HealthIndicator} for Azure Service Bus.
 *
 * <p>Reports {@code UP} when {@link ServiceBusAdministrationClient#getQueueRuntimeProperties(String)}
 * succeeds against the configured queue, exposing {@code queue} and
 * {@code activeMessageCount} as details. Reports {@code DOWN} on any
 * exception, exposing only {@code queue} and {@code errorClass}.
 *
 * <p>The connection string and any {@code SharedAccessKey} substring are
 * deliberately never included in the health detail (requirement 5.3): the
 * raw exception message and stack trace can wrap connection-string fragments
 * coming from the Azure SDK, so we surface only the safe class name.
 *
 * <p>This class is registered as a bean by {@code AzureServiceBusMessagingConfig}
 * (task 5) under the bean name {@code azureServiceBus} so it appears under
 * that component name on {@code /actuator/health}. It is intentionally not a
 * {@code @Component} so it is absent when the active provider is not
 * {@code azureservicebus} (requirement 5.4).
 */
public class AzureServiceBusHealthIndicator implements HealthIndicator {

  private final ServiceBusAdministrationClient admin;
  private final String queueName;

  public AzureServiceBusHealthIndicator(
    ServiceBusAdministrationClient admin,
    String queueName
  ) {
    this.admin = admin;
    this.queueName = queueName;
  }

  @Override
  public Health health() {
    try {
      QueueRuntimeProperties properties = admin.getQueueRuntimeProperties(
        queueName
      );
      return Health.up()
        .withDetail("queue", queueName)
        .withDetail("activeMessageCount", properties.getActiveMessageCount())
        .build();
    } catch (Exception e) {
      // Never include the connection string, the exception message, or the
      // stack trace -- any of those could leak `Endpoint=sb://...` or
      // `SharedAccessKey=...` from a wrapped Azure SDK exception
      // (requirement 5.3).
      return Health.down()
        .withDetail("queue", queueName)
        .withDetail("errorClass", e.getClass().getSimpleName())
        .build();
    }
  }
}
