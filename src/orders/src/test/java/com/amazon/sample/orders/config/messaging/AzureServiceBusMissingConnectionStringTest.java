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
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.amazon.sample.orders.OrdersApplication;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.BeanCreationException;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.WebApplicationType;
import org.springframework.context.ConfigurableApplicationContext;

/**
 * Spring context test for the missing-secret invariant (task 8.3).
 *
 * <p>Boots the orders application with
 * {@code retail.orders.messaging.provider=azureservicebus} and an empty
 * {@code connectionString}, then asserts startup fails with a
 * {@link BeanCreationException} whose chain names the offending property
 * {@code retail.orders.messaging.azureservicebus.connectionString}.
 *
 * <p><strong>Why this test does not use the {@code @SpringBootTest}
 * annotation directly:</strong> when the application context fails to
 * load, Spring's JUnit extension reports the failure during the test
 * <em>setup</em> phase, before any {@code @Test} method body executes,
 * so {@code assertThatThrownBy} inside the method body never runs and
 * the failure is reported as a confusing "Failed to load
 * ApplicationContext" rather than the precise property-name assertion
 * the spec asks for. Booting via {@link SpringApplication#run} inside
 * the test method captures the original startup throwable so the cause
 * chain is inspectable. The boot itself uses the same
 * {@link OrdersApplication} configuration class a class-level
 * {@code @SpringBootTest} would use.
 *
 * <p><strong>Why the assertion walks the cause chain:</strong> the
 * {@link jakarta.validation.constraints.NotBlank @NotBlank} on
 * {@link AzureServiceBusProperties#getConnectionString()} causes Spring
 * Boot to throw a {@code ConfigurationPropertiesBindException} (which
 * extends {@link BeanCreationException}) wrapping a
 * {@code BindValidationException}. The property name appears in the
 * inner exception's message — the validation message
 * "{@code retail.orders.messaging.azureservicebus.connectionString must
 * not be blank}" set on the constraint. Walking the chain makes the
 * test robust to both that path and the explicit
 * {@link AzureServiceBusMessagingConfig} constructor check (which is
 * unreachable when the bean cannot be bound, but would also name the
 * property if it were).
 *
 * <p>Validates Acceptance Criterion 1.5 (and supports 1.1, 1.2, 1.3,
 * 5.4, 8.4, 9.1 by exercising the {@code azureservicebus} branch of
 * the provider switch).
 */
class AzureServiceBusMissingConnectionStringTest {

  private static final String CONNECTION_STRING_PROPERTY =
    "retail.orders.messaging.azureservicebus.connectionString";

  @Test
  void startupFailsWithBeanCreationExceptionThatNamesTheMissingProperty() {
    SpringApplication app = new SpringApplication(OrdersApplication.class);
    // Avoid binding a port so the test stays cheap and isolated; this
    // matches what @SpringBootTest(webEnvironment = MOCK) would do.
    app.setWebApplicationType(WebApplicationType.NONE);

    // Command-line-style args take precedence over application.yml so
    // the empty connectionString actually reaches the binder. Using
    // SpringApplication#setDefaultProperties would be overridden by
    // the application.yml provider="in-memory" default.
    String[] args = {
      "--retail.orders.messaging.provider=azureservicebus",
      "--" + CONNECTION_STRING_PROPERTY + "=",
      "--retail.orders.messaging.azureservicebus.queueName=test-queue",
    };

    assertThatThrownBy(() -> {
      try (ConfigurableApplicationContext ignored = app.run(args)) {
        // Unreachable: startup must fail before the context is
        // returned. If we ever reach this line the invariant the
        // spec asks for is broken.
      }
    })
      .as(
        "startup must fail when retail.orders.messaging.provider=" +
          "azureservicebus and connectionString is empty (R1.5)"
      )
      .isInstanceOf(BeanCreationException.class)
      .satisfies(t ->
        assertThat(collectChainMessages(t))
          .as(
            "an exception in the failure cause chain must name the " +
              "missing property '" +
              CONNECTION_STRING_PROPERTY +
              "' so operators can locate the misconfiguration in " +
              "container logs without seeing the connection string itself"
          )
          .contains("connectionString")
      );
  }

  /**
   * Concatenates the message of every {@link Throwable} in the cause
   * chain. Spring may surface the {@code @NotBlank} validation as a
   * {@code ConfigurationPropertiesBindException} (a
   * {@link BeanCreationException} subclass) wrapping a
   * {@code BindValidationException}; the property name appears in the
   * inner exception's message rather than at the top.
   */
  private static String collectChainMessages(Throwable root) {
    StringBuilder sb = new StringBuilder();
    Throwable current = root;
    while (current != null) {
      String message = current.getMessage();
      if (message != null) {
        sb.append(message).append('\n');
      }
      current = current.getCause();
    }
    return sb.toString();
  }
}
