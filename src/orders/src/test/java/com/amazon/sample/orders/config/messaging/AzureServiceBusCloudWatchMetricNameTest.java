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
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import io.micrometer.cloudwatch2.CloudWatchMeterRegistry;
import io.micrometer.core.instrument.Counter;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import software.amazon.awssdk.services.cloudwatch.CloudWatchAsyncClient;
import software.amazon.awssdk.services.cloudwatch.model.Dimension;
import software.amazon.awssdk.services.cloudwatch.model.MetricDatum;
import software.amazon.awssdk.services.cloudwatch.model.PutMetricDataRequest;
import software.amazon.awssdk.services.cloudwatch.model.PutMetricDataResponse;

/**
 * Reproduces the metric-name bug in
 * {@link AzureServiceBusMessagingConfig#cloudWatchMeterRegistry(CloudWatchAsyncClient)}.
 *
 * <p>The Terraform CloudWatch alarm targets the unsuffixed metric name
 * {@code OrdersAzurePublishFailures}. The {@code MeterFilter.map(...)}
 * registered in production rewrites the source meter id
 * {@code orders.azure.publish.failures} to {@code OrdersAzurePublishFailures}
 * before registration, but Micrometer's
 * {@code CloudWatchMeterRegistry#metricData(Counter)} appends a
 * {@code .count} suffix to {@link io.micrometer.core.instrument.Counter}
 * meters when it serializes them into {@link MetricDatum}, AFTER the
 * filter rename runs. Production therefore publishes the metric under
 * {@code OrdersAzurePublishFailures.count}, and the alarm — which
 * watches {@code OrdersAzurePublishFailures} — never fires.
 *
 * <p>This test is expected to FAIL on {@code main}: the captured
 * {@link PutMetricDataRequest} contains a {@link MetricDatum} whose
 * {@code metricName()} is {@code OrdersAzurePublishFailures.count}
 * rather than the expected {@code OrdersAzurePublishFailures}. Once the
 * production fix is in place (Stage 2), this test will pass.
 *
 * <p>Approach: mock {@link CloudWatchAsyncClient}, construct the real
 * {@link AzureServiceBusMessagingConfig} bean factory, obtain the
 * production-shaped {@link CloudWatchMeterRegistry}, register and
 * increment the failures counter exactly the way
 * {@code AzureServiceBusMessagingProvider} does, and call
 * {@link CloudWatchMeterRegistry#close()} to trigger the registry's
 * final publish step. The {@code close()} call is preferred over
 * subclassing to expose the protected {@code publish()} method because
 * it exercises the same code path Spring's bean lifecycle would invoke
 * on shutdown.
 */
class AzureServiceBusCloudWatchMetricNameTest {

  private static final String QUEUE_NAME = "orders-events";

  /**
   * Endpoint=sb:// is the only constructor-validation requirement;
   * neither the SAS key name nor the key bytes are used by the
   * registry construction path. The string is intentionally synthetic
   * so it cannot be mistaken for a real secret.
   */
  private static final String VALID_CONNECTION_STRING =
    "Endpoint=sb://test.servicebus.windows.net/;" +
    "SharedAccessKeyName=fake;SharedAccessKey=ZmFrZQ==";

  private static final String SOURCE_METER_NAME =
    "orders.azure.publish.failures";

  private static final String EXPECTED_METRIC_NAME =
    "OrdersAzurePublishFailures";

  @Test
  void cloudWatchMetricName_forFailureCounter_hasNoCountSuffix() {
    CloudWatchAsyncClient cloudWatchClient = mock(CloudWatchAsyncClient.class);
    // The registry chains .whenComplete(...) on the returned future, so
    // a non-null completed future is required to avoid NPEs in the
    // registry's own logging callback.
    when(cloudWatchClient.putMetricData(any(PutMetricDataRequest.class))).thenReturn(
      CompletableFuture.completedFuture(
        PutMetricDataResponse.builder().build()
      )
    );

    AzureServiceBusProperties properties = new AzureServiceBusProperties();
    properties.setConnectionString(VALID_CONNECTION_STRING);
    properties.setQueueName(QUEUE_NAME);

    AzureServiceBusMessagingConfig config = new AzureServiceBusMessagingConfig(
      properties
    );
    CloudWatchMeterRegistry registry = config.cloudWatchMeterRegistry(
      cloudWatchClient
    );

    try {
      // Register and increment exactly the way
      // AzureServiceBusMessagingProvider does at runtime.
      Counter counter = Counter.builder(SOURCE_METER_NAME)
        .tag("queue", QUEUE_NAME)
        .register(registry);
      counter.increment();
    } finally {
      // close() invokes StepMeterRegistry#publish() one final time
      // synchronously on the calling thread, which is what we capture.
      registry.close();
    }

    ArgumentCaptor<PutMetricDataRequest> captor = ArgumentCaptor.forClass(
      PutMetricDataRequest.class
    );
    verify(cloudWatchClient, atLeastOnce()).putMetricData(captor.capture());

    List<MetricDatum> emitted = captor
      .getAllValues()
      .stream()
      .flatMap(req -> req.metricData().stream())
      .toList();

    assertThat(emitted)
      .as(
        "the only meter accepted by the production filter chain is the " +
        "renamed failures counter, so exactly one MetricDatum should be " +
        "emitted"
      )
      .hasSize(1);

    MetricDatum datum = emitted.get(0);

    assertThat(datum.dimensions())
      .as(
        "the queue=%s dimension must survive the rename so per-queue " +
        "alarms still scope correctly",
        QUEUE_NAME
      )
      .anySatisfy(d ->
        assertThat(d)
          .extracting(Dimension::name, Dimension::value)
          .containsExactly("queue", QUEUE_NAME)
      );

    assertThat(datum.metricName())
      .as(
        "Terraform alarm targets the unsuffixed name " +
        "'%s' — production today emits the Micrometer-suffixed name " +
        "with '.count', so the alarm never fires. " +
        "actual=<%s> expected=<%s>",
        EXPECTED_METRIC_NAME,
        datum.metricName(),
        EXPECTED_METRIC_NAME
      )
      .isEqualTo(EXPECTED_METRIC_NAME);
  }
}
