// k6 Load Test Script for ProductivityAI Backend API
// Runs 100 Virtual Users for 1 minute of continuous load
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTrend = new Trend('response_time_ms');

export const options = {
  vus: 100,
  duration: '1m',
  thresholds: {
    http_req_failed: ['rate<0.05'],      // Request failure rate under 5%
    http_req_duration: ['p(95)<1500'],    // 95th percentile latency under 1.5s
  },
};

export default function () {
  const baseUrl = __ENV.BACKEND_URL || 'https://productivityai-backend.onrender.com';

  // Test 1: Health check / root endpoint
  const healthRes = http.get(`${baseUrl}/`);
  check(healthRes, {
    'root status is 200 or 404': (r) => r.status === 200 || r.status === 404 || r.status === 301,
    'root response time < 2s': (r) => r.timings.duration < 2000,
  });
  errorRate.add(healthRes.status >= 500);
  responseTrend.add(healthRes.timings.duration);

  // Test 2: API base endpoint
  const apiRes = http.get(`${baseUrl}/api`);
  check(apiRes, {
    'api status is reachable': (r) => r.status < 500,
    'api response time < 2s': (r) => r.timings.duration < 2000,
  });
  errorRate.add(apiRes.status >= 500);
  responseTrend.add(apiRes.timings.duration);

  // Short pause between iterations to simulate realistic user behavior
  sleep(0.1);
}
