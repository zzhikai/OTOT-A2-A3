echo Setting Up A3.1 Resources

echo Start Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -nkube-system edit deploy/metrics-server

kubectl -nkube-system rollout restart deploy/metrics-server
kubectl wait --namespace metrics-server -nkube-system --for=condition=ready pod --selector=k8s-app=metrics-server --timeout=180s


echo Starting horizontal pod autoscaler...
kubectl apply -f ./k8s/manifests/backend-hpa.yaml

echo Initial Stress Testing
sleep 60
kubectl describe hpa