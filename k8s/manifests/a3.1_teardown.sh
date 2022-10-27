
echo Removing all A3.1 Resources

echo Delete hpa
kubectl delete hpa backend 

echo Delete Metrics Server
kubectl delete -n metrics-server deploy

echo Script Finished Running!