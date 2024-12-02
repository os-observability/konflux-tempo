#!/usr/bin/env bash

set -e

# The pullspec should be image index, check if all architectures are there with: skopeo inspect --raw docker://$IMG | jq
export TEMPO_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo@sha256:ae7235d3f721606afd16b0b47b9aecb45fc1a6b523246626d66236bfe4f32b8d"
# Separate due to merge conflicts
export TEMPO_QUERY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-query@sha256:7c1645b2bb8a9146b6b7eedd16098c9cc09d5b39f3ba9e6b3172ce7d3d703b8f"
# Separate due to merge conflicts
export TEMPO_JAEGER_QUERY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-jaeger-query@sha256:2cc2be758f4eb449b8054c9bbbcc79e5c7a6fac81f5aeab37b36bc4604f07fc0"
# separate due to merge conflicts
export TEMPO_GATEWAY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-gateway@sha256:ca549f05f374f72efe25ad8ff6062219bf7f7a1f5e78b989326a4ee8dd6570d3"
# separate due to merge conflicts
export TEMPO_OPA_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-opa@sha256:9d0ec4614403bcc49f24f51845b02afa2b04f6108fb73664dbbb8c8f348c2737"
# Separate due to merge conflicts
export TEMPO_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-operator@sha256:ec549ea21d5506a102a3375df68d1b0d6315aeec3de605bfc9a17aa54ac373b1"
# Separate due to merge conflicts
# TODO, we used to set the proxy image per OCP version
export OSE_KUBE_RBAC_PROXY_PULLSPEC="registry.redhat.io/openshift4/ose-kube-rbac-proxy:latest@sha256:7efeeb8b29872a6f0271f651d7ae02c91daea16d853c50e374c310f044d8c76c"
export OSE_OAUTH_PROXY_PULLSPEC="registry.redhat.io/openshift4/ose-oauth-proxy:latest@sha256:234af927030921ab8f7333f61f967b4b4dee37a1b3cf85689e9e63240dd62800"

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
