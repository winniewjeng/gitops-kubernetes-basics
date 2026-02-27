# Day 3 — Helm: The Kubernetes Package Manager

## Goal

Understand Helm charts, install community charts, and create your own.

## Concepts to Learn

- What is Helm? (a package manager for K8s — think "apt/brew for clusters")
- Charts: a bundle of K8s YAML templates + default values
- Releases: an installed instance of a chart
- `values.yaml`: how you customize a chart without editing templates
- Helm repositories
- `templates/`: deployment.yaml, service.yaml, etc.

## Step 1: Install Helm

```bash
$ brew install helm
$ helm version
```

## Step 2: Add a Chart Repository

Register a remote chart repo so Helm knows where to search and download charts. Without this step, Helm has no idea where charts live. After adding, you can reference charts by `repo-name/chart-name` instead of full URLs.

```bash
$ helm repo add bitnami https://charts.bitnami.com/bitnami  # Saves the name bitnami as a shortcut for the URL
$ helm repo update        # Refresh index from all repos (like apt-get update)
$ helm search repo bitnami/nginx   # Search for <repo>/<chart>
$ helm repo list          # See all added repositories
```

Bitnami packages popular software into ready-to-deploy formats. They provide:

- Helm charts — pre-built Kubernetes application packages (nginx, MySQL, etc.)
- Docker images — pre-configured container images
- VM images — ready-to-run virtual machines

## Step 3: Install a Chart

`helm install` creates a new release by deploying a chart to your Kubernetes cluster. It follows these steps:

1. Downloading the chart from the repo
2. Reading in the default values from chart's `values.yaml`
3. Takes the YAML template files in templates, replaces the values, and generates final Kubernetes YAML manifests (Deployment, Service, ConfigMap)
4. Applies to cluster for each manifest (equivalent of `kubectl apply -f`)
5. Creates release record - saves the named release (e.g. `my-nginx`) as a Secret in your cluster to track what chart was installed, what values were used, what manifests were created, and allows `helm upgrade`, `helm rollback`, `helm uninstall` later

**In short:** Downloads chart → merges with values → generates YAML → applies to cluster → tracks as release.

```bash
$ helm install my-nginx bitnami/nginx  # using Bitnami's pre-packaged nginx chart instead of writing dozens of lines of YAML
$ kubectl get pods       # Watch the pods come up
# my-nginx-nginx-abc123-xyz     ← Pod name
$ kubectl get services   # Find the service
$ kubectl get all        # See everything Helm created!
$ helm list              # See installed releases
```

**Note that:**

- `my-nginx` is the release name
- `bitnami` is the repository
- `nginx` is the chart, a package containing:
  - `templates/` folder with Kubernetes templates
  - `values.yaml` with default configuration
  - `Chart.yaml` with metadata
- `abc123-xyz` is the random hash from the ReplicaSet

**Check the default values:**

```bash
$ helm show values bitnami/nginx | head -80
```

## Step 4: Customize with --set or a Values File

Update an existing Helm release (e.g. `my-nginx`) using the chart and custom values file.

```bash
$ helm upgrade my-nginx bitnami/nginx --set replicaCount=3
$ kubectl get pods       # Now 3 replicas
```

Or use a file — create `~/Documents/learnK8s/helm/values/my-nginx-values.yaml`

```bash
$ helm upgrade my-nginx bitnami/nginx -f helm/values/my-nginx-values.yaml
```

**In short:** loads the chart (`bitnami/nginx`) → reads/overrides values from `values.yaml` → renders template (the various YAML files) → applies changes to existing revision → stores a new version of the release in the cluster (that can be rolled back if needed)

**Common changes in values file:**

- Change replica count
- Update service type (e.g. NodePort)
- Adjust resources / probes / labels / etc.

## Step 5: Uninstall a Release

```bash
$ helm uninstall my-nginx
$ kubectl get pods       # Cleaned up!
```

## Step 6: Create Your Own Helm Chart

Instead of writing all these files from scratch, Helm gives you a working example chart that uses best practices, has proper Go templating (`{{ .Values.xxx }}`), includes common Kubernetes resources, and is ready to customize for your app.

```bash
$ cd ~/Documents/learnK8s
$ helm create my-first-chart
```

This scaffolds a full chart:

```
my-first-chart/
├── Chart.yaml          # Chart metadata (name, version)
├── values.yaml         # Default config values
├── templates/          # K8s YAML templates with {{ .Values.xxx }}
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml    # (conditional)
│   ├── serviceaccount.yaml
│   ├── hpa.yaml        # HorizontalPodAutoscaler template
│   ├── NOTES.txt       # Post-install instructions shown to users
│   ├── _helpers.tpl    # template helper functions
│   └── tests/          # Test templates
│       └── test-connection.yaml
├── charts/             # Sub-chart dependencies
└── .helmignore         # Files to ignore when packaging
```

Explore the generated files. You can then customize:

- `values.yaml` — set your app's defaults
- `templates/*.yaml` — adjust the Kubernetes manifests
- `Chart.yaml` — update name, version, description

**NOTE:** In practice, `helm create` is rarely used. Most developers (80%) use existing community charts (`helm install bitnami/mysql`), some (15%) fork/modify existing charts, and only a few (5%) create charts from scratch for proprietary apps or internal platform standards. Common alternatives include plain kubectl manifests, Kustomize, or GitOps tools. For learning, `helm create` helps understand how charts work internally.

### Test Render Without Installing

Renders the chart templates locally and prints the final Kubernetes YAML to the terminal:

```bash
$ helm template my-release ./helm/my-first-chart
```

Even though `helm template` doesn't actually install anything, it still needs a release name (e.g. `my-release`) because templates use `{{ .Release.Name }}` in patterns like `name: {{ .Release.Name }}-deployment` in `templates/deployment.yaml`.

### Install Your Chart

```bash
$ helm install my-release ./helm/my-first-chart
$ kubectl get all
$ minikube service my-release-my-first-chart --url  # finds the service name, creates a tunnel from local machine to the minikube cluster, then returns the URL to access the service
```

### Upgrade Your Chart

Modify `values.yaml` (change `replicaCount` to 3), then upgrade:

```bash
$ helm upgrade my-release ./helm/my-first-chart
```

### Clean Up

```bash
$ helm uninstall my-release
```

## Day 3 Checkpoint

- [✓] Helm installed
- [✓] Added bitnami repo, searched & installed a chart
- [✓] Customized a release with --set and values file
- [✓] Created your own Helm chart from scratch
- [✓] Understood Chart.yaml, values.yaml, and templates/
