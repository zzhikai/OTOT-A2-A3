# OTOT Task 3

From Task 2, you should have the NodeJS server you built earlier on running in a k8s cluster that is accessible from your local environment.

We will now explore how to exploit k8s to make the service elastic under load.

## Task A3.1: scale Deployment HorizontalPodAutoscaler

k8s is built to orchestrate tens of thousands of containers running in a cluster of compute resources.
In Task 2, we have explored the use of Deployment to maintain some numbers of Pods to run in the cluster.
However, when the containers are under load, we want the cluster to also scale up the number of Pods running.

`HorizontalPodAutoscaler` is a type of resource that specifies the autoscaling requirement for a controller.
In our case, the controller is the backend Deployment that initially controls 3 Pods.

When we use the manifest, we specify that we are going to scale the number of Pods controlled by the Deployment called backend based on its CPU usage.

### Step 1: Metrics Server

For HPA to work, it needs to read the metrics from somewhere.
This demands a centralised aggregator for the Pod metrics.
The most standard way of doing this is using metrics-server.

As it has quite some manifests, you can directly install the resources from the [link](https://github.com/kubernetes-sigs/metrics-server)
where you can find this command to install all resources.  
`kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`

**IMPORTANT**
Do note that the TLS will not be working and you have to manually edit the Deployment manifest to add a flag
`--kubelet-insecure-tls` to `deployment.spec.containers[].args[]` using the command
`kubectl -nkube-system edit deploy/metrics-server` (metrics-server will be installed in `kube-system` namespace).
And you will have to restart the Deployment using `kubectl -nkube-system rollout restart deploy/metrics-server`.

### Step 2:
Apply the following:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend
  namespace: default
spec:
  metrics:
    - resource:
        name: cpu
        target:
          averageUtilization: 50
          type: Utilization
      type: Resource
  minReplicas: 1
  maxReplicas: 10
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
```

The important fields are:
* `spec.metrics[].resource`: specifies the resource name (we use "cpu"), the type and target value it should be for scaling.
* `spec.metrics[].resource`: just add "Resource"
* `spec.minReplicas`: minimum replicas the target Deployment will scale down to if the target is not met and it is possible to scale down. (That means, the scaled down Deployment must not exceed the scaling target!)
* `spec.maxReplicas`: maximum replicas to scale up to. We can't just scale indefinitely.
* `spec.scaleTargetRef`: specify some important fields about the target object using `kind` and `name` (`apiVersion` should follow the `kind` used in the cluster)

After you apply this, you should try to load test the backend.

With the extremely low resource allocation, you can simply open and refresh the page "http:localhost/app" repeatedly to
stress the servers. See it scale.

On the contrary, if the servers are idling, you should see the scale down:
```
$ kubectl get po
NAME                      READY   STATUS    RESTARTS   AGE
backend-745dd6fc9-7qjmt   1/1     Running   0          20m

$ kubectl describe hpa
Warning: autoscaling/v2beta2 HorizontalPodAutoscaler is deprecated in v1.23+, unavailable in v1.26+; use autoscaling/v2 HorizontalPodAutoscaler
Name:                                                  backend
Namespace:                                             default
Labels:                                                <none>
Annotations:                                           <none>
CreationTimestamp:                                     Wed, 17 Aug 2022 19:37:44 +0800
Reference:                                             Deployment/backend
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  0% (0) / 50%
Min replicas:                                          1
Max replicas:                                          10
Deployment pods:                                       1 current / 1 desired
Conditions:
  Type            Status  Reason            Message
  ----            ------  ------            -------
  AbleToScale     True    ReadyForNewScale  recommended size matches current size
  ScalingActive   True    ValidMetricFound  the HPA was able to successfully calculate a replica count from cpu resource utilization (percentage of request)
  ScalingLimited  True    TooFewReplicas    the desired replica count is less than the minimum replica count
Events:
  Type     Reason                        Age                From                       Message
  ----     ------                        ----               ----                       -------
  Warning  FailedGetResourceMetric       20m (x2 over 20m)  horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedComputeMetricsReplicas  20m (x2 over 20m)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
  Warning  FailedGetResourceMetric       20m                horizontal-pod-autoscaler  failed to get cpu utilization: did not receive metrics for any ready pods
  Warning  FailedComputeMetricsReplicas  20m                horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu utilization: did not receive metrics for any ready pods
  Normal   SuccessfulRescale             15m                horizontal-pod-autoscaler  New size: 1; reason: All metrics below target
```

Observe the last Event at the bottom.

## High Availability

One advantage of adopting microservices architecture is high availability.
When 3 Pods are deployed on 3 different nodes (machines), 
failure of 1 node will only cripple the performance of the service shortly before k8s brings up another such Pod else where.

In k8s, usually the Pods from the same Deployment will be spread out.
However, this mechanism is not guaranteed.

In this part of the task, you will learn to set the spread explicitly.

By default, k8s scheduler (kube-scheduler) will try to schedule all Pods evenly across the cluster.
That's why when you have 3 worker nodes and 10 Pods (try it), you will see a 3-3-4 spread.

However, imagine the following scenario:  
There is an uneven spread of nodes across two different data centres. 
We want the Pods to go to both sides in an even manner such that if one data centre fails, 
we will only lose half the Pods for this service.

This can be achieved using `pod.spec.topologySpreadConstraints` which checks the number of Pods against
the node label "topology.kubernetes.io/zone" and make sure for sets of nodes of different values (e.g. a, b), 
the maxSkew, i.e. maximum difference, will be 1.

View the nodes with the command:

```
$ kubectl get nodes -L topology.kubernetes.io/zone
NAME                      STATUS   ROLES                  AGE   VERSION   ZONE
cluster-1-control-plane   Ready    control-plane,master   63s   v1.23.4   
cluster-1-worker          Ready    <none>                 30s   v1.23.4   a
cluster-1-worker2         Ready    <none>                 31s   v1.23.4   a
cluster-1-worker3         Ready    <none>                 31s   v1.23.4   b
```

As you can see, each worker node is labeled with key "topology.kubernetes.io/zone" and a letter zone "a" or "b".

### Step 1: add topologySpread Constraints

In order to leave the auto-scaled Deployment alone, we create another Deployment "backend-zone-aware" with 10 replicas:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-zone-aware
  labels:
    app: backend-zone-aware
spec:
  replicas: 10
  selector:
    matchLabels:
      app: backend-zone-aware
  template:
    metadata:
      labels:
        app: backend-zone-aware
    spec:
      containers:
        - name: backend
          image: nginx:latest
          ports:
            - name: http
              containerPort: 8080
          resources:
            limits:
              cpu: 40m
              memory: 100Mi
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: backend-zone-aware
```

It is mostly the same as A2.2. The only additional part is `spec.template.spec.topologySpreadConstraints`.
Here is the explanation of the fields:
* `maxSkew`: between all scheduling partition, the numbers of Pods scheduled differ by at most 1 Pod
* `topologyKey`: the key of the Node label for this constraint to take effect. "topology.kubernetes.io/zone" is typically used to indicate availability zone of a Node.
* `whenUnsatisfiable`: namely the behaviour when no Node can satisfy the constraint
* `labelSelect`: same as before, the way to select the group of Pods to apply this constraint to. Should match `spec.template.metadata.labels`.

Run the command:

```
$ kubectl get po -lapp=backend-zone-aware -owide --sort-by='.spec.nodeName'
NAME                                 READY   STATUS    RESTARTS       AGE     IP            NODE                NOMINATED NODE   READINESS GATES
backend-zone-aware-f9b99b55f-fx99l   1/1     Running   1 (110s ago)   4m54s   10.244.3.6    cluster-1-worker    <none>           <none>
backend-zone-aware-f9b99b55f-5c4j7   1/1     Running   1 (110s ago)   4m54s   10.244.1.7    cluster-1-worker2   <none>           <none>
backend-zone-aware-f9b99b55f-h598q   1/1     Running   0              4m54s   10.244.1.5    cluster-1-worker2   <none>           <none>
backend-zone-aware-f9b99b55f-qkz7p   1/1     Running   0              4m54s   10.244.1.4    cluster-1-worker2   <none>           <none>
backend-zone-aware-f9b99b55f-gc56d   1/1     Running   0              4m54s   10.244.1.2    cluster-1-worker2   <none>           <none>
backend-zone-aware-f9b99b55f-9t5lk   1/1     Running   1              4m54s   10.244.2.4    cluster-1-worker3   <none>           <none>
backend-zone-aware-f9b99b55f-bsqws   1/1     Running   0              4m54s   10.244.2.2    cluster-1-worker3   <none>           <none>
backend-zone-aware-f9b99b55f-25fzl   1/1     Running   0              4m54s   10.244.2.6    cluster-1-worker3   <none>           <none>
backend-zone-aware-f9b99b55f-7b2gb   1/1     Running   0              4m54s   10.244.2.7    cluster-1-worker3   <none>           <none>
backend-zone-aware-f9b99b55f-8blkk   1/1     Running   0              4m54s   10.244.2.10   cluster-1-worker3   <none>           <none>
```

You can see that there are 1 Pod on worker, 4 Pods on worker2, and 5 Pods on worker3.  
Recall that worker and worker2 are zone "a", and worker3 alone is in zone "b".
We have distributed the Pods evenly across the two zones!

Furthermore, do note that zone "a" Pods are uneven across worker and worker2.
This is because of the existing Pods on those nodes that result in overall Pod number balance but imbalance between Pods belonging to an individual Deployment.

You can add a constraint to make sure the Pods are spread across all node evenly instead.
