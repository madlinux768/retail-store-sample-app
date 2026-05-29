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

import com.amazon.sample.orders.messaging.MessagingProvider;
import com.amazon.sample.orders.messaging.azureservicebus.AzureServiceBusMessagingProvider;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;

/**
 * Spring context test for provider selection (task 8.1).
 *
 * <p>Boots the full orders application with the env-equivalent properties
 * a deployed task would receive when {@code RETAIL_ORDERS_MESSAGING_PROVIDER}
 * is {@code azureservicebus}, and asserts the application context contains
 * exactly one {@link MessagingProvider} bean and that it is
 * {@link AzureServiceBusMessagingProvider}.
 *
 * <p>Validates Property 1 (single bean) from the design and Acceptance
 * Criteria 1.1, 1.3, 1.5, 5.4, and 9.1.
 *
 * <p>The connection string and queue name use Microsoft's documented
 * placeholder hostname {@code test.servicebus.windows.net} and a fake
 * SharedAccessKey. The Azure SDK {@code ServiceBusSenderClient}
 * instantiated by {@link AzureServiceBusMessagingConfig} is lazy at the
 * network layer, so bean creation succeeds without any live Azure
 * connectivity.
 */
@SpringBootTest(
  properties = {
    "retail.orders.messaging.provider=azureservicebus",
    "retail.orders.messaging.azureservicebus.connectionString=" +
      "Endpoint=sb://test.servicebus.windows.net/;" +
      "SharedAccessKeyName=fake;SharedAccessKey=ZmFrZQ==",
    "retail.orders.messaging.azureservicebus.queueName=test-queue",
  }
)
class AzureServiceBusProviderSelectionTest {

  @Autowired
  private ApplicationContext context;

  @Test
  void exactlyOneMessagingProviderBeanExistsAndItIsAzureServiceBus() {
    Map<String, MessagingProvider> beans = context.getBeansOfType(
      MessagingProvider.class
    );

    assertThat(beans)
      .as(
        "exactly one MessagingProvider bean must be registered " +
          "regardless of which provider value is selected (Property 1)"
      )
      .hasSize(1);

    MessagingProvider provider = beans.values().iterator().next();
    assertThat(provider)
      .as(
        "the active MessagingProvider must be the Azure Service Bus " +
          "implementation when retail.orders.messaging.provider=azureservicebus"
      )
      .isInstanceOf(AzureServiceBusMessagingProvider.class);
  }
}
