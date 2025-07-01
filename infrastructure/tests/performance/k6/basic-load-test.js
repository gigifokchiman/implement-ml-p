// K6 Load Test for ML Platform Infrastructure
// Tests basic application performance and infrastructure limits

import http from 'k6/http';
import {check, sleep} from 'k6';
import {Rate, Trend} from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('errors');
export let responseTime = new Trend('response_time');

// Test configuration
export let options = {
  stages: [
    {duration: '2m', target: 10},  // Ramp up to 10 users
    {duration: '5m', target: 10},  // Stay at 10 users
    {duration: '2m', target: 20},  // Ramp up to 20 users
    {duration: '5m', target: 20},  // Stay at 20 users
    {duration: '2m', target: 0},   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must be below 500ms
    http_req_failed: ['rate<0.1'],    // Error rate must be below 10%
    errors: ['rate<0.1'],             // Custom error rate must be below 10%
  },
};

// Environment configuration
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TARGET_HOST = __ENV.TARGET_HOST || 'ml-platform.local';

export default function () {
  // Test frontend availability
  let frontendResponse = http.get(`${BASE_URL}/`, {
    headers: {
      'Host': TARGET_HOST,
    },
  });

  let frontendCheck = check(frontendResponse, {
    'frontend status is 200': (r) => r.status === 200,
    'frontend response time < 1000ms': (r) => r.timings.duration < 1000,
  });

  errorRate.add(!frontendCheck);
  responseTime.add(frontendResponse.timings.duration);

  // Test health endpoint if available
  let healthResponse = http.get(`${BASE_URL}/health`, {
    headers: {
      'Host': TARGET_HOST,
    },
  });

  check(healthResponse, {
    'health endpoint available': (r) => r.status === 200 || r.status === 404, // 404 is ok if not implemented
  });

  // Test API endpoints if available
  let apiResponse = http.get(`${BASE_URL}/api/health`, {
    headers: {
      'Host': `api.${TARGET_HOST}`,
    },
  });

  check(apiResponse, {
    'api endpoint responds': (r) => r.status === 200 || r.status === 404, // 404 is ok if not implemented
  });

  // Simulate realistic user behavior
  sleep(1);
}

export function handleSummary(data) {
  return {
    'performance-test-results.json': JSON.stringify(data, null, 2),
    stdout: textSummary(data, {indent: ' ', enableColors: true}),
  };
}

function textSummary(data, options) {
  const {indent = '', enableColors = false} = options || {};

  let summary = '';
  summary += `${indent}Performance Test Summary\n`;
  summary += `${indent}========================\n\n`;

  // Request metrics
  summary += `${indent}Requests:\n`;
  summary += `${indent}  Total: ${data.metrics.http_reqs.values.count}\n`;
  summary += `${indent}  Failed: ${data.metrics.http_req_failed.values.rate * 100}%\n`;
  summary += `${indent}  Rate: ${data.metrics.http_reqs.values.rate}/sec\n\n`;

  // Response time metrics
  summary += `${indent}Response Times:\n`;
  summary += `${indent}  Average: ${data.metrics.http_req_duration.values.avg}ms\n`;
  summary += `${indent}  95th percentile: ${data.metrics.http_req_duration.values['p(95)']}ms\n`;
  summary += `${indent}  Max: ${data.metrics.http_req_duration.values.max}ms\n\n`;

  // Custom metrics
  if (data.metrics.errors) {
    summary += `${indent}Custom Metrics:\n`;
    summary += `${indent}  Error Rate: ${data.metrics.errors.values.rate * 100}%\n\n`;
  }

  // Test results
  summary += `${indent}Thresholds:\n`;
  for (const [metric, threshold] of Object.entries(data.thresholds)) {
    const passed = threshold.ok ? '✓' : '✗';
    summary += `${indent}  ${passed} ${metric}\n`;
  }

  return summary;
}
