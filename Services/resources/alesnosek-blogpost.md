**Below I mirrored this very good blogpost from Ales Nosek, available here
https://alesnosek.com/blog/2017/02/14/accessing-kubernetes-pods-from-outside-of-the-cluster/.
This post is not from me but I am referencing it in this [document](synthesis.md)**


# Accessing Kubernetes Pods from Outside of the Cluster

**Feb 14th, 2017 11:36 pm**

There are several ways how to expose your application running on the Kubernetes cluster to the outside world. 
When reading the Kubernetes documentation I had a hard time ordering the different approaches in my head. 
I created this blog post for my future reference but will be happy if it can be of any use to you.
Without further ado let’s discuss the hostNetwork, hostPort, NodePort, LoadBalancer and Ingress features of Kubernetes.

## hostNetwork: true

The hostNetwork setting applies to the Kubernetes pods.
When a pod is configured with `hostNetwork: true`, the applications running in such a pod can directly
see the network interfaces of the host machine where the pod was started.
An application that is configured to listen on all network interfaces will in turn be accessible
on all network interfaces of the host machine.

Here is an example definition of a pod that uses host networking:

influxdb-hostnetwork.yml

````shell script
apiVersion: v1
kind: Pod
metadata:
  name: influxdb
spec:
  hostNetwork: true
  containers:
    - name: influxdb
      image: influxdb
````


You can start the pod with the following command:

````shell script
$ kubectl create -f influxdb-hostnetwork.yml
````


You can check that the InfluxDB application is running with:

````shell script
$ curl -v http://kubenode01.example.com:8086/ping
````


Remember to replace the host name in the above URL with the host name or IP address of the Kubernetes node where your pod has been scheduled to run. InfluxDB will respond with HTTP 204 No Content when working properly.

Note that every time the pod is restarted Kubernetes can reschedule the pod onto a different node and so the application will change its IP address. Besides that two applications requiring the same port cannot run on the same node. This can lead to port conflicts when the number of applications running on the cluster grows. On top of that, creating a pod with hostNetwork: true on OpenShift is a privileged operation. For these reasons, the host networking is not a good way to make your applications accessible from outside of the cluster.

What is the host networking good for? For cases where a direct access to the host networking is required. For example, the Kubernetes networking plugin Flannel can be deployed as a daemon set on all nodes of the Kubernetes cluster. Due to hostNetwork: true the Flannel has full control of the networking on every node in the cluster allowing it to manage the overlay network to which the pods with hostNetwork: false are connected to.

## hostPort

The hostPort setting applies to the Kubernetes containers.
The container port will be exposed to the external network at `<hostIP>:<hostPort>`,
where the hostIP is the IP address of the Kubernetes node where the container is running and the hostPort
is the port requested by the user. Here comes a sample pod definition:

influxdb-hostport.yml

````shell script
apiVersion: v1
kind: Pod
metadata:
  name: influxdb
spec:
  containers:
    - name: influxdb
      image: influxdb
      ports:
        - containerPort: 8086
          hostPort: 8086
````


The hostPort feature allows to expose a single container port on the host IP. 
Using the hostPort to expose an application to the outside of the Kubernetes cluster has the same drawbacks
as the hostNetwork approach discussed in the previous section. The host IP can change when the container is restarted, two containers using the same hostPort cannot be scheduled on the same node and the usage of the hostPort is considered a privileged operation on OpenShift.

What is the hostPort used for? For example, **the nginx based Ingress controller** is deployed as a set of containers running on top of Kubernetes. These containers are configured to use hostPorts 80 and 443 to allow the inbound traffic on these ports from the outside of the Kubernetes cluster.

## NodePort

The NodePort setting applies to the Kubernetes services. 
By default Kubernetes services are accessible at the ClusterIP which is an internal IP address reachable from inside of the Kubernetes cluster only. The ClusterIP enables the applications running within the pods to access the service. To make the service accessible from outside of the cluster a user can create a service of type NodePort. At first, let’s review the definition of the pod that we’ll expose using a NodePort service:

influxdb-pod.yml

````shell script
apiVersion: v1
kind: Pod
metadata:
  name: influxdb
  labels:
    name: influxdb
spec:
  containers:
    - name: influxdb
      image: influxdb
      ports:
        - containerPort: 8086
````


When creating a NodePort service, the user can specify a port from the range 30000-32767,
and each Kubernetes node will proxy that port to the pods selected by the service.
A sample definition of a NodePort service looks as follows:
influxdb-nodeport.yml

````shell script

kind: Service
apiVersion: v1
metadata:
  name: influxdb
spec:
  type: NodePort
  ports:
    - port: 8086
      nodePort: 30000
  selector:
    name: influxdb
````


Note that on OpenShift more privileges are required to create a NodePort service. 
After the service has been created, the kube-proxy component that runs on each node of the Kubernetes cluster and listens on all network interfaces is instructed to accept connections on port 30000.
The incoming traffic is forwarded by the kube-proxy to the selected pods in a round-robin fashion.
You should be able to access the InfluxDB application from outside of the cluster using the command:

````shell script
$ curl -v http://kubenode01.example.com:30000/ping
````


The NodePort service represents a static endpoint through which the selected pods can be reached.
If you prefer serving your application on a different port than the 30000-32767 range,
you can deploy an external load balancer in front of the Kubernetes nodes and forward the traffic to the NodePort on each of the Kubernetes nodes.
This gives you an extra resiliency for the case that some of the Kubernetes nodes becomes unavailable, too. If you’re hosting your Kubernetes cluster on one of the supported cloud providers like AWS, Azure or GCE, Kubernetes can provision an external load balancer for you. We’ll take a look at how to do it in the next section.

## LoadBalancer

The LoadBalancer setting applies to the Kubernetes service. 
In order to be able to create a service of type LoadBalancer, a cloud provider has to be enabled in the configuration of the Kubernetes cluster.
As of version 1.6, Kubernetes can provision load balancers on AWS, Azure, CloudStack, GCE and OpenStack. Here is an example definition of the LoadBalancer service:
influxdb-loadbalancer.yml

````shell script
kind: Service
apiVersion: v1
metadata:
  name: influxdb
spec:
  type: LoadBalancer
  ports:
    - port: 8086
  selector:
    name: influxdb
````
Let’s take a look at what Kubernetes created for us:

````shell script
$ kubectl get svc influxdb
NAME       CLUSTER-IP     EXTERNAL-IP     PORT(S)          AGE
influxdb   10.97.121.42   10.13.242.236   8086:30051/TCP   39s

````

In the command output we can read that the influxdb service is internally reachable at the ClusterIP 10.97.121.42. Next, Kubernetes allocated a NodePort 30051. Because we didn’t specify a desired NodePort number, Kubernetes picked one for us. We can check the reachability of the InfluxDB application through the NodePort with the command:

````shell script
$ curl -v http://kubenode01.example.com:30051/ping
````

Finally, Kubernetes reached out to the cloud provider to provision a load balancer. 
The VIP of the load balancer is 10.13.242.236 as it is shown in the command output. 
Now we can access the InfluxDB application through the load balancer like this:

````shell script
curl -v http://10.13.242.236:8086/ping
````
My cloud provider is OpenStack. Let’s examine how the provisioned load balancer on OpenStack looks like:

````shell script
$ neutron lb-vip-show 9bf2a580-2ba4-4494-93fd-9b6969c55ac3
+---------------------+--------------------------------------------------------------+
| Field               | Value                                                        |
+---------------------+--------------------------------------------------------------+
| address             | 10.13.242.236                                                |
| admin_state_up      | True                                                         |
| connection_limit    | -1                                                           |
| description         | Kubernetes external service a6ffa4dadf99711e68ea2fa163e0b082 |
| id                  | 9bf2a580-2ba4-4494-93fd-9b6969c55ac3                         |
| name                | a6ffa4dadf99711e68ea2fa163e0b082                             |
| pool_id             | 392917a6-ed61-4924-acb2-026cd4181755                         |
| port_id             | e450b80b-6da1-4b31-a008-280abdc6400b                         |
| protocol            | TCP                                                          |
| protocol_port       | 8086                                                         |
| session_persistence |                                                              |
| status              | ACTIVE                                                       |
| status_description  |                                                              |
| subnet_id           | 73f8eb91-90cf-42f4-85d0-dcff44077313                         |
| tenant_id           | 4d68886fea6e45b0bc2e05cd302cccb9                             |
+---------------------+--------------------------------------------------------------+

$ neutron lb-pool-show 392917a6-ed61-4924-acb2-026cd4181755
+------------------------+--------------------------------------+
| Field                  | Value                                |
+------------------------+--------------------------------------+
| admin_state_up         | True                                 |
| description            |                                      |
| health_monitors        |                                      |
| health_monitors_status |                                      |
| id                     | 392917a6-ed61-4924-acb2-026cd4181755 |
| lb_method              | ROUND_ROBIN                          |
| members                | d0825cc2-46a3-43bd-af82-e9d8f1f85299 |
|                        | 3f73d3bb-bc40-478d-8d0e-df05cdfb9734 |
| name                   | a6ffa4dadf99711e68ea2fa163e0b082     |
| protocol               | TCP                                  |
| provider               | haproxy                              |
| status                 | ACTIVE                               |
| status_description     |                                      |
| subnet_id              | 73f8eb91-90cf-42f4-85d0-dcff44077313 |
| tenant_id              | 4d68886fea6e45b0bc2e05cd302cccb9     |
| vip_id                 | 9bf2a580-2ba4-4494-93fd-9b6969c55ac3 |
+------------------------+--------------------------------------+

$ neutron lb-member-list
+--------------------------------------+--------------+---------------+--------+----------------+--------+
| id                                   | address      | protocol_port | weight | admin_state_up | status |
+--------------------------------------+--------------+---------------+--------+----------------+--------+
| 3f73d3bb-bc40-478d-8d0e-df05cdfb9734 | 10.13.241.89 |         30051 |      1 | True           | ACTIVE |
| d0825cc2-46a3-43bd-af82-e9d8f1f85299 | 10.13.241.10 |         30051 |      1 | True           | ACTIVE |
+--------------------------------------+--------------+---------------+--------+----------------+--------+

````


Kubernetes created a TCP load balancer with the VIP `10.13.242.236` and port `8086`.
There are two pool members associated with the load balancer: 
`10.13.241.89` and `10.13.241.10`.
These are the IP addresses of the nodes in my two-node Kubernetes cluster.
The traffic is forwarded to the NodePort 30051 of these two nodes.

The load balancer created by Kubernetes is a plain TCP round-robin load balancer.
It doesn’t offer SSL termination or HTTP routing.
Besides that, Kubernetes will create a separate load balancer for each service.
This can become quite costly when the number of your services increases.
Instead of letting Kubernetes manage the load balancer, you can go back to deploying NodePort services and provision and configure an external load balancer yourself. Another option is leveraging the Kubernetes Ingress resource that we will discuss in the next section.

## Ingress

The Ingress resource type was introduced in Kubernetes version 1.1.
The Kubernetes cluster must have an Ingress controller deployed in order for you to be able to create Ingress resources.

What is the Ingress controller?
The Ingress controller is deployed as a Docker container on top of Kubernetes.
Its Docker image contains a load balancer like nginx or HAProxy and a controller daemon. 
The controller daemon receives the desired Ingress configuration from Kubernetes.
It generates an nginx or HAProxy configuration file and restarts the load balancer process for changes to take effect.
In other words, Ingress controller is a load balancer managed by Kubernetes.

The Kubernetes Ingress provides features typical for a load balancer:
HTTP routing, sticky sessions, SSL termination, SSL passthrough, TCP and UDP load balancing … 
At the moment not every Ingress controller implements all the available features.
You have to consult the documentation of your Ingress controller to learn about its capabilities.

Let’s expose our InfluxDB application to the outside world via Ingress. An example Ingress definition looks like this:

influxdb-ingress.yml

````shell script
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: influxdb
spec:
  rules:
    - host: influxdb.kube.example.com
      http:
        paths:
          - backend:
              serviceName: influxdb
              servicePort: 8086

````

Our DNS is setup to resolve `*.kube.example.com` to the IP address `10.13.241.10`.
This is the IP address of the Kubernetes node where the Ingress controller is running.
As we already mentioned when discussing the hostPort,
the Ingress listens for the incoming connections on two hostPorts 80 and 443 for the HTTP and HTTPS requests, respectively.
Let’s check that we can reach the InfluxDB application via Ingress:

````shell script
$ curl -v http://influxdb.kube.example.com/ping
````


When everything is setup correctly, the InfluxDB will respond with HTTP 204 No Content.

There’s a difference between the LoadBalancer service and the Ingress in how the traffic routing is realized. 
- In the case of the LoadBalancer service, the traffic that enters through the external load balancer is forwarded to the kube-proxy that in turn forwards the traffic to the selected pods.
- In contrast, the Ingress load balancer forwards the traffic straight to the selected pods which is more efficient.

## Conclusion

Overall, when exposing pods to the outside of the Kubernetes cluster, the Ingress seems to be a very flexible and convenient solution. Unfortunately, it’s also the less mature among the discussed approaches. When choosing the NodePort service, you might want to deploy a load balancer in front of your cluster as well. If you are hosting Kubernetes on one of the supported clouds, the LoadBalancer service is another option for you.

How do you route the external traffic to the Kubernetes pods? Glad to hear about your experience in the Comments section below!


Posted by Ales Nosek Feb 14th, 2017 11:36 pm cloud, devops 