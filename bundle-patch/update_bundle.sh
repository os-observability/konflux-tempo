#!/usr/bin/env bash

set -e

# The pullspec should be image index, check if all architectures are there with: skopeo inspect --raw docker://$IMG | jq
export TEMPO_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo@sha256:72ac3ed2c813b66e8c4e8e2d411ad51a233a8a62d7e1d7773c7c4a079d9167f3"
# Separate due to merge conflicts
export TEMPO_QUERY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-query@sha256:a46f198caa16a547416741595dd99c00fdeac8e6d69d8d4e0fddd91ba3f00e83"
# Separate due to merge conflicts
export TEMPO_JAEGER_QUERY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-jaeger-query@sha256:f44eec70bd083b28ac53683a691431e752b8c58b2b2d5f21bc6b2511e82de75e"
# separate due to merge conflicts
export TEMPO_GATEWAY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-gateway@sha256:feece7028ea67baa4a850175ea3eff4ec13c4bd582b3c2bb14b859556295e0e9"
# separate due to merge conflicts
export TEMPO_OPA_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-opa@sha256:7ebc005431046612b966f1efeafdff1c8f584e900014ce165baa43c3af014d1c"
# Separate due to merge conflicts
export TEMPO_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-operator@sha256:0e5fcd2f8d8e7456b234bc942977fbca7b69d03dea658e358e2596ade066b460"
# Separate due to merge conflicts
# TODO, we used to set the proxy image per OCP version
export OSE_KUBE_RBAC_PROXY_PULLSPEC="registry.redhat.io/openshift4/ose-kube-rbac-proxy@sha256:8204d45506297578c8e41bcc61135da0c7ca244ccbd1b39070684dfeb4c2f26c"
export OSE_OAUTH_PROXY_PULLSPEC="registry.redhat.io/openshift4/ose-oauth-proxy@sha256:4f8d66597feeb32bb18699326029f9a71a5aca4a57679d636b876377c2e95695"

if [[ $REGISTRY == "registry.redhat.io" ||  $REGISTRY == "registry.stage.redhat.io" ]]; then
  TEMPO_IMAGE_PULLSPEC="$REGISTRY/rhosdt/tempo-rhel8@${TEMPO_IMAGE_PULLSPEC:(-71)}"
  TEMPO_QUERY_IMAGE_PULLSPEC="$REGISTRY/rhosdt/tempo-query-rhel8@${TEMPO_QUERY_IMAGE_PULLSPEC:(-71)}"
  TEMPO_JAEGER_QUERY_IMAGE_PULLSPEC="$REGISTRY/rhosdt/tempo-jaeger-query-rhel8@${TEMPO_JAEGER_QUERY_IMAGE_PULLSPEC:(-71)}"
  TEMPO_GATEWAY_IMAGE_PULLSPEC="$REGISTRY/rhosdt/tempo-gateway-rhel8@${TEMPO_GATEWAY_IMAGE_PULLSPEC:(-71)}"
  TEMPO_OPA_IMAGE_PULLSPEC="$REGISTRY/rhosdt/tempo-gateway-opa-rhel8@${TEMPO_OPA_IMAGE_PULLSPEC:(-71)}"
  TEMPO_OPERATOR_IMAGE_PULLSPEC="$REGISTRY/rhosdt/tempo-rhel8-operator@${TEMPO_OPERATOR_IMAGE_PULLSPEC:(-71)}"
fi


export CSV_FILE=/manifests/tempo-operator.clusterserviceversion.yaml

sed -i "s#tempo-container-pullspec#$TEMPO_IMAGE_PULLSPEC#g" patch_csv.yaml
sed -i "s#tempo-query-container-pullspec#$TEMPO_QUERY_IMAGE_PULLSPEC#g" patch_csv.yaml
sed -i "s#tempo-jaeger-query-container-pullspec#$TEMPO_JAEGER_QUERY_IMAGE_PULLSPEC#g" patch_csv.yaml
sed -i "s#tempo-gateway-container-pullspec#$TEMPO_GATEWAY_IMAGE_PULLSPEC#g" patch_csv.yaml
sed -i "s#tempo-opa-container-pullspec#$TEMPO_OPA_IMAGE_PULLSPEC#g" patch_csv.yaml
sed -i "s#tempo-operator-container-pullspec#$TEMPO_OPERATOR_IMAGE_PULLSPEC#g" patch_csv.yaml
sed -i "s#ose-kube-rbac-proxy-container-pullspec#$OSE_KUBE_RBAC_PROXY_PULLSPEC#g" patch_csv.yaml
sed -i "s#ose-oauth-proxy-container-pullspec#$OSE_OAUTH_PROXY_PULLSPEC#g" patch_csv.yaml

#export AMD64_BUILT=$(skopeo inspect --raw docker://${TEMPO_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="amd64")')
#export ARM64_BUILT=$(skopeo inspect --raw docker://${TEMPO_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="arm64")')
#export PPC64LE_BUILT=$(skopeo inspect --raw docker://${TEMPO_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="ppc64le")')
#export S390X_BUILT=$(skopeo inspect --raw docker://${TEMPO_OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="s390x")')
export AMD64_BUILT=true
export ARM64_BUILT=true
export PPC64LE_BUILT=true
export S390X_BUILT=true

export EPOC_TIMESTAMP=$(date +%s)


# time for some direct modifications to the csv
python3 patch_csv.py
python3 patch_annotations.py
