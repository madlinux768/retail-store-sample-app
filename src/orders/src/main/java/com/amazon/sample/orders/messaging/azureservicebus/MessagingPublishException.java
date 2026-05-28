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

/**
 * Thrown by {@link AzureServiceBusMessagingProvider} when an event cannot be
 * published to the configured Azure Service Bus queue. Wraps the underlying
 * cause (Jackson serialization error or Azure SDK runtime exception) so the
 * caller sees a single, provider-specific failure type.
 *
 * <p>This is an unchecked exception on purpose: the {@code MessagingProvider}
 * interface does not declare a checked exception, and the orders service
 * relies on the surrounding {@code @TransactionalEventListener} to propagate
 * the failure after the order has already been committed. The thrown
 * exception is what allows the alarm path (counter + log + rethrow) to be
 * observed by the caller, satisfying requirement 2.5.
 */
public class MessagingPublishException extends RuntimeException {

  private static final long serialVersionUID = 1L;

  public MessagingPublishException(String message, Throwable cause) {
    super(message, cause);
  }
}
