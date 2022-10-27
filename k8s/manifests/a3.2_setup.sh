echo Setting Up A3.2 Resources

echo Add topologySpread Contraints
echo " "

echo View nodes with zone
kubectl get nodes -L topology.kubernetes.io/zone

echo " "

echo Deploy Backend Deploy Zone Aware
kubectl apply -f ./k8s/manifests/backend-deploy-zone-aware.yaml
sleep 60

echo Check Backend Deploy Zone Aware Running
kubectl get po -lapp=backend-zone-aware

echo " "

echo Inspect distribution of pods
kubectl get po -lapp=backend-zone-aware -owide --sort-by='.spec.nodeName'
