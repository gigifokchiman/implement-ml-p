// K6 Stress Test for ML Platform Infrastructure
// Tests infrastructure limits and breaking points

import http from 'k6/http';
import {check, sleep} from 'k6';
import {Counter, Gauge, Rate, Trend} from 'k6/metrics';

// Custom metrics
export let errorRate = new Rate('stress_errors');
export let requestCount = new Counter('stress_requests');
export let activeUsers = new Gauge('active_users');
export let responseTime = new Trend('stress_response_time');

// Stress test configuration - gradually increase load to find breaking point
export let options = {
  stages: [
    {duration: '5m', target: 50},   // Ramp up to 50 users
    {duration: '10m', target: 50},  // Stay at 50 users
    {duration: '5m', target: 100},  // Ramp up to 100 users
    {duration: '10m', target: 100}, // Stay at 100 users
    {duration: '5m', target: 200},  // Stress: Ramp up to 200 users
    {duration: '10m', target: 200}, // Stress: Stay at 200 users
    {duration: '5m', target: 0},    // Ramp down
  ],
  thresholds: {
    // More relaxed thresholds for stress testing
    http_req_duration: ['p(95)<2000'],  // 95% of requests under 2s
    http_req_failed: ['rate<0.5'],      // Error rate under 50%
    stress_errors: ['rate<0.5'],        // Custom error rate under 50%
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TARGET_HOST = __ENV.TARGET_HOST || 'ml-platform.local';

export default function () {
  activeUsers.add(1);
  requestCount.add(1);

  // Test multiple endpoints to stress different parts of the system
  const endpoints = [
    {url: '/', name: 'frontend'},
    {url: '/health', name: 'health'},
    {url: '/api/health', name: 'api_health'},
    {url: '/metrics', name: 'metrics'},
  ];

  // Randomly select endpoint to test
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];

  let response = http.get(`${BASE_URL}${endpoint.url}`, {
    headers: {
      'Host': endpoint.name === 'api_health' ? `api.${TARGET_HOST}` : TARGET_HOST,
      'User-Agent': 'k6-stress-test',
    },
    timeout: '30s', // Longer timeout for stress conditions
  });

  let success = check(response, {
    [`${endpoint.name} responds`]: (r) => r.status < 500, // Allow 4xx but not 5xx
    [`${endpoint.name} response time acceptable`]: (r) => r.timings.duration < 5000,
  });

  errorRate.add(!success);
  responseTime.add(response.timings.duration);

  // Variable sleep time to simulate realistic user behavior under stress
  sleep(Math.random() * 3);
}

export function setup() {
  console.log('Starting stress test...');
  console.log(`Target URL: ${BASE_URL}`);
  console.log(`Target Host: ${TARGET_HOST}`);

  // Warmup request to ensure system is responsive
  let warmupResponse = http.get(`${BASE_URL}/`, {
    headers: {'Host': TARGET_HOST},
  });

  if (warmupResponse.status >= 500) {
    console.error('System appears to be down before stress test started');
    throw new Error('Pre-test warmup failed');
  }

  return {};
}

export function teardown(data) {
  console.log('Stress test completed');

  // Final health check
  let finalResponse = http.get(`${BASE_URL}/health`, {
    headers: {'Host': TARGET_HOST},
  });

  if (finalResponse.status >= 500) {
    console.warn('System may be in degraded state after stress test');
  } else {
    console.log('System recovered successfully after stress test');
  }
}

export function handleSummary(data) {
  const report = generateStressReport(data);

  return {
    'stress-test-results.json': JSON.stringify(data, null, 2),
    'stress-test-report.md': report,
    stdout: textSummary(data),
  };
}

function generateStressReport(data) {
  const totalRequests = data.metrics.http_reqs.values.count;
  const errorRate = data.metrics.http_req_failed.values.rate * 100;
  const avgResponseTime = data.metrics.http_req_duration.values.avg;
  const p95ResponseTime = data.metrics.http_req_duration.values['p(95)'];
  const maxResponseTime = data.metrics.http_req_duration.values.max;
  const requestsPerSecond = data.metrics.http_reqs.values.rate;

  return `# ML Platform Stress Test Report

## Test Configuration
- **Duration**: 55 minutes total
- **Max Concurrent Users**: 200
- **Target**: ${BASE_URL}
- **Test Date**: ${new Date().toISOString()}

## Results Summary

### Performance Metrics
- **Total Requests**: ${totalRequests}
- **Requests/Second**: ${requestsPerSecond.toFixed(2)}
- **Error Rate**: ${errorRate.toFixed(2)}%

### Response Times
- **Average**: ${avgResponseTime.toFixed(2)}ms
- **95th Percentile**: ${p95ResponseTime.toFixed(2)}ms
- **Maximum**: ${maxResponseTime.toFixed(2)}ms

## Threshold Analysis
${Object.entries(data.thresholds).map(([metric, result]) =>
    `- **${metric}**: ${result.ok ? '✅ PASSED' : '❌ FAILED'}`
  ).join('\n')}

## Recommendations

### If Error Rate > 10%
- Review application logs for specific error patterns
- Check resource utilization (CPU, memory, disk)
- Consider scaling up infrastructure
- Implement circuit breakers and retry logic

### If Response Time > 1000ms
- Optimize application performance
- Add caching layers
- Scale horizontally
- Review database query performance

### If System Failed Under Load
- Implement proper resource limits
- Add health checks and auto-scaling
- Review infrastructure capacity planning
- Consider load balancing improvements

## Next Steps
1. Review detailed metrics in stress-test-results.json
2. Correlate with infrastructure monitoring data
3. Identify bottlenecks and optimization opportunities
4. Plan capacity based on expected user growth
`;
}

function textSummary(data) {
  let summary = '\n=== STRESS TEST SUMMARY ===\n';
  summary += `Total Requests: ${data.metrics.http_reqs.values.count}\n`;
  summary += `Error Rate: ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%\n`;
  summary += `Avg Response Time: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
  summary += `95th Percentile: ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  summary += `Requests/Second: ${data.metrics.http_reqs.values.rate.toFixed(2)}\n`;
  summary += '\nThreshold Results:\n';

  for (const [metric, result] of Object.entries(data.thresholds)) {
    summary += `  ${result.ok ? '✅' : '❌'} ${metric}\n`;
  }

  return summary;
}
