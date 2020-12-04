# Resilient deployment with readiness and liveness probes

A good explanation is given here:
https://www.openshift.com/blog/liveness-and-readiness-probes (note some typo in formulas: `-1 <=> * ()` )

It is also documented in official documentation:
- https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle
-  https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

Here are some explanations

## Liveness probe
 
### Objective

Indicates whether the container is running. 

### Actions

If the liveness probe fails, the Kubelet kills the container, and the container is subjected to its restart policy (usually restart the container)

### When to use 

> If the process in your container is able to crash on its own whenever it encounters an issue or becomes unhealthy, you do not necessarily need a liveness probe; the kubelet will automatically perform the correct action in accordance with the Pod's restartPolicy.
> If you'd like your container to be killed and restarted if a probe fails, then specify a liveness probe, and specify a restartPolicy of Always or OnFailure

From: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#when-should-you-use-a-liveness-probe

## Behavior

For a start up, the equation for liveness probe to trigger container restart is 

````text
time  = initialDelaySeconds + failureThreshold * (periodSeconds + timeOutSeconds)
````

Under normal steady state operation, and assuming that the pod has operated successfully for a period of time

````shell script
time = failureThreshold * (periodSeconds + timeoutSeconds)
````

From: https://www.openshift.com/blog/liveness-and-readiness-probes 

In [secret deep dive](../Volumes/secret-doc-deep-dive.md#secrets-consumed-as-environment-variable-and-secret-update), we had killed the container and Kubelet restarts it or not based on the restart policy (Always, OnFailure, Never).
Same behavior is happening failing `liveness`

## Readiness probes
 
### Objective

Indicate pod ready to server request. If not it removes pod IP from service endpoint (see `oc get ep`).

### When to use

> If you'd like to start sending traffic to a Pod only when a probe succeeds, specify a readiness probe. In this case, the readiness probe might be the same as the liveness probe, but the existence of the readiness probe in the spec means that the Pod will start without receiving any traffic and only start receiving traffic after the probe starts succeeding. If your container needs to work on loading large data, configuration files, or migrations during startup, specify a readiness probe.
> If you want your container to be able to take itself down for maintenance, you can specify a readiness probe that checks an endpoint specific to readiness that is different from the liveness probe.

From: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#when-should-you-use-a-readiness-probe

### Behavior

The minimum amount of time for which a pod can be returned to health but still not servicing requests is given by:

````shell script
time = successThreshold * periodSeconds
````

From: https://www.openshift.com/blog/liveness-and-readiness-probes 

We deduced:

````shell script
time before removing pod ip from the endpoint = failureThreshold * (periodSeconds + timeoutSeconds)
````

To manage container start up we can add `initialDelaySeconds` but as container start-up status is not ready,
adding `initialDelaySeconds` will avoid readiness to fail for nothing at start-up.

````shell script
time before removing pod ip from the endpoint = initialDelaySeconds + failureThreshold * (periodSeconds + timeoutSeconds)
````

So  `initialDelaySeconds` will actually not really add extra time for container to start, but avoids extra failure.
This failure does not really having impact.
However if `initialDelaySeconds` is too high container will not be appear ready whereas it could be.

<!-- here is the subtlety -->

This is warned here: https://www.openshift.com/blog/liveness-and-readiness-probes
> Setting this value too high will leave a period of time during which the container applications are active and the probe is not. 

Another side effect could be to slow down the deployment as:
> A deployment strategy uses readiness checks to determine if a new pod is ready for use. If a readiness check fails, the deployment configuration will retry to run the pod until it times out.

From https://docs.openshift.com/container-platform/3.11/dev_guide/deployments/deployment_strategies.html#strategies

Same in Kubernetes doc: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#failed-deployment

## Start-up probes [Kubernetes v1.18 [beta]]

### Objective

Special liveness probes for start-up.

### When to use

> Rather than set a long liveness interval, you can configure a separate configuration for probing the container as it starts up, allowing a time longer than the liveness interval would allow.
> If your container usually starts in more than initialDelaySeconds + failureThreshold × periodSeconds, you should specify a startup probe that checks the same endpoint as the liveness probe

### Behavior

> Sometimes, you have to deal with legacy applications that might require an additional startup time on their first initialization. In such cases, it can be tricky to set up liveness probe parameters without compromising the fast response to deadlocks that motivated such a probe. The trick is to set up a startup probe with the same command, HTTP or TCP check, with a failureThreshold * periodSeconds long enough to cover the worse case startup time.

Here

````shell script

startupProbe:
  httpGet:
    path: /healthz
    port: liveness-port
  failureThreshold: 30
  periodSeconds: 1
````

> Thanks to the startup probe, the application will have a maximum of 5 minutes (30 * 10 = 300s) to finish its startup. Once the startup probe has succeeded once, the liveness probe takes over to provide a fast response to container deadlocks. If the startup probe never succeeds, the container is killed after 300s and subject to the pod's restartPolicy.

From: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-startup-probes
<!--
(which confirms our typo : `-1 <=> * ()`  interpreartion in blog)
-->

Startup probe can also have `initialDelaySeconds`.
From: https://medium.com/swlh/fantastic-probes-and-how-to-configure-them-fef7e030bd2f

We can not check yet fields via:

````shell script
kubectl explain pod.spec.containers.startupProbe
````


## Testing a dependency via liveness

Assume you have an API server depending on another API/device. 
We could also make a Pinger checking API/device connectivity.
It could be eventually used in readiness probes but not in the liveness.

From :https://blog.colinbreck.com/kubernetes-liveness-and-readiness-probes-how-to-avoid-shooting-yourself-in-the-foot/  )

Using that for liveness could be a bad idea, as we would go to a restart container loop.




All behavior described here starts when container is started so after the pull.

<!-- sre-setup, TestV2.md -->

<!-- => https://github.com/kubernetes/website/pull/25027, OK reviewed and CCL finally -->

If liveness  and startup probe IMO initial delay seconds makes less sense. OK.