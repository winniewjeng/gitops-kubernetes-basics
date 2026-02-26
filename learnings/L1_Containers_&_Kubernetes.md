# DAY 1 — FOUNDATIONS: CONTAINERS & LOCAL KUBERNETES

## Goal

Understand what containers and Kubernetes are, install tools, and run your first pod.

## Concepts to Learn

- What is a container? (lightweight, isolated process with its own filesystem)
- What is Kubernetes? (an orchestrator that manages containers at scale)
- Key K8s objects: Pod, Deployment, Service, Namespace
- Control plane vs worker nodes (conceptual — your local cluster handles both)

---

## STEP 1: Install Docker Desktop

Docker provides the container runtime that Kubernetes uses under the hood.

1. **Download Docker Desktop for Mac:**
   https://www.docker.com/products/docker-desktop/

2. **Install it** (drag to Applications), launch it, and accept the terms.

3. **Verify:**
   ```bash
   docker --version
   docker run hello-world
   ```
   You should see "Hello from Docker!" — congratulations, you ran a container.

---

## STEP 2: Install Homebrew (if you don't have it)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

## STEP 3: Install kubectl (the Kubernetes CLI)

```bash
brew install kubectl
kubectl version --client
```

`kubectl` is how you talk to any Kubernetes cluster.

---

## STEP 4: Install Minikube (local Kubernetes cluster)

Minikube runs a single-node K8s cluster on your Mac — perfect for learning.

```bash
brew install minikube
```

**Start your cluster** (uses Docker as the driver):

```bash
minikube start --driver=docker --memory=3072 --cpus=2
```

> **Note:** This allocates 3 GB to Minikube (leaves ~5 GB for macOS + other apps) and 2 CPU cores (plenty for learning; you have 8 available)

**Verify:**

```bash
kubectl cluster-info
kubectl get nodes          # Should show one node in "Ready" state
```

---

## STEP 5: Run your first Pod

A Pod is the smallest deployable unit in K8s (usually one container).

```bash
kubectl run my-nginx --image=nginx --port=80
kubectl get pods           # Wait until STATUS = "Running"
kubectl describe pod my-nginx   # See all the details
kubectl describe pod my-nginx | grep -A 10 Events  # see start up event sequence
```

**Expose it so you can visit in a browser:**

This creates a Service that makes the `my-nginx` pod reachable from outside the cluster by opening a port on the Minikube node:

```bash
kubectl expose pod my-nginx --type=NodePort --port=80
kubectl get svc my-nginx   # See what gets created
minikube service my-nginx --url  # Get the URL
```

Open that URL — you'll see the nginx welcome page.

---

## STEP 6: Create a Deployment (self-healing containers)

**Clean up the single pod first:**

```bash
kubectl delete pod my-nginx
kubectl delete service my-nginx
```

**Now create a Deployment** (manages replicas + rolling updates):

```bash
kubectl create deployment nginx-deploy --image=nginx --replicas=3
kubectl get deployments
kubectl get pods           # 3 pods running!
```

**ReplicaSet Reference:** A Kubernetes controller that ensures a specific number of pod replicas are always running. It continuously checks: "Are 3 pods running right now?" If a pod dies, ReplicaSet immediately creates a new one. If you manually create extra pods, ReplicaSet deletes them to match the desired count.

**Try deleting one pod** — K8s will recreate it automatically:

```bash
kubectl delete pod <one-of-the-pod-names>
kubectl get pods           # Back to 3 within seconds
```

**Expose the deployment** (create a Service):

```bash
kubectl expose deployment nginx-deploy --type=NodePort --port=80
minikube service nginx-deploy --url
```

---

## STEP 7: Explore with the Dashboard

```bash
minikube dashboard
```

This opens a web UI showing your cluster's state — great for visual learners.

---

## Understanding Service Types

When you expose a pod or deployment, you choose a Service type. Here's what each does:

### **ClusterIP** (default)

- Internal-only access within the cluster
- No external traffic can reach it
- **Use for:** internal databases, backend services, inter-pod communication
- **Example:**
  ```bash
  kubectl expose deployment db --type=ClusterIP --port=5432
  ```

### **NodePort** (what we used)

- Opens a port on every node (in range 30000–32767)
- Reachable from outside via `nodeIP:nodePort`
- **Use for:** local dev, testing, demos
- **Example:**
  ```bash
  kubectl expose deployment nginx --type=NodePort --port=80
  ```
- **In Minikube:**
  ```bash
  minikube service nginx --url  # gives you the access URL
  ```

### **LoadBalancer**

- Requests a load balancer from the cloud provider (AWS/GCP/Azure)
- Gives you a public IP (or internal LB in private networks)
- Requires infrastructure support (MetalLB for private environments)
- **Use for:** production public APIs and web apps
- **In Minikube:** use `minikube tunnel` to make it work locally

### **ExternalName**

- Creates a DNS alias inside the cluster (no traffic proxy)
- Resolves internal name to an external service
- **Use for:** referencing external APIs without hardcoding their hostname

**Example:**

```yaml
kind: Service
metadata:
  name: stripe-api
spec:
  type: ExternalName
  externalName: api.stripe.com
```

Inside cluster, pods call `http://stripe-api` instead of `http://api.stripe.com`

### Quick Decision Tree

- Need external access from outside cluster? → **LoadBalancer** (cloud) or **NodePort** (dev)
- Only internal access? → **ClusterIP**
- Simple DNS alias to external service? → **ExternalName**

---

## Pod vs Service vs Deployment Reference

### **Pod**

- The actual running container(s) in the cluster
- Ephemeral — dies if unhealthy, can be deleted anytime
- Smallest deployable unit in Kubernetes
- Rarely created directly in production (dangerous — no recovery)
- Usually contains one container, sometimes multiple (sidecar pattern)

### **Service**

- A networking abstraction that provides stable access to pods
- Assigns a stable IP address and DNS name
- Routes traffic to one or more pods (via labels)
- Survives pod death — still exists even if all pods are deleted
- Acts as a "load balancer" across multiple pod replicas
- **Types:** ClusterIP (internal), NodePort (local dev), LoadBalancer (cloud), ExternalName (DNS alias)

### **Deployment**

- A controller that manages pod replicas
- Ensures desired number of pod copies are running at all times
- If a pod dies, Deployment automatically creates a replacement
- Handles rolling updates (gradually replace old pods with new ones)
- The production-standard way to run workloads
- You specify desired state; Deployment ensures reality matches

---

## Other Important Kubernetes Resources

### **Namespace**

- Virtual partitions within a cluster (like folders)
- Isolate resources, set quotas, apply policies per namespace
- **Example:** namespaces for dev, staging, production
- **List:**
  ```bash
  kubectl get namespaces
  ```

### **ConfigMap**

- Stores non-sensitive configuration as key-value pairs
- Can inject as env vars, files, or command arguments into pods
- **Example:** app version, database host, feature flags
- Pods can read it at runtime without rebuilding container

### **Secret**

- Stores sensitive data (passwords, API tokens, certificates)
- Base64-encoded by default (add encryption in production)
- Mounted as files or env vars into pods
- **Example:** database password, Docker registry credentials

### **PersistentVolume (PV)**

- Persistent storage that survives pod restarts
- Decoupled from pod lifecycle
- **Example:** database data, user uploads
- Requested by pods via PersistentVolumeClaim (PVC)

### **StatefulSet**

- Like Deployment, but for stateful applications
- Pods have stable, persistent identities (`pod-0`, `pod-1`, etc.)
- **Use for:** databases, message queues, any app needing stable storage/identity
- **Example:**
  ```bash
  kubectl create statefulset mysql
  ```

### **DaemonSet**

- Ensures a pod runs on every node in the cluster
- Automatically added to new nodes
- **Use for:** monitoring agents, log collectors, system daemons
- **Example:** Prometheus node exporter on all nodes

### **Job**

- Runs a workload to completion (not continuously)
- Useful for batch processing, one-off tasks, cron-like jobs
- Automatically cleans up when done
- **Example:** data migration, backup job

### **CronJob**

- Scheduled job that runs on a schedule (like cron)
- **Example:** run cleanup job every night at 2 AM
- **Use for:** periodic maintenance, reports

### **Ingress**

- HTTP(S) routing rules for external traffic
- More powerful than NodePort; enables path-based routing, SSL/TLS
- **Example:** `api.com/users` → user-service, `api.com/auth` → auth-service
- Requires an Ingress Controller (NGINX, Traefik, etc.)

---

## Which Controllers to Use: Decision Tree

### What should you CREATE (user-facing):

#### **Deployment**

- For stateless apps (web servers, APIs, workers)
- Most common workload type
- **Example:** nginx, web app backend, REST API
- **Command:**
  ```bash
  kubectl create deployment app-name --image=image:tag
  ```

#### **StatefulSet**

- For stateful apps (databases, message queues)
- Pods have stable identities (`pod-0`, `pod-1`, etc.)
- Persistent storage for each pod
- **Example:** PostgreSQL, Redis, Kafka, MySQL

#### **DaemonSet**

- Run a pod on every node in the cluster
- Automatically scales as nodes are added
- **Use for:** monitoring agents, log collectors, system utilities
- **Example:** Prometheus node exporter, Fluentd

#### **Job**

- Run a workload once to completion
- Useful for batch processing, one-off tasks
- Automatically retries on failure
- Cleans up when done
- **Example:** data migration, backup, batch ETL

#### **CronJob**

- Schedule a Job to run at specific times
- Uses cron syntax (`0 2 * * * = 2 AM daily`)
- **Use for:** periodic maintenance, reports, cleanup
- **Example:** run backup every night at 2 AM

### What you should AVOID:

#### **Pod (direct creation)**

- Ephemeral — dies, gets replaced, no self-healing
- No recovery if it crashes
- **Only use for:** debugging temporarily (`kubectl run debug-pod --image=busybox`)
- **Never** for production workloads

#### **ReplicaSet**

- Deployment creates it automatically for you
- You manage Deployments, not ReplicaSets directly
- Don't create ReplicaSets manually

### What's AUTOMATICALLY HANDLED (don't worry about):

- **ReplicaSet** — Deployment creates it
- **Endpoints** — Service creates/updates it (list of pod IPs)
- **Node Controller** — monitors nodes automatically
- **Service Controller** — manages IPs/DNS automatically

### Quick Decision Tree

- Is it a web app or stateless API? → **Deployment**
- Is it a database or stateful service? → **StatefulSet**
- Does it run once and exit? → **Job**
- Does it run on a schedule? → **CronJob**
- Should it run on every node? → **DaemonSet**
- Just need to test/debug something? → **Pod** (temporary only)

---

## Cleanup (optional, or keep for Day 2)

```bash
kubectl delete deployment nginx-deploy
kubectl delete service nginx-deploy
```

---

## Day 1 Checkpoint

- [✓] Docker installed and running
- [✓] kubectl installed
- [✓] Minikube cluster running
- [✓] Created a Pod, a Deployment, and a Service
- [✓] Accessed nginx in the browser
- [✓] Opened the Minikube dashboard
