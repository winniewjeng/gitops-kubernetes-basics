#!/usr/bin/env python3
from prometheus_client import start_http_server, Counter, Gauge, Histogram
import random
import time

# Define metrics
request_count = Counter('app_requests_total', 'Total HTTP requests', [
                        'method', 'endpoint'])
request_latency = Histogram(
    'app_request_latency_seconds', 'Request latency in seconds')
active_users = Gauge('app_active_users', 'Number of active users')
temperature = Gauge('app_temperature_celsius', 'Simulated temperature')

# Start the metrics server on port 8000
start_http_server(8000)

print("Metrics server running on http://localhost:8000/metrics")

# Simulate some activity
while True:
    # Simulate requests
    request_count.labels(method='GET', endpoint='/api/users').inc()
    request_count.labels(
        method='POST', endpoint='/api/login').inc(random.randint(1, 5))

    # Simulate request latency
    request_latency.observe(random.uniform(0.01, 0.5))

    # Simulate active users going up and down
    active_users.set(random.randint(10, 100))

    # Simulate temperature drift
    temperature.set(20 + random.uniform(-5, 5))

    time.sleep(2)
