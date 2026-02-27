# Helm Directory Organization

This directory contains all Helm-related files for the LearnK8s project, organized by purpose.

## Directory Structure

```
helm/
├── organization_structure.md     # This file
├── my-first-chart/               # Custom Helm chart (created with helm create)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── templates/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   └── ...
│   └── charts/
└── values/                       # Custom values files for external charts
    ├── my-nginx-values.yaml      # Minimal overrides for bitnami/nginx
    └── my-nginx-values-maxx.yaml # Detailed production-ready overrides
```

## Purpose

### `my-first-chart/`

**Type:** Custom Helm chart (your own creation)

**Created with:** `helm create my-first-chart`

**Purpose:** Learn how Helm charts work internally by creating and customizing your own chart from scratch.

**Usage:**

```bash
# Install the custom chart
helm install my-release ./helm/my-first-chart

# Upgrade after modifying values.yaml
helm upgrade my-release ./helm/my-first-chart

# Uninstall
helm uninstall my-release
```

**Key Files:**

- [`Chart.yaml`](my-first-chart/Chart.yaml) — Chart metadata (name, version, description)
- [`values.yaml`](my-first-chart/values.yaml) — Default configuration values
- `templates/` — Kubernetes YAML templates with Go templating (`{{ .Values.xxx }}`)

**When to modify:**

- Learning Helm templating and chart structure
- Building custom applications not available in public repos
- Creating internal company charts

### `values/`

**Type:** Custom configuration overrides for **external community charts**

**Purpose:** Store reusable configuration files that customize charts from public repositories (like `bitnami/nginx`) without modifying the original chart.

**Charts referenced:**

- [`bitnami/nginx`](https://github.com/bitnami/charts/tree/main/bitnami/nginx)

#### `my-nginx-values.yaml`

**Purpose:** Minimal configuration overrides for quick testing

**Overrides:**

```yaml
replicaCount: 2 # Run 2 nginx pods
service:
  type: NodePort # Expose via NodePort for Minikube access
```

**Usage:**

```bash
# Install bitnami/nginx with custom values
helm install my-nginx bitnami/nginx -f helm/values/my-nginx-values.yaml

# Upgrade with updated values
helm upgrade my-nginx bitnami/nginx -f helm/values/my-nginx-values.yaml
```

**When to use:**

- Quick prototyping and testing
- Learning basic Helm value overrides
- Local development on Minikube

#### `my-nginx-values-maxx.yaml`

**Purpose:** Production-ready configuration with comprehensive overrides

**Overrides:**

```yaml
replicaCount: 2 # Pod count
image:
  tag: 1.25.4-debian-12-r2 # Pinned version for repeatability
service:
  type: NodePort
  nodePorts:
    http: 30080 # Fixed NodePort (predictable access)
resources:
  requests: # Scheduler guarantees
    cpu: 100m
    memory: 128Mi
  limits: # Resource caps
    cpu: 300m
    memory: 256Mi
livenessProbe: # Health checks
  enabled: true
  initialDelaySeconds: 15
readinessProbe: # Readiness checks
  enabled: true
  initialDelaySeconds: 5
podLabels: # Custom labels
  app: my-nginx
  tier: web
```

**Usage:**

```bash
# Install with production-ready config
helm install my-nginx-prod bitnami/nginx -f helm/values/my-nginx-values-maxx.yaml

# Check resource usage
kubectl top pods
```

**When to use:**

- Learning production best practices
- Setting resource limits and probes
- Preparing for staging/production deployments

## Workflow Examples

### Using External Charts with Custom Values

**Scenario:** Deploy nginx using bitnami's chart with your own configuration

```bash
# 1. Add the bitnami repository (if not already added)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. Install with minimal overrides
helm install my-nginx bitnami/nginx -f helm/values/my-nginx-values.yaml

# 3. Check deployment
kubectl get pods
minikube service my-nginx --url

# 4. Upgrade to production-ready config
helm upgrade my-nginx bitnami/nginx -f helm/values/my-nginx-values-maxx.yaml

# 5. View release history
helm history my-nginx

# 6. Rollback if needed
helm rollback my-nginx 1

# 7. Clean up
helm uninstall my-nginx
```

### Using Your Custom Chart

**Scenario:** Deploy your own application using the custom chart

```bash
# 1. Test render (dry-run)
helm template test-release ./helm/my-first-chart

# 2. Install the chart
helm install my-app ./helm/my-first-chart

# 3. Modify values in my-first-chart/values.yaml
# Example: change replicaCount from 3 to 5

# 4. Upgrade with new values
helm upgrade my-app ./helm/my-first-chart

# 5. Access the service
minikube service my-app-my-first-chart --url

# 6. Clean up
helm uninstall my-app
```

## Key Differences

| Aspect              | `my-first-chart/`                         | `values/*.yaml`                                            |
| ------------------- | ----------------------------------------- | ---------------------------------------------------------- |
| **Type**            | Complete Helm chart                       | Values override files                                      |
| **Contains**        | Templates, Chart.yaml, values.yaml        | Only configuration overrides                               |
| **Used for**        | Your custom applications                  | Customizing external charts                                |
| **Installation**    | `helm install name ./helm/my-first-chart` | `helm install name bitnami/nginx -f helm/values/file.yaml` |
| **Modification**    | Edit templates and Chart.yaml             | Edit only values (chart unchanged)                         |
| **Version control** | Entire chart is tracked                   | Only overrides tracked                                     |
| **Learning focus**  | Chart structure & templating              | Configuration management                                   |

## Design Philosophy

This structure separates concerns:

1. **Custom charts** (`my-first-chart/`) — for applications you build
2. **Value overrides** (`values/`) — for applications others built

**Benefits:**

- Clear separation between "things I create" and "things I configure"
- Easy to version control and track changes
- Follows Helm best practices
- Scalable as you add more charts and configurations

## Related Learning Materials

- [L3_Helm_K8s_Manager.md](../Learnings/L3_Helm_K8s_Manager.md) — Helm fundamentals
- [nginx-deployment.yaml](../manifests/nginx-deployment.yaml) — Plain Kubernetes manifests (pre-Helm approach)
- [nginx-service.yaml](../manifests/nginx-service.yaml) — Service configuration example (pre-Helm approach)

## Next Steps

1. **Experiment with `my-first-chart/`:**
   - Modify [`values.yaml`](my-first-chart/values.yaml) to change replicas, service types
   - Explore templates to understand Go templating
   - Try `helm template` to see rendered YAML

2. **Try different external charts:**
   - `helm install my-db bitnami/mysql -f helm/values/my-mysql-values.yaml`
   - Create new values files for other charts (PostgreSQL, Redis, etc.)

3. **Learn advanced Helm features:**
   - Chart dependencies (`charts/` directory)
   - Helm hooks (pre-install, post-upgrade)
   - Helm tests (`templates/tests/`)
   - Chart packaging (`helm package`)

## Common Commands

```bash
# List all installed releases
helm list

# Show chart values
helm show values bitnami/nginx

# View rendered templates (dry-run)
helm template my-release ./helm/my-first-chart

# Get release history
helm history my-nginx

# Rollback to previous version
helm rollback my-nginx 1

# Uninstall and clean up
helm uninstall my-nginx
```

## Tips

- **Always use values files** (not `--set`) for reproducible deployments
- **Pin image tags** in production values files (see `my-nginx-values-maxx.yaml`)
- **Test with `helm template`** before installing
- **Keep values files in version control** alongside code
- **Use meaningful release names** that indicate environment (e.g., `my-nginx-dev`, `my-nginx-prod`)
