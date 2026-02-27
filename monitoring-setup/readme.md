# Monitoring Setup - Prometheus & Grafana

This workspace contains the configuration and tooling for Days 4-5 of the K8s learning journey: **Prometheus Fundamentals & Grafana Visualization**.

## Directory Structure

```
monitoring-setup/
├── prometheus.yml          # Prometheus configuration (scrape targets, intervals)
├── simple_app.py          # Demo Python app that exports metrics
├── requirements.txt       # Python dependencies for simple_app
├── readme.md             # This file
└── prometheus-data/      # Time-series database (auto-created by Prometheus)
```

## Quick Start

### 1. Start Prometheus Container

```bash
cd ~/Documents/LearnK8s/monitoring-setup
docker run -d \
  --name prometheus \
  --restart unless-stopped \
  -p 9090:9090 \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest
```

Verify it's running:

```bash
docker ps | grep prometheus
```

Access UI: http://localhost:9090

### 2. Set up Python Environment for simple_app

Option A (using venv):

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Option B (direct install):

```bash
pip3 install prometheus-client
```

### 3. Run the Demo App

```bash
python3 simple_app.py
```

You should see:

```
Metrics server running on http://localhost:8000/metrics
```

Leave this running in a separate terminal.

### 4. Register App with Prometheus

Edit `prometheus.yml` and add this job:

```yaml
- job_name: "simple_app"
  static_configs:
    - targets: ["localhost:8000"]
```

Tell Prometheus to reload:

```bash
curl -X POST http://localhost:9090/-/reload
```

Wait ~10 seconds, then check: http://localhost:9090/targets
You should see `simple_app` listed with status **UP**.

## What simple_app.py Does

The demo app exposes these metrics on `http://localhost:8000/metrics`:

- **`app_requests_total`** (Counter) - Total HTTP requests by method & endpoint
- **`app_request_latency_seconds`** (Histogram) - Request latency distribution
- **`app_active_users`** (Gauge) - Current number of active users
- **`app_temperature_celsius`** (Gauge) - Simulated temperature readings

Metrics are updated every 2 seconds with realistic variations.

## PromQL Query Examples

Once the app is running and registered, try these queries in Prometheus (http://localhost:9090):

```promql
app_requests_total                    # Total requests counter
rate(app_requests_total[5m])          # Requests per second (rate)
app_request_latency_seconds_bucket    # Request latency histogram
app_active_users                      # Current active users
app_temperature_celsius               # Current temperature
```

## Optional: Add Grafana Visualization

```bash
docker run -d \
  --name grafana \
  --restart unless-stopped \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana/grafana:latest
```

1. Open http://localhost:3000
2. Login: `admin` / `admin`
3. Add Prometheus data source: http://localhost:9090
4. Create dashboards visualizing the metrics

## Cleanup

```bash
# Stop containers
docker stop prometheus grafana

# Remove containers entirely
docker rm prometheus grafana

# Keep simple_app running (it's lightweight) or Ctrl+C to stop
```

## Troubleshooting

**Docker daemon target failing?**

- This is normal. Docker metrics require additional setup. You can ignore it for learning.

**simple_app not appearing in Prometheus targets?**

- Ensure the app is running: `curl http://localhost:8000/metrics`
- Wait 15+ seconds after reload for Prometheus to scrape it
- Check Prometheus logs: `docker logs prometheus`

**Can't activate venv?**

- Try: `python3 -m venv .venv` first, then source again
- Or just use: `pip3 install prometheus-client` directly

## Learning Outcomes

By the end of this setup, you'll understand:

- ✓ How Prometheus scrapes metrics from endpoints
- ✓ The pull-based monitoring model
- ✓ Time-series data storage
- ✓ Writing PromQL queries
- ✓ Monitoring custom applications
- ✓ Visualizing metrics in Grafana
