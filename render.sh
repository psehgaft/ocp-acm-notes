#!/usr/bin/env bash
set -euo pipefail
# Render templates using envsubst from variables.yaml
# Requirements: yq, jq, envsubst
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

if [[ ! -f variables.yaml ]]; then
  echo "variables.yaml not found. Copy variables.example.yaml to variables.yaml and edit."
  exit 1
fi

# Export variables for envsubst
export clusterName=$(yq -r '.clusterName' variables.yaml)
export baseDomain=$(yq -r '.baseDomain' variables.yaml)
export namespace=$(yq -r '.namespace' variables.yaml)
export clusterImageSetName=$(yq -r '.clusterImageSetName' variables.yaml)
export sshPublicKey=$(yq -r '.sshPublicKey' variables.yaml)
export machineNetworkCIDR=$(yq -r '.networking.machineNetworkCIDR' variables.yaml)
export serviceNetworkCIDR=$(yq -r '.networking.serviceNetworkCIDR' variables.yaml)
export clusterNetworkCIDR=$(yq -r '.networking.clusterNetworkCIDR' variables.yaml)
export hostPrefix=$(yq -r '.networking.hostPrefix' variables.yaml)
export apiVIP=$(yq -r '.networking.apiVIP' variables.yaml)
export ingressVIP=$(yq -r '.networking.ingressVIP' variables.yaml)
export ntpSources_csv=$(yq -r '.networking.ntpSources | join(",")' variables.yaml)
export installConfigOverrides_json=$(yq -r '.installConfigOverrides' variables.yaml | jq -c .)
export releaseImage=${RELEASE_IMAGE:-"quay.io/openshift-release-dev/ocp-release:${OCP_VERSION:-4.18.12}-x86_64"}

# pullSecret: allow inline or env var PULL_SECRET
if yq -e '.pullSecret' variables.yaml >/dev/null 2>&1; then
  export pullSecret_b64=$(yq -r '.pullSecret' variables.yaml | base64 -w0)
elif [[ -n "${PULL_SECRET:-}" ]]; then
  export pullSecret_b64=$(printf '%s' "${PULL_SECRET}" | base64 -w0)
else
  echo "ERROR: set pullSecret in variables.yaml or export PULL_SECRET env var."
  exit 1
fi

# Proxy block
if yq -e '.proxy.httpProxy' variables.yaml >/dev/null 2>&1; then
  export proxy_block=$(cat <<'EOF'
    httpProxy: "$(yq -r '.proxy.httpProxy' variables.yaml)"
    httpsProxy: "$(yq -r '.proxy.httpsProxy' variables.yaml)"
    noProxy: "$(yq -r '.proxy.noProxy' variables.yaml)"
EOF
)
else
  export proxy_block="# {}"
fi

# Addon toggles
export enable_observability=$(yq -r '.enableAddons.observability' variables.yaml)
export enable_policy=$(yq -r '.enableAddons.policyController' variables.yaml)
export enable_search=$(yq -r '.enableAddons.searchCollector' variables.yaml)

mkdir -p rendered

# Render base templates
for f in 00-namespace.yaml 01-clusterimageset.yaml 03-agentclusterinstall.yaml 04-clusterdeployment.yaml 05-infraenv.yaml 07-managedcluster.yaml 08-klusterletaddonconfig.yaml; do
  envsubst < "templates/$f" > "rendered/$f"
done

# Render NMState per host
> rendered/06-nmstateconfigs.yaml
count=$(yq '.hosts | length' variables.yaml)
for i in $(seq 0 $((count-1))); do
  export hostname=$(yq -r ".hosts[$i].hostname" variables.yaml)
  export ifname=$(yq -r ".hosts[$i].interfaces[0].name" variables.yaml)
  export mac=$(yq -r ".hosts[$i].interfaces[0].macAddress" variables.yaml)
  export ip=$(yq -r ".hosts[$i].interfaces[0].ipv4.address" variables.yaml)
  export prefixLength=$(yq -r ".hosts[$i].interfaces[0].ipv4.prefixLength" variables.yaml)
  export gateway=$(yq -r ".hosts[$i].interfaces[0].ipv4.gateway" variables.yaml)
  # DNS list to YAML block
  dns=$(yq -r ".hosts[$i].interfaces[0].ipv4.dns | @csv" variables.yaml 2>/dev/null || echo "")
  if [[ -z "$dns" || "$dns" == "null" ]]; then
    export dns_block="                - 8.8.8.8"
  else
    export dns_block=$(python3 - <<PY
import os
vals = os.environ.get("dns","").split(",")
print("\n".join([f"                - {v.strip().strip('"')}" for v in vals if v.strip()]))
PY
)
  fi
  envsubst < "templates/06-nmstateconfigs.yaml" >> "rendered/06-nmstateconfigs.yaml"
  echo "---" >> rendered/06-nmstateconfigs.yaml
done

echo "Rendered manifests in $(realpath rendered)"
