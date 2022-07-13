# ocp-acm-notes
# Commands for install ACM

Create project

'oc create namespace [cloudname]-[clustername]'

# ACM Commands

Retrieve the currently available managed clusters

'oc get managedclusters'


Retrieve the properties of [cluster]

'oc get managedcluster [cluster] -o yaml'

# Hibernate Cluster

Not all OpenShift clusters need to run continuously. For example, development clusters are probably not used during the night. Therefore, it makes sense to hibernate these clusters during off hours to save on cloud hosting costs.

# Start Clusters

Once you are ready to use your hibernated clusters again, you can restart them.

# Get Cluster Information

Every cluster, both imported and deployed from RHACM, has its own dashboard with information about the cluster. The useful information you can retrieve directly from the RHACM cluster properties page includes the cluster resource name, cluster API address, console URL, and the username and password.

You can also see the cluster status, distribution version, channel, and labels.

. On your bastion host, check the status of your managed clusters:

'oc get managedclusters'

. Retrieve the secrets for your managed cluster (you are only interested in the secrets whose names start with the name of your cluster):

'oc get secrets -n [namespace == cluster-name] | grep [cluster-name]'

. Retrieve the install-config.yaml file for your cluster:

'oc get secret [cluster-name]-install-config -n [namespace] -o yaml'

.. Note that the install-config.yaml file is base64 encoded. Retrieve only the content of the install-config.yaml file and decode it:

' oc get secret sno-${GUID}-install-config -n sno-${GUID} -o yaml -o jsonpath='{.data.install-config\.yaml}' | base64 -d '

# Confirm Autoscaler Readiness

'oc login --insecure-skip-tls-verify=true -u kubeadmin -p <password> https://api.[namespace]-[subdomain].[Domain]'

Verify that the cluster autoscaler was created on the managed cluster:

'oc get clusterautoscaler'

The cluster autoscaler works by using MachineAutoscaler resources to scale the MachineSet resources in the openshift-machine-api namespace.
Verify that you have machine autoscalers available:

'oc get machineautoscaler -n openshift-machine-api'

## Test Cluster Autoscaler

. Create a new project to hold your workload:

'oc new-project work-queue'

. Create a job to create 150 Pods in that project. Select 2Gi for the requested memory and 2 whole CPUs for each of the containers in the Pod. This causes the cluster autoscaler to trigger the creation of additional nodes:

```yaml
echo 'apiVersion: batch/v1
kind: Job
metadata:
  generateName: work-queue-
spec:
  template:
    spec:
      containers:
      - name: work
        image: busybox
        command: ["sleep",  "300"]
        resources:
          requests:
            memory: 2Gi
            cpu: 2
      restartPolicy: Never
  parallelism: 50
  completions: 150' | oc create -f - -n work-queue
```

. After a few seconds, verify that the first machine set scaled to make space for new workloads:

'oc get machineset -n openshift-machine-api'

. Verify that the machines were created:

'oc get machines -n openshift-machine-api'

. Verify that the nodes were created:

'oc get nodes'
