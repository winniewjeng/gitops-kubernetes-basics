# "Updating the running docker container" hang usually means Docker daemon communication issue or corrupted Minikube state. Fresh start should fix it

# check minikube status
minikube status

# stop minikube
minikube stop

# If minikube stop hangs after 30 seconds, press Ctrl+C and then force delete
minikube delete --purge

# Alternative (if delete is too slow), kill Docker containers directly
docker ps -a | grep minikube
docker rm -f <container-id>    # Force remove the minikube container

# restart
minikube start --driver=docker --memory=3072 --cpus=2

# Once restarted
kubectl get nodes              # Verify cluster is ready