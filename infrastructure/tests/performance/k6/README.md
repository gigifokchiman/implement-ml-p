# K6 Load Testing Suite

Performance testing suite for ML Platform and Data Platform using K6.

## Prerequisites

- k6 installed globally: `npm install -g k6`
- Running local infrastructure (see main infrastructure README)

## Available Tests

### Basic Load Test (`basic-load-test.js`)

- Tests frontend, health, and API endpoints
- Gradual ramp-up: 10 → 20 users over 16 minutes
- Thresholds: 95% requests < 500ms, error rate < 10%

### Stress Test (`stress-test.js`)

- High-load testing for stress scenarios
- More aggressive user load patterns

## Running Tests

### Quick Start

```bash
# Basic test against default endpoints
npm test

# Test specific platform
npm run test:ml-platform
npm run test:data-platform

# Stress testing
npm run test:stress

# Generate JSON report
npm run test:report
```

### Manual Execution

```bash
# Test ML Platform
k6 run basic-load-test.js --env BASE_URL=http://localhost:8080 --env TARGET_HOST=ml-platform.local

# Test Data Platform  
k6 run basic-load-test.js --env BASE_URL=http://localhost:8081 --env TARGET_HOST=data-platform.local

# Test with custom parameters
k6 run basic-load-test.js \
  --env BASE_URL=http://localhost:8080 \
  --env TARGET_HOST=ml-platform.local \
  --vus 20 \
  --duration 5m
```

## Port Forwarding for Local Testing

Before running tests, ensure services are accessible:

```bash
# ML Platform Backend
kubectl port-forward -n ml-platform svc/ml-platform-backend 8080:80

# Data Platform API
kubectl port-forward -n data-platform svc/data-api 8081:80

# Infrastructure Services
kubectl port-forward -n storage svc/minio 9000:9000
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

## Test Results

Results are output to:

- Console (real-time)
- `performance-test-results.json` (when using `--out json`)

## Customization

### Environment Variables

- `BASE_URL`: Target base URL (default: http://localhost:8080)
- `TARGET_HOST`: Host header value (default: ml-platform.local)

### Test Scenarios

Modify the `options` object in test files to adjust:

- Load patterns (`stages`)
- Performance thresholds
- Test duration

## Integration with CI/CD

These tests can be integrated into GitHub Actions:

```yaml
- name: Run Performance Tests
  run: |
    kubectl port-forward -n ml-platform svc/ml-platform-backend 8080:80 &
    sleep 10
    cd infrastructure/tests/performance/k6
    npm test
```
