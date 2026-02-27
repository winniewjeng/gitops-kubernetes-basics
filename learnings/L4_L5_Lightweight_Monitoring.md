# Days 4-5 — Lightweight Monitoring (8GB RAM Version)

A resource-friendly alternative to kube-prometheus-stack for learning Prometheus & Grafana concepts without running out of memory.

## Concepts to Learn

- **Prometheus** — metrics collection system
- **Pull-based model** — Prometheus scrapes `/metrics` endpoints
- **PromQL** — the query language
- **Grafana** — visualization + dashboards
- How they connect together

---

## Approach: Prometheus + Grafana via Docker (not in Kubernetes)

### Why This Works Better on 8GB

- Prometheus and Grafana run as lightweight Docker containers
- No K8s components overhead
- Uses **~1.5 GB** total vs **~3 GB** for kube-prometheus-stack
- You still learn the concepts with real tools

### Trade-off

- You're **not** monitoring Kubernetes itself (the kube-prometheus-stack does that)
- Instead, you're learning by monitoring a simple app + exploring dashboards
- This is actually more beginner-friendly

---

## Day 4 — Prometheus Fundamentals

**Goal:** Install Prometheus, understand scraping, write PromQL queries.

### Step 1: Verify Workspace Structure

Your `monitoring-setup` directory should contain:

```
~/Documents/learnK8s/monitoring-setup/
├── prometheus.yml          # Prometheus configuration (already created)
├── simple_app.py          # Demo Python app that exports metrics
├── requirements.txt       # Python dependencies
└── readme.md             # Setup guide
```

If these files don't exist yet, see `monitoring-setup/readme.md` for detailed setup.

### Step 2: Install Python Dependencies

**Option A** (using venv):

```bash
cd ~/Documents/learnK8s/monitoring-setup
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**Option B** (direct install):

```bash
pip3 install prometheus-client
```

### Step 3: Run Prometheus via Docker

```bash
cd ~/Documents/learnk8s/monitoring-setup
docker run -d \
  --name prometheus \
  --restart unless-stopped \
  -p 9090:9090 \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --web.enable-lifecycle
```

**What this does:**

- Docker starts the Prometheus container
- Mounts your local `prometheus.yml` config into the container
- Prometheus launches on `localhost:9090`
- Prometheus reads `prometheus.yml` and sees 3 jobs configured:
  1. `prometheus` (itself on `:9090`)
  2. `simple_app` (on `:8000` — not running yet)
  3. `docker` (on `:9323` — for Docker metrics)
- When using `--web.enable-lifecycle`, you must explicitly set `--config.file`
- The `--web.enable-lifecycle` flag allows Prometheus to reload config without restart

**Verify it's running:**

```bash
docker ps | grep prometheus
```

Wait ~10 seconds, then open: http://localhost:9090

### Step 4: Explore Prometheus UI

1. Click **Status → Targets**
   - You should see 3 jobs: `prometheus` (UP), `simple_app` (DOWN), `docker` (DOWN/error)
   - `prometheus` should be UP (Prometheus scrapes itself)
   - `simple_app` is DOWN (not running yet — we'll start it in Step 6)
   - `docker` might show error (requires Docker daemon metrics — can ignore)

2. Go to **Graph** tab and try queries:

   ```promql
   up                            -- Which targets are healthy?
   process_resident_memory_bytes -- Memory used by Prometheus itself
   up{job="prometheus"}          -- Filter by specific job
   ```

3. Practice writing simple queries:
   - Type `up` and see autocomplete work
   - Type `up{job="prometheus"}` to filter by job
   - Hit **Execute** to run the query

### Step 5: Understand Prometheus Basics

#### Key Insights

- Prometheus **PULLS** metrics from targets (not pushed to it)
- Each target exposes a `/metrics` endpoint (text format)
- Prometheus scrapes at intervals (default 15s, configured in `prometheus.yml`)
- Every metric has a name, labels (tags), and values over time
- All metrics stored in time-series database on disk (`prometheus-data/`)

#### Your `prometheus.yml` Configuration

| Setting                  | Value                                                       |
| ------------------------ | ----------------------------------------------------------- |
| `global.scrape_interval` | 15s (scrape every 15 seconds)                               |
| Job `prometheus`         | scrapes `localhost:9090/metrics` (itself)                   |
| Job `simple_app`         | scrapes `host.docker.internal:8000/metrics` (your app)      |
| Job `docker`             | scrapes `host.docker.internal:9323/metrics` (Docker daemon) |

#### Metric Types

| Type          | Behavior                            | Example                               |
| ------------- | ----------------------------------- | ------------------------------------- |
| **Counter**   | Only goes up                        | `http_requests_total`, `errors_total` |
| **Gauge**     | Goes up and down                    | `memory_bytes`, `temperature`         |
| **Histogram** | Tracks distribution                 | `request_latency_seconds_bucket`      |
| **Summary**   | Like histogram but with percentiles | `request_duration_quantile`           |

#### PromQL Basics

```promql
up                               -- Raw metric value
up{job="prometheus"}             -- Filter by label
rate(requests_total[5m])         -- Rate of change (per-second average)
sum(up)                          -- Sum all "up" metrics
count(up)                        -- Count how many series match "up"
```

### Step 6: Run the Demo App That Exports Metrics

This app simulates a real application with realistic metrics.

In a **new terminal**, start `simple_app.py`:

```bash
cd ~/Documents/learnK8s/monitoring-setup
source .venv/bin/activate        # or skip if using pip3 directly
python3 simple_app.py
```

You should see:

```
Metrics server running on http://localhost:8000/metrics
```

**Leave this terminal running.**

#### What `simple_app.py` Does

- Defines 4 metrics (a counter, histogram, and 2 gauges)
- Starts an HTTP server on port 8000
- Simulates realistic activity by updating metrics every 2 seconds
- Exposes everything at `http://localhost:8000/metrics`

#### Metrics Provided

| Metric                               | Type      | Description                     |
| ------------------------------------ | --------- | ------------------------------- |
| `app_requests_total`                 | Counter   | Total HTTP requests             |
| `app_request_latency_seconds_bucket` | Histogram | Request latency                 |
| `app_active_users`                   | Gauge     | Current active users (0-100)    |
| `app_temperature_celsius`            | Gauge     | Simulated temperature (15-35°C) |

Access the metrics directly:

```bash
curl http://localhost:8000/metrics | head -20
```

### Step 7: Register the App with Prometheus

Your `prometheus.yml` already has the `simple_app` job configured:

```yaml
- job_name: "simple_app"
  static_configs:
    - targets: ["host.docker.internal:8000"]
```

Tell Prometheus to reload the config:

```bash
curl -X POST http://localhost:9090/-/reload
```

Wait ~10 seconds, then check http://localhost:9090/targets — you should see `simple_app` listed with status **UP** (green).

**If still DOWN:**

- Verify `simple_app.py` is running: `curl http://localhost:8000/metrics`
- Check Prometheus logs: `docker logs prometheus`
- Wait another 10 seconds for scrape interval

### Step 8: Query the App's Metrics in Prometheus

Go to http://localhost:9090/graph and try these queries:

| Query                                | What It Shows                           |
| ------------------------------------ | --------------------------------------- |
| `app_requests_total`                 | Total requests counter (only increases) |
| `rate(app_requests_total[5m])`       | Requests per second (rate over 5 min)   |
| `app_request_latency_seconds_bucket` | Latency distribution                    |
| `app_active_users`                   | Current active users (0-100)            |
| `app_temperature_celsius`            | Current temperature (15-35°C)           |

**Try this:**

1. Set time range to **5m** (5 minutes) in top right
2. Query: `app_temperature_celsius`
3. Click **Graph** tab to see the temperature over time
4. Watch the line graph update every 15 seconds

### Step 9: Understand Prometheus Storage

Prometheus stores data in time-series database format on disk:

```bash
ls -la ./prometheus-data/
```

- Default location (inside Docker): `/prometheus/`
- Local mount point: `./prometheus-data/` (created by Docker on first run)
- Data persists between container restarts

To wipe data (fresh start):

```bash
docker stop prometheus
rm -rf ./prometheus-data/
docker start prometheus
```

### Day 4 Checkpoint

- [x] Prometheus running on localhost:9090
- [x] Viewed Prometheus targets (prometheus, simple_app, docker)
- [x] Understood pull-based scraping model
- [x] Wrote basic PromQL queries (up, rate, gauge queries)
- [x] Started simple_app.py (metrics exporter)
- [x] Confirmed simple_app appears as UP in targets
- [x] Queried app metrics in Prometheus
- [x] Understood metric types (counter, gauge, histogram)

---

## Day 5 — Grafana: Dashboards & Visualization

**Goal:** Install Grafana, connect to Prometheus, build dashboards.

### Step 1: Run Grafana via Docker

```bash
docker run -d \
  --name grafana \
  --restart unless-stopped \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana/grafana:latest
```

Verify it's running:

```bash
docker ps | grep grafana
```

Open http://localhost:3000 in your browser.

**Login:**

| Field    | Value   |
| -------- | ------- |
| Username | `admin` |
| Password | `admin` |

### Step 2: Add Prometheus as a Data Source

1. Click the **hamburger menu** (☰) in the top-left corner
2. Go to **Connections → Data sources**
3. Click **"Add data source"** button
4. Search for and select **"Prometheus"**
5. In the URL field, enter: `http://host.docker.internal:9090`

   > **Note:** Use `host.docker.internal` because Grafana runs inside a Docker container and needs to reach Prometheus through the host machine. `localhost` inside Grafana's container refers to the Grafana container itself.

6. Click **"Save & test"**
7. You should see **"Successfully queried the Prometheus API."**

### Step 3: Create Your First Dashboard

1. Click the **"+"** icon (Create) in the left sidebar
2. Select **"Dashboard"**
3. Click **"Add visualization"**
4. Select **"Prometheus"** as the data source
5. In the query box, enter: `app_active_users`
6. In the right panel:
   - Change visualization type to **"Stat"** or **"Gauge"**
   - Set the title: **"Active Users"**
   - Click **"Apply"**

You should see a large number showing current active users!

### Step 4: Add More Panels to the Dashboard

**Panel 2 — Request Rate:**

1. Click "Add visualization"
2. Query: `rate(app_requests_total[5m])`
3. Visualization: **Time series** (line graph)
4. Title: **"Request Rate (req/sec)"**
5. Apply

**Panel 3 — Temperature:**

1. Add visualization
2. Query: `app_temperature_celsius`
3. Visualization: **Gauge** (circular dial)
4. Title: **"Current Temperature (°C)"**
5. Min: 10, Max: 40 (optional, for gauge scaling)
6. Apply

**Panel 4 — Request Latency (optional):**

1. Add visualization
2. Query: `avg(rate(app_request_latency_seconds_sum[5m]) / rate(app_request_latency_seconds_count[5m]))`
3. Visualization: **Stat**
4. Title: **"Avg Latency (sec)"**
5. Unit: seconds
6. Apply

### Step 5: Save Your Dashboard

1. Click **Save** (top right, or `Ctrl+S`)
2. Name it: **"My First Dashboard"**
3. Click **Save**

> **Bonus:** If you refresh the page or wait a few minutes, the metrics will update automatically as Prometheus collects new data!

### Step 6: Modify Panel Settings

Click on any panel title to edit it.

**Try editing the temperature gauge:**

1. Click on the "Current Temperature" panel title
2. Click the Edit button (pencil icon)
3. Scroll down in the right panel to **"Thresholds"**
4. Set color thresholds:
   - `0` = blue (cold)
   - `25` = green (comfortable)
   - `35` = red (hot)
5. Click Apply

Now the gauge color changes based on temperature!

### Step 7: Understand Grafana Concepts

| Concept          | Description                                                   |
| ---------------- | ------------------------------------------------------------- |
| **Dashboards**   | A collection of panels showing related metrics                |
| **Panels**       | Individual visualizations (graph, gauge, stat, bar, etc.)     |
| **Queries**      | PromQL expressions that fetch data from Prometheus            |
| **Data Sources** | Where panels get data (Prometheus, Loki, Elasticsearch, etc.) |
| **Variables**    | Parameterize dashboards (e.g., `${job}` selector)             |
| **Alerts**       | Trigger notifications based on metric thresholds              |

### Step 8: Experiment with Visualizations

1. Duplicate the "Active Users" panel (right-click → Duplicate)
2. Change visualization type to:
   - **Time series** (line graph) → shows trend over time
   - **Bar gauge** → compact colored bars
   - **Stat** → just the number
   - **Gauge** → circular dial
3. See which is most intuitive for each metric

**Best practices:**

| Visualization | Best For                                           |
| ------------- | -------------------------------------------------- |
| Time series   | Trends (requests, latency, temperature over time)  |
| Stat / Gauge  | Current snapshots (active users, CPU%, memory%)    |
| Table         | Lists/matrices (pod details, error logs)           |
| Pie / Donut   | Proportions (requests by endpoint, errors by type) |

### Day 5 Checkpoint

- [x] Grafana running on localhost:3000
- [x] Prometheus added as a data source
- [ ] Created a multi-panel dashboard
- [ ] Panels show real data from simple_app.py
- [ ] Understood Prometheus as Grafana's data backend
- [ ] Experimented with different visualization types
- [ ] Saved dashboard and confirmed persistence

---

## Cleanup

```bash
# Stop services (keep data)
docker stop prometheus grafana

# Restart services
docker start prometheus grafana

# Remove containers entirely (lose dashboard configs)
docker stop prometheus grafana
docker rm prometheus grafana

# Wipe Prometheus data (fresh start)
docker stop prometheus
rm -rf ./prometheus-data/
docker start prometheus
```

Stop `simple_app.py` with `Ctrl+C` in the terminal where it's running.

---

## Key Differences from kube-prometheus-stack

|                            | Lightweight (Docker)          | kube-prometheus-stack |
| -------------------------- | ----------------------------- | --------------------- |
| **RAM usage**              | ~1.5 GB                       | ~3 GB                 |
| **Startup time**           | < 30 seconds                  | ~5 minutes            |
| **Dashboard building**     | From scratch (you learn more) | Pre-built             |
| **PromQL practice**        | Hands-on                      | Optional              |
| **K8s cluster monitoring** | ✗                             | ✓                     |
| **Prometheus Operator**    | ✗                             | ✓                     |
| **Alert Manager**          | ✗                             | ✓                     |
| **Control**                | Full                          | Managed               |

**Trade-off:** You learn the fundamentals deeply, then can add kube-prometheus later when you have more RAM or on a cloud cluster.

---

## Troubleshooting

### Prometheus Issues

**Q: `simple_app` shows "DOWN" in targets?**

1. Verify app is running: `curl http://localhost:8000/metrics`
2. Wait 15+ seconds after starting app for scrape
3. Check Prometheus logs: `docker logs prometheus`
4. Try `host.docker.internal` vs `localhost` in targets

**Q: Can't access http://localhost:9090?**

1. Check container is running: `docker ps | grep prometheus`
2. Check port isn't in use: `lsof -i :9090`
3. Restart container: `docker restart prometheus`
4. Check logs: `docker logs prometheus`

**Q: Container keeps restarting with "open prometheus.yml: no such file or directory"?**

1. Volume mount path is wrong
2. `cd` into the directory first: `cd ~/Documents/learnk8s/monitoring-setup`
3. Verify with `pwd`
4. Check file exists: `ls -la prometheus.yml`
5. Use absolute path instead of `$(pwd)`
6. Path is **case-sensitive** — use `learnk8s` not `LearnK8s`

**Q: Docker target failing?**

This is normal. Docker metrics require `daemon.json` configuration. Safe to ignore for learning.

### Grafana Issues

**Q: Can't connect to Prometheus data source?**

1. Use `http://host.docker.internal:9090` (not localhost)
2. Check both containers are running: `docker ps`
3. Manually test: `curl http://localhost:9090/api/v1/query?query=up`

**Q: Panels show "No data"?**

1. Confirm `simple_app.py` is running: `curl http://localhost:8000/metrics`
2. Confirm Prometheus scrapes it: http://localhost:9090/targets
3. Test query in Prometheus first
4. Wait 15+ seconds for first scrape
5. Adjust time range to "last 1h"

**Q: Grafana password not working?**

```bash
docker exec grafana grafana-cli admin reset-admin-password admin
```

### Python App Issues

**Q: Can't activate venv?**

```bash
python3 -m venv .venv
source .venv/bin/activate
```

If still fails, just use `pip3 install prometheus-client` directly.

**Q: `ImportError` for `prometheus_client`?**

```bash
pip install prometheus-client
```

**Q: App crashes on startup?**

```bash
lsof -i :8000        # Find what's using the port
kill -9 <PID>        # Kill it
python3 simple_app.py  # Restart
```

---

## Next Steps After Day 5

### Immediate

1. Experiment with more PromQL queries
   - Aggregation: `sum(app_requests_total)`
   - Filtering: `app_requests_total{method="GET"}`
   - Time ranges: `rate(app_requests_total[1m])` vs `[5m]`

2. Add more panels to your dashboard

3. Try importing a community dashboard from https://grafana.com/grafana/dashboards/

### Production Transition

When you deploy to Kubernetes:

1. Keep your Prometheus instance (for app metrics)
2. Add kube-prometheus-stack (for cluster metrics)
3. Grafana talks to both Prometheus instances
4. You get app metrics + infrastructure metrics together

### For Your Own Applications

```python
from prometheus_client import Counter, Gauge, start_http_server

requests = Counter('my_app_requests', 'Total requests')
active_users = Gauge('my_app_active_users', 'Current users')

start_http_server(8000)  # Expose /metrics

# In your app:
requests.inc()
active_users.set(42)
```

Then add to Prometheus targets:

```yaml
- targets: ["your-app:8000"]
```
