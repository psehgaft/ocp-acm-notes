
# Upgrade Guide: Red Hat Advanced Cluster Management (RHACM) from 2.[version--] to 2.[version]

## Prerequisites

1. **Compatible OpenShift Version**:
   - Ensure your OpenShift cluster meets the minimum version required for RHACM 2.[version] (typically OCP 4.10+).
   - [RHACM Version Compatibility](https://access.redhat.com/articles/6095721)
   - [Red Hat Advanced Cluster Management for Kubernetes 2.11 Support Matrix](https://access.redhat.com/articles/7073065)
   - [The multicluster engine for Kubernetes operator 2.6 Support Matrix](https://access.redhat.com/articles/7073030)
   - [Red Hat Advanced Cluster Management for Kubernetes](https://www.redhat.com/en/resources/advanced-cluster-management-kubernetes-datasheet)

2. **Backup Key Resources**:
   ```bash
   oc get managedclusters -o yaml > managedclusters-backup.yaml
   oc get policies --all-namespaces -o yaml > policies-backup.yaml
   ```

3. **Access to Red Hat OperatorHub**:
   - Verify that the cluster can reach the Red Hat operator catalog.
---

## Upgrade Steps

### 1. **Upgrade the ACM Operator**

#### Option A: Using the Web Console (GUI)
1. Go to **Operators > Installed Operators**.
2. Select **Advanced Cluster Management for Kubernetes**.
3. Switch the update channel to `release-[version]`.
4. Set the update strategy to `Automatic` or `Manual` as desired.

#### Option B: Using the Command Line (CLI)
```bash
oc edit subscription advanced-cluster-management -n open-cluster-management
```

Modify the `channel` field:
```yaml
channel: release-2.[version]
```

Check the status:
```bash
oc get csv -n open-cluster-management
```

---

### 2. **Verify Component Health**
Ensure all pods are in the `Running` state:
```bash
oc get pods -n open-cluster-management
```

Check the MultiClusterHub (MCH) status:
```bash
oc get mch -n open-cluster-management
```

---

### 3. **Validate Functionality**
- Confirm all `ManagedClusters` are in `Available` state.
- Review policies, observability, search, and other modules via ACM console (`/multicloud`).

---

## (Optional) Upgrade Managed Clusters
If using `klusterlet` components deployed by ACM, verify compatibility with [version] and upgrade if needed.

---

## Best Practices

- Test in a staging environment before production.
- [RHACM 2.13 Release Notes](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.[version]/html/release_notes/index).
- Check for changes in permissions, CRDs, and configurations post-upgrade.

Test permissions and post-uprade
```bash
# Check for Permission (RBAC) Changes

## List Roles and RoleBindings created by ACM
oc get roles,rolebindings,clusterroles,clusterrolebindings -A | grep open-cluster-management

## Compare RBAC settings (if you have a backup)
diff roles-backup.yaml roles-current.yaml

## View permissions of a specific ClusterRole
oc describe clusterrole <clusterrole-name>

# Check for Custom Resource Definitions (CRDs) Changes

## List CRDs related to ACM
oc get crds | grep open-cluster-management

## Describe a specific CRD
oc describe crd <crd-name>

## Compare CRDs before and after upgrade (if you have backup)
diff crds-backup.yaml crds-current.yaml

## Export current CRDs to snapshot:
oc get crd -o yaml > crds-post-upgrade.yaml
```

# Check Configuration Changes

## Export the current MultiClusterHub (MCH) configuration
oc get multiclusterhub -n open-cluster-management -o yaml

## Compare with pre-upgrade version
diff mch-pre-upgrade.yaml mch-post-upgrade.yaml

# Audit Changes After Upgrade

## Review recent events in ACM namespace
oc get events -n open-cluster-management --sort-by=.lastTimestamp

## Check resources created/modified recently
oc get all -n open-cluster-management --sort-by=.metadata.creationTimestamp

---


