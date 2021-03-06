# Service Catalog Demonstration Walkthrough (DEPRECATED)

This document outlines the basic features of the service catalog by walking
through a short demo.

This document contains instructions for a self-guided demo of the Service 
Catalog for Kubernetes clusters running version 1.6. Since Service
Catalog only officially supports versions 1.7 and later, these instructions are 
deprecated and may be removed at any time.

If you are running a Kubernetes cluster running version 1.7 or later, please 
see [walkthrough-1.7.md](./walkthrough-1.7.md).

__Note: This document assumes that you've installed Service Catalog onto your cluster.
If you haven't, please see the 
[installation instructions for 1.6](./install-1.6.md).__

# Step 1 - Installing the UPS Service Broker Server

In order to effectively demonstrate the service catalog, we will require a
sample broker server. To proceed, we will deploy the [User Provided Service
broker (hereafter, "UPS")](https://github.com/kubernetes-incubator/service-catalog/tree/master/contrib/pkg/broker/user_provided/controller)
to our own Kubernetes cluster. Similar to the service catalog system itself,
this is easily installed using a provided Helm chart. The chart supports a
wide variety of customizations which are detailed in that directory's
[README.md](https://github.com/kubernetes-incubator/service-catalog/blob/master/charts/ups-broker/README.md).

**Note:** The UPS broker emulates user-provided services as they exist in
Cloud Foundry. Essentially, values provided during provisioning are merely
echoed during binding. (i.e. The values *are* the service.) This is a trivial
broker server but it's deliberately employed in this walkthrough to avoid
getting hung up on the distracting details of some other technology.

To install with defaults:

```console
helm install charts/ups-broker --name ups-broker --namespace ups-broker
```

# Step 2 - Creating a `ServiceBroker` Resource

Next, we'll register a broker server with the catalog by creating a new
[`ServiceBroker`](../contrib/examples/walkthrough/ups-broker.yaml) resource.

Because we haven't created any resources in the service-catalog API server yet,
`kubectl get` will return an empty list of resources.

```console
kubectl --context=service-catalog get servicebrokers,serviceclasses,serviceinstances,serviceinstancecredentials
No resources found.
```

Create the new `ServiceBroker` resource with the following command:

```console
kubectl --context=service-catalog create -f contrib/examples/walkthrough/ups-broker.yaml
```

The output of that command should be the following:

```console
servicebroker "ups-broker" created
```

When we create this `ServiceBroker` resource, the service catalog controller responds
by querying the broker server to see what services it offers and creates a
`ServiceClass` for each.

We can check the status of the broker using `kubectl get`:

```console
kubectl --context=service-catalog get servicebrokers ups-broker -o yaml
```

We should see something like:

```yaml
apiVersion: servicecatalog.k8s.io/v1alpha1
kind: ServiceBroker
metadata:
  creationTimestamp: 2017-03-03T04:11:17Z
  finalizers:
  - kubernetes-incubator/service-catalog
  name: ups-broker
  resourceVersion: "6"
  selfLink: /apis/servicecatalog.k8s.io/v1alpha1/servicebrokers/ups-broker
  uid: 72fa629b-ffc7-11e6-b111-0242ac110005
spec:
  url: http://ups-broker-ups-broker.ups-broker.svc.cluster.local
status:
  conditions:
  - message: Successfully fetched catalog entries from broker.
    reason: FetchedCatalog
    status: "True"
    type: Ready
```

Notice that the `status` field has been set to reflect that the broker server's
catalog of service offerings has been successfully added to our cluster's
service catalog.

# Step 3 - Viewing `ServiceClass`es

The controller created a `ServiceClass` for each service that the UPS broker
provides. We can view the `ServiceClass` resources available in the cluster by
executing:

```console
kubectl --context=service-catalog get serviceclasses
```

We should see something like:

```console
NAME                    KIND
user-provided-service   ServiceClass.v1alpha1.servicecatalog.k8s.io
```

As we can see, the UPS broker provides a type of service called
`user-provided-service`. Run the following command to see the details of this
offering:

```console
kubectl --context=service-catalog get serviceclasses user-provided-service -o yaml
```

We should see something like:

```yaml
apiVersion: servicecatalog.k8s.io/v1alpha1
kind: ServiceClass
metadata:
  creationTimestamp: 2017-03-03T04:11:17Z
  name: user-provided-service
  resourceVersion: "7"
  selfLink: /apis/servicecatalog.k8s.io/v1alpha1/serviceclasses/user-provided-service
  uid: 72fef5ce-ffc7-11e6-b111-0242ac110005
brokerName: ups-broker
externalID: 4F6E6CF6-FFDD-425F-A2C7-3C9258AD2468
bindable: false
planUpdatable: false
plans:
- name: default
  free: true
  externalID: 86064792-7ea2-467b-af93-ac9694d96d52
```

# Step 4 - Creating a New `ServiceInstance`

Now that a `ServiceClass` named `user-provided-service` exists within our
cluster's service catalog, we can provision an instance of that. We do so by
creating a new [`ServiceInstance`](../contrib/examples/walkthrough/ups-instance.yaml)
resource.

Unlike `ServiceBroker` and `ServiceClass` resources, `ServiceInstance` resources must reside
within a Kubernetes namespace. To proceed, we'll first ensure that the namespace
`test-ns` exists:

```console
kubectl create namespace test-ns
```

We can then continue to create an `ServiceInstance`:

```console
kubectl --context=service-catalog create -f contrib/examples/walkthrough/ups-instance.yaml
```

That operation should output:

```console
serviceinstance "ups-instance" created
```

After the `ServiceInstance` is created, the service catalog controller will communicate
with the appropriate broker server to initiate provisioning. We can check the
status of this process like so:

```console
kubectl --context=service-catalog get serviceinstances -n test-ns ups-instance -o yaml
```

We should see something like:

```yaml
apiVersion: servicecatalog.k8s.io/v1alpha1
kind: ServiceInstance
metadata:
  creationTimestamp: 2017-03-03T04:26:08Z
  finalizers:
  - kubernetes-incubator/service-catalog
  name: ups-instance
  namespace: test-ns
  resourceVersion: "9"
  selfLink: /apis/servicecatalog.k8s.io/v1alpha1/namespaces/test-ns/serviceinstances/ups-instance
  uid: 8654e626-ffc9-11e6-b111-0242ac110005
spec:
  externalID: 34c984e1-4626-4574-8a95-9e500d0d48d3
  parameters:
    credentials:
      name: root
      password: letmein
  planName: default
  serviceClassName: user-provided-service
status:
  conditions:
  - lastTransitionTime: 2017-03-03T04:26:09Z
    message: The instance was provisioned successfully
    reason: ProvisionedSuccessfully
    status: "True"
    type: Ready
```

# Step 5 - Requesting a `ServiceInstanceCredential` to use the `ServiceInstance`

Now that our `ServiceInstance` has been created, we can bind to it. To accomplish this,
we will create a [`ServiceInstanceCredential`](../contrib/examples/walkthrough/ups-instance-credential.yaml)
resource.

```console
kubectl --context=service-catalog create -f contrib/examples/walkthrough/ups-instance-credential.yaml
```


That command should output:

```console
serviceinstancecredential "ups-instance-credential" created
```

After the `ServiceInstanceCredential` resource is created, the service catalog controller will
communicate with the appropriate broker server to initiate binding. Generally,
this will cause the broker server to create and issue credentials that the
service catalog controller will insert into a Kubernetes `Secret`. We can check
the status of this process like so:

```console
kubectl --context=service-catalog get serviceinstancecredentials -n test-ns ups-instance-credential -o yaml
```

_NOTE: if using the API aggregator, you will need to use the fully qualified name of the binding resource due to [issue 1008](https://github.com/kubernetes-incubator/service-catalog/issues/1008):_

```console
kubectl get bindings.v1alpha1.servicecatalog.k8s.io -n test-ns ups-instance-credential -o yaml
```

We should see something like:

```yaml
apiVersion: servicecatalog.k8s.io/v1alpha1
kind: ServiceInstanceCredential
metadata:
  creationTimestamp: 2017-03-07T01:44:36Z
  finalizers:
  - kubernetes-incubator/service-catalog
  name: ups-instance-credential
  namespace: test-ns
  resourceVersion: "29"
  selfLink: /apis/servicecatalog.k8s.io/v1alpha1/namespaces/test-ns/serviceinstancecredentials/ups-instance-credential
  uid: 9eb2cdce-02d7-11e7-8edb-0242ac110005
spec:
  instanceRef:
    name: ups-instance
  externalID: b041db94-a5a0-41a2-87ae-1025ba760918
  secretName: ups-instance-credential
status:
  conditions:
  - lastTransitionTime: 2017-03-03T01:44:37Z
    message: Injected bind result
    reason: InjectedBindResult
    status: "True"
    type: Ready
```

Notice that the status has a `Ready` condition set.  This means our binding is
ready to use!  If we look at the `Secret`s in our `test-ns` namespace, we should
see a new one:

```console
kubectl get secrets -n test-ns
NAME                              TYPE                                  DATA      AGE
default-token-3k61z               kubernetes.io/service-account-token   3         29m
ups-instance-credential           Opaque                                2         1m
```

Notice that a new `Secret` named `ups-instance-credential` has been created.

# Step 6 - Deleting the `ServiceInstanceCredential`

Now, let's unbind from the provisioned instance. To do this, we simply *delete* the
`ServiceInstanceCredential` resource that we previously created:

```console
kubectl --context=service-catalog delete -n test-ns serviceinstancecredentials ups-instance-credential
```

Checking the `Secret`s in the `test-ns` namespace, we should see that
`ups-instance-credential` has also been deleted:

```console
kubectl get secrets -n test-ns
NAME                  TYPE                                  DATA      AGE
default-token-3k61z   kubernetes.io/service-account-token   3         30m
```

# Step 7 - Deleting the `ServiceInstance`

Now, we can deprovision the instance. To do this, we simply *delete* the
`ServiceInstance` resource that we previously created:

```console
kubectl --context=service-catalog delete -n test-ns serviceinstances ups-instance
```

# Step 8 - Deleting the `ServiceBroker`

Next, we should remove the broker server, and the services it offers, from the catalog. We can do
so by simply deleting the broker:

```console
kubectl --context=service-catalog delete servicebrokers ups-broker
```

We should then see that all the `ServiceClass` resources that came from that
broker have also been deleted:

```console
kubectl --context=service-catalog get serviceclasses
No resources found.
```

# Step 9 - Final Cleanup

## Cleaning up the UPS Service Broker Server

To clean up, delete the helm deployment:

```console
helm delete --purge ups-broker
```

Then, delete all the namespaces we created:

```console
kubectl delete ns test-ns ups-broker
```
## Cleaning up the Service Catalog

Delete the helm deployment and the namespace:

```console
helm delete --purge catalog
kubectl delete ns catalog
```

# Troubleshooting

## Firewall rules

If you are using Google Cloud Platform, you may need to run the following
commands to setup proper firewall rules to allow your traffic get in.

```console
gcloud compute firewall-rules create allow-service-catalog-secure --allow tcp:30443 --description "Allow incoming traffic on 30443 port."
```
