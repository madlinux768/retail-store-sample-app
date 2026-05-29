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

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/**
 * Unit tests for {@link AzureServiceBusMessagingConfig#stripEntityPath(String)}.
 *
 * <p>Background: a SAS authorization rule created on a Service Bus queue
 * (rather than on the namespace) emits a connection string of the form
 * {@code Endpoint=sb://...;SharedAccessKeyName=X;SharedAccessKey=Y;EntityPath=<queue>}.
 * The {@code ServiceBusAdministrationClient} explicitly rejects any
 * connection string containing {@code EntityPath=...} with the error
 * "'connectionString' cannot contain an EntityPath. It should be a
 * namespace connection string." The publisher's
 * {@code ServiceBusSenderClient} accepts both forms, so we strip the
 * clause for the admin client while preserving the original for the
 * sender.
 */
class AzureServiceBusStripEntityPathTest {

  private static final String NAMESPACE_FORM =
    "Endpoint=sb://example.servicebus.windows.net/;" +
    "SharedAccessKeyName=orders-events-send;SharedAccessKey=ZmFrZQ==";

  private static final String ENTITY_FORM =
    NAMESPACE_FORM + ";EntityPath=orders-events";

  @Test
  void stripsEntityPathSuffixWhenPresent() {
    assertThat(AzureServiceBusMessagingConfig.stripEntityPath(ENTITY_FORM))
      .as("EntityPath clause must be removed for the admin client")
      .isEqualTo(NAMESPACE_FORM);
  }

  @Test
  void returnsInputUnchangedWhenNoEntityPath() {
    assertThat(AzureServiceBusMessagingConfig.stripEntityPath(NAMESPACE_FORM))
      .as("namespace-form connection strings must pass through unchanged")
      .isEqualTo(NAMESPACE_FORM);
  }

  @Test
  void preservesEverythingBeforeEntityPath() {
    String prefixed =
      "Endpoint=sb://other.servicebus.windows.net/;" +
      "SharedAccessKeyName=root;SharedAccessKey=AAA=;EntityPath=q;Foo=bar";

    String stripped = AzureServiceBusMessagingConfig.stripEntityPath(
      prefixed
    );

    assertThat(stripped)
      .as("only the EntityPath suffix and anything after it is removed")
      .isEqualTo(
        "Endpoint=sb://other.servicebus.windows.net/;" +
        "SharedAccessKeyName=root;SharedAccessKey=AAA="
      );
    assertThat(stripped)
      .as("stripped form must not contain EntityPath= anywhere")
      .doesNotContain("EntityPath=");
  }

  @Test
  void returnsNullWhenInputNull() {
    assertThat(AzureServiceBusMessagingConfig.stripEntityPath(null)).isNull();
  }
}
