# ConfigMaps & Secrets: Deep Dive

## Overview

ConfigMaps and Secrets are Kubernetes resources for storing configuration data that pods need at runtime.

**Key difference:**

- **ConfigMap**: Non-sensitive config (database host, feature flags, app settings)
- **Secret**: Sensitive data (passwords, API keys, certificates) — base64-encoded

---

## Part 1: ConfigMaps

### Creating ConfigMaps

#### Method 1: From Literal Values (command line)

```bash
kubectl create configmap app-config \
  --from-literal=ENV=development \
  --from-literal=LOG_LEVEL=debug \
  --from-literal=DATABASE_HOST=postgres.default.svc.cluster.local
```

**View it:**

```bash
kubectl get configmap app-config
kubectl describe configmap app-config
kubectl get configmap app-config -o yaml
```

#### Method 2: From a File

Create a config file: `config/app.properties`

```properties
ENV=production
LOG_LEVEL=info
DATABASE_HOST=prod-db.example.com
MAX_CONNECTIONS=100
TIMEOUT=30
```

Create ConfigMap from the file:

```bash
kubectl create configmap app-config --from-file=config/app.properties
```

#### Method 3: From YAML Manifest (declarative)

Create: `manifests/app-config.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  ENV: "production"
  LOG_LEVEL: "info"
  DATABASE_HOST: "postgres.default.svc.cluster.local"
  MAX_CONNECTIONS: "100"
  # Multi-line values work too
  nginx.conf: |
    server {
      listen 80;
      server_name example.com;
      location / {
        proxy_pass http://backend:8080;
      }
    }
```

Apply it:

```bash
kubectl apply -f manifests/app-config.yaml
```

---

### Using ConfigMaps in Pods

#### Option 1: As Environment Variables

Create: `manifests/app-with-configmap.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: nginx:1.25
          env:
            # Single key from ConfigMap
            - name: ENV
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: ENV

            # Another key
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: LOG_LEVEL

            # Or import ALL keys at once
            # (each key becomes an env var)
          envFrom:
            - configMapRef:
                name: app-config
```

Apply and verify:

```bash
kubectl apply -f manifests/app-with-configmap.yaml
kubectl get pods
kubectl exec -it <pod-name> -- env | grep -E "ENV|LOG_LEVEL"
```

#### Option 2: As Volume Mounts (files in the container)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-volume
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp-volume
  template:
    metadata:
      labels:
        app: myapp-volume
    spec:
      containers:
        - name: myapp
          image: nginx:1.25
          volumeMounts:
            - name: config-volume
              mountPath: /etc/config # Files appear here
      volumes:
        - name: config-volume
          configMap:
            name: app-config
```

**What happens:**

- Each key in the ConfigMap becomes a file
- `ENV` → `/etc/config/ENV` (content: "production")
- `LOG_LEVEL` → `/etc/config/LOG_LEVEL` (content: "info")
- `nginx.conf` → `/etc/config/nginx.conf` (full file content)

**Verify:**

```bash
kubectl apply -f manifests/app-with-configmap-volume.yaml
kubectl exec -it <pod-name> -- ls -la /etc/config
kubectl exec -it <pod-name> -- cat /etc/config/ENV
kubectl exec -it <pod-name> -- cat /etc/config/nginx.conf
```

---

### Updating ConfigMaps

```bash
# Edit the ConfigMap directly
kubectl edit configmap app-config

# Or update from file
kubectl apply -f manifests/app-config.yaml
```

**Important:** Pods don't automatically restart when ConfigMap changes!

- Env vars: pod needs restart to pick up changes
- Volume mounts: files update automatically (eventually — can take up to 60 seconds)

**Force pod restart after ConfigMap update:**

```bash
kubectl rollout restart deployment myapp
```

---

## Part 2: Secrets

### Creating Secrets

#### Method 1: From Literal Values

```bash
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=supersecret123
```

**View it:**

```bash
kubectl get secrets
kubectl describe secret db-creds
kubectl get secret db-creds -o yaml  # Values are base64-encoded
```

**Decode a secret value:**

```bash
kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 --decode
```

#### Method 2: From Files

Create files:

```bash
echo -n "admin" > username.txt
echo -n "supersecret123" > password.txt
```

Create Secret:

```bash
kubectl create secret generic db-creds \
  --from-file=username=username.txt \
  --from-file=password=password.txt
```

Clean up local files (important!):

```bash
rm username.txt password.txt
```

#### Method 3: From YAML Manifest

**Note:** You must base64-encode values yourself in YAML.

Encode values:

```bash
echo -n "admin" | base64          # YWRtaW4=
echo -n "supersecret123" | base64 # c3VwZXJzZWNyZXQxMjM=
```

Create: `manifests/db-secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-creds
type: Opaque # Generic secret type
data:
  username: YWRtaW4= # base64 of "admin"
  password: c3VwZXJzZWNyZXQxMjM= # base64 of "supersecret123"


# Alternative: use stringData (plain text, K8s encodes it for you)
# stringData:
#   username: admin
#   password: supersecret123
```

Apply:

```bash
kubectl apply -f manifests/db-secret.yaml
```

---

### Using Secrets in Pods

#### Option 1: As Environment Variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-secrets
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-with-secrets
  template:
    metadata:
      labels:
        app: app-with-secrets
    spec:
      containers:
        - name: myapp
          image: nginx:1.25
          env:
            # Single key from Secret
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: db-creds
                  key: username

            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-creds
                  key: password

            # Or import all keys at once
          envFrom:
            - secretRef:
                name: db-creds
```

**Verify:**

```bash
kubectl apply -f manifests/app-with-secrets.yaml
kubectl exec -it <pod-name> -- env | grep DB_
```

#### Option 2: As Volume Mounts

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-secret-volume
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-with-secret-volume
  template:
    metadata:
      labels:
        app: app-with-secret-volume
    spec:
      containers:
        - name: myapp
          image: nginx:1.25
          volumeMounts:
            - name: secret-volume
              mountPath: /etc/secrets # Secrets appear as files here
              readOnly: true # Best practice: read-only
      volumes:
        - name: secret-volume
          secret:
            secretName: db-creds
```

**What happens:**

- `username` → `/etc/secrets/username` (content: "admin")
- `password` → `/etc/secrets/password` (content: "supersecret123")

**Verify:**

```bash
kubectl apply -f manifests/app-with-secret-volume.yaml
kubectl exec -it <pod-name> -- ls -la /etc/secrets
kubectl exec -it <pod-name> -- cat /etc/secrets/username
kubectl exec -it <pod-name> -- cat /etc/secrets/password
```

---

## Practical Example: Full App with ConfigMap & Secret

### Scenario

Deploy a web app that needs:

- Database credentials (Secret)
- App configuration (ConfigMap)

### Step 1: Create the ConfigMap

`manifests/webapp-config.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  API_TIMEOUT: "30"
  FEATURES_ENABLED: "auth,payments,analytics"
```

### Step 2: Create the Secret

`manifests/webapp-secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secret
type: Opaque
stringData: # Use stringData for plain text (K8s encodes it)
  db-username: "dbadmin"
  db-password: "MySecureP@ssw0rd!"
  api-key: "sk_live_1234567890abcdef"
```

### Step 3: Create the Deployment

`manifests/webapp-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: webapp
          image: nginx:1.25 # Replace with your app image

          # Inject ConfigMap as environment variables
          envFrom:
            - configMapRef:
                name: webapp-config

          # Inject specific Secret keys
          env:
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: webapp-secret
                  key: db-username

            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: webapp-secret
                  key: db-password

            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: webapp-secret
                  key: api-key

          ports:
            - containerPort: 80
```

### Step 4: Apply Everything

```bash
kubectl apply -f manifests/webapp-config.yaml
kubectl apply -f manifests/webapp-secret.yaml
kubectl apply -f manifests/webapp-deployment.yaml
```

### Step 5: Verify

```bash
# Check pods are running
kubectl get pods -l app=webapp

# Exec into a pod and check env vars
kubectl exec -it <pod-name> -- env | grep -E "APP_ENV|DB_USERNAME|API_KEY"
```

---

## Best Practices

### ConfigMaps

✅ Use for non-sensitive config  
✅ One ConfigMap per app or per environment  
✅ Version control the YAML manifests  
✅ Use meaningful key names (`DATABASE_HOST` not `host`)

❌ Don't store secrets in ConfigMaps  
❌ Don't make them too large (1 MB limit)

### Secrets

✅ Use for passwords, tokens, certificates  
✅ Mount as volumes when possible (more secure than env vars)  
✅ Use `readOnly: true` on volume mounts  
✅ Enable encryption at rest in production clusters  
✅ Use external secret managers (Vault, AWS Secrets Manager) for real production

❌ Never commit plain-text secrets to Git  
❌ Don't print secrets in logs  
❌ Don't use Secrets for large files (use PersistentVolumes)

### General

- Use `stringData` in YAML for plain text (easier than base64 encoding)
- Prefer declarative YAML over imperative `kubectl create`
- Use namespaces to isolate secrets between environments
- Rotate secrets regularly
- Limit RBAC access to who can read secrets

---

## Common Commands Cheat Sheet

```bash
# ConfigMaps
kubectl create configmap <name> --from-literal=KEY=VALUE
kubectl create configmap <name> --from-file=<file>
kubectl get configmaps
kubectl describe configmap <name>
kubectl get configmap <name> -o yaml
kubectl delete configmap <name>

# Secrets
kubectl create secret generic <name> --from-literal=KEY=VALUE
kubectl create secret generic <name> --from-file=<file>
kubectl get secrets
kubectl describe secret <name>
kubectl get secret <name> -o yaml
kubectl get secret <name> -o jsonpath='{.data.KEY}' | base64 --decode
kubectl delete secret <name>

# Edit in-place
kubectl edit configmap <name>
kubectl edit secret <name>

# Force restart pods after config change
kubectl rollout restart deployment <deployment-name>
```

---

## Troubleshooting

### Problem: Pod can't find ConfigMap or Secret

**Error:** `Error: couldn't find key <key> in ConfigMap <name>`

**Solutions:**

1. Verify the ConfigMap/Secret exists:

   ```bash
   kubectl get configmap <name>
   kubectl get secret <name>
   ```

2. Check you're in the right namespace:

   ```bash
   kubectl get configmap <name> -n <namespace>
   ```

3. Verify the key name matches exactly (case-sensitive)

### Problem: Env vars not updating after ConfigMap change

**Cause:** Pods don't auto-restart on ConfigMap changes.

**Solution:**

```bash
kubectl rollout restart deployment <name>
```

### Problem: Secret values showing as asterisks

**Cause:** `kubectl describe` hides secret values for security.

**Solution:** Use `-o yaml` to see base64-encoded values:

```bash
kubectl get secret <name> -o yaml
```

Decode:

```bash
kubectl get secret <name> -o jsonpath='{.data.password}' | base64 --decode
```

---

## Next Steps

Now that you understand ConfigMaps and Secrets:

- Day 3: Learn Helm (which uses ConfigMaps/Secrets extensively)
- Day 6: See how GitOps handles secrets securely with Sealed Secrets or external secret operators
- Production: Integrate with external secret managers (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault)

---

**Ready to continue with Day 2?** Try the practice exercises:

1. Create a ConfigMap from a file
2. Deploy an app that reads the ConfigMap as environment variables
3. Update the ConfigMap and restart the deployment
4. Create a Secret and mount it as a volume
