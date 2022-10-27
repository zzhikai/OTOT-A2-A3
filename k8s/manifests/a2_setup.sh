echo Setting Up A2 Resources

echo Create Cluster
kind create cluster --name kind-1 --config ./k8s/kind/cluster-config.yaml
sleep 30

echo Cluster Information

echo Inspect Node Containers
docker ps

sleep 30
echo Inspect Nodes
kubectl get nodes

echo Inspect Cluster Information
kind get clusters
kubectl cluster-info
echo 
read -rsn1 -p"Press any key to create backend deployment"
kubectl apply -f ./k8s/manifests/backend-deploy.yaml

echo Waiting for Backend Deployment to be Ready
kubectl wait --for=condition=ready pod -l app=backend --timeout=90s
echo

echo Inspect Deployment Pods
kubectl get po -lapp=backend

echo 
read -rsn1 -p"Press any key to create backend service"
kubectl apply -f ./k8s/manifests/backend-service.yaml

echo Verify Backend Service Details
kubectl describe svc backend-service
echo 

read -rsn1 -p"Press any key to create nginx ingress controller"
echo Create NGINX Ingress Controller
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
echo 
echo Waiting for NGINX Ingress Controller to be Ready
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
echo 
echo Inspect Controller
kubectl -n ingress-nginx get deploy
kubectl -n ingress-nginx describe deploy
echo "\n"
echo Create an Ingress object
kubectl apply -f ./k8s/manifests/backend-ingress-object.yaml
echo "\n"
echo Waiting for Ingress object to be Ready
sleep 60
echo "\n"
echo Inspect Ingress object Details

kubectl describe ingress backend-ingress
echo " "

echo Port Forwarding to show demo
kubectl port-forward svc/backend-service 3000:3000

echo " "
echo Go to localhost:3000 to access application;