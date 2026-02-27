##### Minimum Requirements:
#####
##### RAM: 8 GB (4 GB for Minikube, rest for macOS)
##### CPU: 2 cores
##### Disk: 20 GB free space
##### macOS: 10.13+ (High Sierra or newer)
#####
#####
##### Recommended for the full GitOps plan:
#####
##### RAM: 16 GB (you'll allocate 6-8 GB to Minikube)
##### CPU: 4+ cores
##### Disk: 40 GB free

# RAM
sysctl hw.memsize | awk '{print $2/1024/1024/1024 " GB"}'

# CPU cores
sysctl -n hw.ncpu

# Free disk space
df -h ~

##### Minikube configuration for 8 GB:
# Use this instead of the default start command:
minikube start --driver=docker --memory=3072 --cpus=2

# For Days 4-5 (if attempting monitoring):
minikube delete  # Clean slate
minikube start --driver=docker --memory=4096 --cpus=2

# For Day 6 (ArgoCD)
minikube delete  # Clean slate
minikube start --driver=docker --memory=4096 --cpus=2

##### Resource management tips:
# Stop when not learning (frees RAM immediately)
minikube stop

# Start fresh if sluggish
minikube delete && minikube start --memory=3072

# Check Minikube's actual usage
docker stats  # Shows all container resource usage
# Start with Days 1-3 using --memory=3072. You'll learn 80% of the concepts without resource stress.