#!/usr/bin/env bash

set -e

# The pullspec should be image index, check if all architectures are there with: skopeo inspect --raw docker://$IMG | jq
export TEMPO_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-tempo@sha256:1594bbb49ccc4d40c06462f6875c30f122153b2409ff4e96db14f19815a295a1"
# Separate due to merge conflicts
export TEMPO_QUERY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-query@sha256:ce900fca4102c11a23901132be20b54e1c68c5241bf31f673bf448cf93e47170"
# Separate due to merge conflicts
export TEMPO_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-operator@sha256:06b2c5b4081103bc34c53d3a1823eeda3cb24e9a9a17996ce55947c610b347b2"
# separate due to merge conflicts
export TEMPO_GATEWAY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-gateway@sha256:5a77802d22e7f1d23279e6e05da98295ef3a07c3f03bbd206b232edf10fe6e8d"
# separate due to merge conflicts
export TEMPO_OPA_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-opa@sha256:474356fe1dbcbda99ebd190b257f5b4ee7f6706349db4b4451be9cef30ba0b5c"


export CSV_FILE=/manifests/tempo-operator.clusterserviceversion.yaml

sed -i -e "s|ghcr.io/grafana/tempo-operator/tempo-operator\:.*|\"${TEMPO_OPERATOR_IMAGE_PULLSPEC}\"|g" \
	"${CSV_FILE}"

sed -i "s#tempo-container-pullspec#$TEMPO_IMAGE_PULLSPEC#g" patch_csv.yaml
sed -i "s#tempo-query-container-pullspec#$TEMPO_QUERY_IMAGE_PULLSPEC#g" patch_csv.yaml
sed -i "s#tempo-gateway-container-pullspec#$TEMPO_GATEWAY_IMAGE_PULLSPEC#g" patch_csv.yaml
sed -i "s#tempo-opa-container-pullspec#$TEMPO_OPA_IMAGE_PULLSPEC#g" patch_csv.yaml

export AMD64_BUILT=$(skopeo inspect --raw docker://${TEMPO_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="amd64")')
export ARM64_BUILT=$(skopeo inspect --raw docker://${TEMPO_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="arm64")')
export PPC64LE_BUILT=$(skopeo inspect --raw docker://${TEMPO_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="ppc64le")')
export S390X_BUILT=$(skopeo inspect --raw docker://${TEMPO_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="s390x")')

export EPOC_TIMESTAMP=$(date +%s)


# time for some direct modifications to the csv
python3 patch_csv.py
python3 patch_annotations.py
