# CS3219 OTOT Task A2 and A3
CS3219 OTOT Task A2 is split into 3 parts. A3 is split into 2 parts.

First, clone the repository

```
git clone git@github.com:CS3219-AY2223S1/OTOT-A2-A3.git cs3219_otot_taska2_3
cd cs3219_otot_taska2_3
```

## A2 - Introduction to Kubernetes

This assignment has three parts:
* A2.1 Deploy a local k8s cluster
* A2.2 Deploy your A1 Docker image as Deployment in A2.1 cluster
* A2.3 Deploy Ingress to expose A2.2 Deployment to your localhost

Follow the guide in demo/a2/ to complete the tasks.
Place your manifests in k8s/manifests/ and commands used in k8s/a2_setup.sh.

## A3 - Scalability and Availability

This assignment has two parts:
* A3.1 Deploy HorizontalPodAutoscaler that makes A2.2 Deployments scale up under load.
* A3.2 Modify your A2.2 Deployment to be distributed equally in each zone


Follow the guide in demo/a3/ to complete the tasks.
Place your manifests in k8s/manifests/ and commands used in k8s/a3_setup.sh.
