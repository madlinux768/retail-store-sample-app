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

import com.azure.messaging.servicebus.ServiceBusSenderClient;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;

/**
 * Spring Boot Actuator {@link HealthIndicator} for Azure Service Bus.
 *
 * <p>Probes connectivity by calling
 * {@link ServiceBusSenderClient#createMessageBatch()} on the cached sender
 * the {@link AzureServiceBusMessagingProvider} already uses. This is
 * deliberate:
 *
 * <ul>
 *   <li><b>R3.5 — Send-only SAS compatible.</b> The queue authorization rule
 *       provisioned by the Terraform module grants {@code send=true,
 *       listen=false, manage=false}. A Manage probe (such as
 *       {@code ServiceBusAdministrationClient.getQueueRuntimeProperties(...)})
 *       returns {@code Unauthorized} against that SAS and would force the
 *       indicator {@code DOWN} even when the publisher path is healthy.
 *       {@code createMessageBatch()} only requires the send link to be open,
 *       so it works under Send-only SAS.</li>
 *   <li><b>R5.2 — same link the publisher uses.</b> The probe exercises the
 *       same AMQPS link, the same SAS auth, and the same queue routing as
 *       {@code publishEvent}. {@code UP} therefore truthfully means
 *       "the publish link is healthy"; this is the semantics R5.2 asks for.
 *       The probe sends nothing — it only asks the SDK whether a batch can
 *       be allocated against the open link, so it is free at the wire.</li>
 * </ul>
 *
 * <p>Reports {@code UP} with only a {@code queue} detail (the configured
 * queue name) on success, satisfying R5.1 and R5.2. {@code activeMessageCount}
 * is intentionally <em>not</em> exposed: it would require Manage rights
 * (incompatible with R3.5) and is not required by R5.2.
 *
 * <p>Reports {@code DOWN} on any exception, exposing only {@code queue} and
 * {@code errorClass}. The connection string and any {@code SharedAccessKey}
 * substring are deliberately never included in the health detail (R5.3): the
 * Azure SDK's exception messages and stack traces can wrap connection-string
 * fragments, so we surface only the safe simple class name.
 *
 * <p>This class is registered as a bean by {@code AzureServiceBusMessagingConfig}
 * under the bean name {@code azureServiceBus} so it appears under that
 * component name on {@code /actuator/health}. It is intentionally not a
 * {@code @Component} so it is absent when the active provider is not
 * {@code azureservicebus} (R5.4).
 */
public class AzureServiceBusHealthIndicator implements HealthIndicator {

  private final ServiceBusSenderClient sender;
  private final String queueName;

  public AzureServiceBusHealthIndicator(
    ServiceBusSenderClient sender,
    String queueName
  ) {
    this.sender = sender;
    this.queueName = queueName;
  }

  @Override
  public Health health() {
    try {
      // Probe the cached sender link the publisher uses. Send-only SAS
      // compatible (R3.5); succeeds iff the AMQPS link, SAS auth, and queue
      // routing are all healthy (R5.2). Sends nothing.
      sender.createMessageBatch();
      return Health.up().withDetail("queue", queueName).build();
    } catch (Exception e) {
      // Broad catch is intentional: the Azure SDK throws both checked
      // (e.g. ServiceBusException) and unchecked variants, and we want all
      // of them to surface as DOWN with the same shape.
      // Never include the connection string, the exception message, or the
      // stack trace — any of those could leak `Endpoint=sb://...` or
      // `SharedAccessKey=...` from a wrapped Azure SDK exception (R5.3).
      return Health.down()
        .withDetail("queue", queueName)
        .withDetail("errorClass", e.getClass().getSimpleName())
        .build();
    }
  }
}
