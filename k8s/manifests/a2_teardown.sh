echo Delete all A2 resources

# Delete all A2 resources
echo Delete Ingress
kubectl delete ingress backend-ingress

echo Delete Ingress Controller
kubectl delete -n ingress-nginx deploy

echo Delete Backend Service
kubectl delete svc backend-service

echo Delete Backend Deployment
kubectl delete deploy backend

echo Delete Cluster
kind delete cluster --name kind-1

echo Finish Deleting All A2 Resources