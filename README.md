# ACM + Assisted Installer: YAML Pack (GitOps-friendly)

This pack provides **declarative YAML** to provision an OpenShift cluster with **Red Hat Advanced Cluster Management (ACM)** using the **Assisted Installer** (via Hive/MCE CRDs). It includes:
- `AgentClusterInstall`, `ClusterDeployment`, `InfraEnv`, `NMStateConfig`, and (optional) `ClusterImageSet`
- Post-install **ManagedCluster** and **KlusterletAddonConfig** for enabling ACM add-ons
- A `variables.yaml` to keep parameters in one place and a `render.sh` to generate ready-to-apply manifests

> Tested with OCP **4.18** and ACM/MCE **2.11+**. Adjust the `releaseImage` or `clusterImageSetName` as needed.

## Prerequisites

1. A running **hub** cluster with **ACM/MCE** installed.
2. **Hive** and **Assisted Service** are provided by MCE on the hub.
3. DNS records and VIPs for the target cluster:
   - `api.<clusterName>.<baseDomain>` → **apiVIP**
   - `*.apps.<clusterName>.<baseDomain>` → **ingressVIP**
4. Workstation with `oc`, `yq` and `jq`, and `envsubst`.
5. Pull secret from Red Hat Hybrid Cloud Console.
6. Static IPs: MAC addresses and addresses for each host, or use DHCP if preferred.

## Files

```
templates/
  00-namespace.yaml
  01-clusterimageset.yaml
  03-agentclusterinstall.yaml
  04-clusterdeployment.yaml
  05-infraenv.yaml
  06-nmstateconfigs.yaml   # rendered per host
  07-managedcluster.yaml
  08-klusterletaddonconfig.yaml
variables.example.yaml
variables.yaml            # you create this from the example
render.sh                 # renders into rendered/
```

## Quick start

```bash
# 1) Download this repo (or unzip the artifact)
# 2) Create and edit your variables
cp variables.example.yaml variables.yaml
$EDITOR variables.yaml

# 3) Render templates from variables (requires yq, jq, envsubst)
./render.sh

# 4) Apply in order
oc apply -f rendered/00-namespace.yaml
oc apply -f rendered/01-clusterimageset.yaml   # skip if the image set already exists
oc apply -f rendered/04-clusterdeployment.yaml
oc apply -f rendered/03-agentclusterinstall.yaml
oc apply -f rendered/05-infraenv.yaml
oc apply -f rendered/06-nmstateconfigs.yaml
# Download the discovery ISO URL from the InfraEnv status, boot hosts, and wait for agents to appear.
# Then the install will proceed when requirements are met.

# 5) (Optional) Enable ACM add-ons after cluster registers
oc apply -f rendered/07-managedcluster.yaml
oc apply -f rendered/08-klusterletaddonconfig.yaml
```

### Get the Discovery ISO

After applying `InfraEnv`, retrieve the ISO URL:

```bash
oc get infraenv ${clusterName} -n ${namespace} -o jsonpath='{.status.isoDownloadURL}{"\n"}'
```

Boot each host from that ISO. When agents show up in the AgentClusterInstall status, installation will begin once minimum agent counts are satisfied.

## Notes and tips

- **ImageSet vs Release image**: This pack uses `ClusterImageSet` by name. Alternatively set `RELEASE_IMAGE` env var before `./render.sh` to override.
- **Proxy**: Fill the `proxy` section in `variables.yaml`; it is templated into `InfraEnv`.
- **User-managed networking**: The default is false (VIPs via L2). For VLAN or other topologies see official docs.
- **Static IPs**: We use `NMStateConfig` with MAC-based matching. DHCP is also supported; remove NMState if using DHCP.
- **Auto import to ACM**: When using MCE/ACM Assisted Installer, clusters are auto-imported once Ready. The provided `ManagedCluster`/`KlusterletAddonConfig` are helpful if you want to toggle add-ons declaratively.

## Clean-up

```bash
oc delete clusterdeployment ${clusterName} -n ${namespace} --wait=false
oc delete namespace ${namespace}
```

## References (APA)

- Red Hat. (2024). *Red Hat Advanced Cluster Management for Kubernetes 2.11 — Install and manage clusters.* Retrieved from https://docs.redhat.com/ …  

- Red Hat. (2024). *Installing a cluster with customizations using the Agent-based Installer (OCP 4.17/4.18).* Retrieved from https://docs.redhat.com/ …  

- Red Hat. (2024). *Managed cluster klusterlet advanced configuration.* Retrieved from https://docs.redhat.com/ …  

- Open Cluster Management. (2022). *ManagedCluster concept.* Retrieved from https://open-cluster-management.io/docs/concepts/managedcluster/ 

- OpenShift Hive. (n.d.). *Using Hive and ClusterDeployment.* Retrieved from https://github.com/openshift/hive/blob/master/docs/using-hive.md

> See the main chat response for direct links.
