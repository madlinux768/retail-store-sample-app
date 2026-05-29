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
import static org.assertj.core.api.Assertions.entry;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.azure.messaging.servicebus.ServiceBusMessageBatch;
import com.azure.messaging.servicebus.ServiceBusSenderClient;
import org.junit.jupiter.api.Test;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.Status;

/**
 * Unit tests for {@link AzureServiceBusHealthIndicator}.
 *
 * <p>These tests cover the actuator-details contract:
 *
 * <ul>
 *   <li>R5.1 / R5.2 — happy path reports {@code UP} with only {@code queue}.</li>
 *   <li>R5.1 / R5.2 — failure path reports {@code DOWN} with only
 *       {@code queue} and {@code errorClass} (the simple class name of the
 *       caught exception).</li>
 *   <li>R5.3 / R8.1 — even when the underlying exception's message contains
 *       a connection-string fragment ({@code Endpoint=sb://...} or
 *       {@code SharedAccessKey=...}), the {@link Health} details and
 *       toString must not leak it.</li>
 * </ul>
 */
class AzureServiceBusHealthIndicatorTest {

  private static final String QUEUE_NAME = "orders-events";

  private static final String LEAKED_SECRET_MARKER_ENDPOINT = "Endpoint=sb://";
  private static final String LEAKED_SECRET_MARKER_KEY = "SharedAccessKey=";

  /**
   * A worst-case exception message that embeds both forbidden tokens. The
   * Azure SDK is known to wrap connection-string fragments into exception
   * messages it throws (for example, on authentication errors), so we
   * simulate that here.
   *
   * <p>This is the sibling of the no-secret-in-logs assertion in
   * {@code AzureServiceBusMessagingProviderTest}; here we assert against
   * the actuator-details path, which is what
   * {@code /actuator/health/azureServiceBus} serializes over HTTP.
   */
  private static final String LEAKY_EXCEPTION_MESSAGE =
    "auth failed: Endpoint=sb://realhost.servicebus.windows.net/;" +
    "SharedAccessKeyName=fake;SharedAccessKey=AAAAA==";

  @Test
  void healthUpWhenCreateMessageBatchSucceeds() {
    ServiceBusSenderClient sender = mock(ServiceBusSenderClient.class);
    when(sender.createMessageBatch()).thenReturn(
      mock(ServiceBusMessageBatch.class)
    );

    AzureServiceBusHealthIndicator indicator =
      new AzureServiceBusHealthIndicator(sender, QUEUE_NAME);

    Health health = indicator.health();

    assertThat(health.getStatus()).isEqualTo(Status.UP);
    assertThat(health.getDetails()).containsOnly(entry("queue", QUEUE_NAME));
  }

  @Test
  void healthDownWhenCreateMessageBatchThrows() {
    ServiceBusSenderClient sender = mock(ServiceBusSenderClient.class);
    // Use RuntimeException to keep the test independent of the Azure SDK's
    // ServiceBusException constructor surface (which requires an
    // AmqpException cause / ServiceBusErrorSource in 7.x). The indicator
    // catches Exception, so any subclass exercises the same contract.
    Class<? extends Exception> thrownType = RuntimeException.class;
    when(sender.createMessageBatch()).thenThrow(
      new RuntimeException(LEAKY_EXCEPTION_MESSAGE)
    );

    AzureServiceBusHealthIndicator indicator =
      new AzureServiceBusHealthIndicator(sender, QUEUE_NAME);

    Health health = indicator.health();

    assertThat(health.getStatus()).isEqualTo(Status.DOWN);
    assertThat(health.getDetails()).containsOnly(
      entry("queue", QUEUE_NAME),
      entry("errorClass", thrownType.getSimpleName())
    );
  }

  @Test
  void healthDetailsDoNotLeakConnectionStringOnFailure() {
    ServiceBusSenderClient sender = mock(ServiceBusSenderClient.class);
    when(sender.createMessageBatch()).thenThrow(
      new RuntimeException(LEAKY_EXCEPTION_MESSAGE)
    );

    AzureServiceBusHealthIndicator indicator =
      new AzureServiceBusHealthIndicator(sender, QUEUE_NAME);

    Health health = indicator.health();

    assertThat(health.getDetails().toString())
      .as("health details must never contain `Endpoint=sb://`")
      .doesNotContain(LEAKED_SECRET_MARKER_ENDPOINT)
      .as("health details must never contain `SharedAccessKey=`")
      .doesNotContain(LEAKED_SECRET_MARKER_KEY);

    // Defensive: ensure no overload of Health.toString accidentally exposes
    // the underlying exception message either.
    assertThat(health.toString())
      .as("Health.toString must never contain `Endpoint=sb://`")
      .doesNotContain(LEAKED_SECRET_MARKER_ENDPOINT)
      .as("Health.toString must never contain `SharedAccessKey=`")
      .doesNotContain(LEAKED_SECRET_MARKER_KEY);
  }
}
