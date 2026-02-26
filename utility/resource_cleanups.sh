# kubectl get all -A

# Delete resources from default namespace:
kubectl delete deployment nginx-app
kubectl delete service nginx-service
kubectl delete configmap app-config
kubectl delete secret db-creds

# Delete custom namespaces (this also deletes all resources inside them):
kubectl delete namespace dev
kubectl delete namespace staging

# Or delete everything at once:
# kubectl delete all --all              # Deletes all pods, services, deployments in default namespace
# kubectl delete configmap --all         # Deletes all configmaps in default namespace
# kubectl delete secret --all -n default # Deletes all secrets in default namespace (excludes default service-account)
# kubectl delete namespace dev staging   # Deletes dev and staging namespaces

# Verify cleanup:
kubectl get all -A
kubectl get configmap -A
kubectl get secret -A
kubectl get namespace