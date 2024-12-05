#!/usr/bin/env bash

set -e

# The pullspec should be image index, check if all architectures are there with: skopeo inspect --raw docker://$IMG | jq
export TEMPO_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo@sha256:ae7235d3f721606afd16b0b47b9aecb45fc1a6b523246626d66236bfe4f32b8d"
# Separate due to merge conflicts
export TEMPO_QUERY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-query@sha256:ad1e5d4bf9fa7b85dd915c37ffa35ded71c70634e81e9352e759351a23ff3e79"
# Separate due to merge conflicts
export TEMPO_JAEGER_QUERY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-jaeger-query@sha256:53a63bdc77af57d2f3b559d498a86265cf9cc495fb3e9f03e35d2554a1126c2b"
# separate due to merge conflicts
export TEMPO_GATEWAY_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-gateway@sha256:49dbb18a17f35bf5451f5ea1245e7c76eb2fcdf8ed50c822b2a1879a105537cb"
# separate due to merge conflicts
export TEMPO_OPA_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-opa@sha256:98bf4294a7ddb8ba9c9d8e06482ae1813ffe81484a27ce6940410745162f8054"
# Separate due to merge conflicts
export TEMPO_OPERATOR_IMAGE_PULLSPEC="quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-operator@sha256:916572545f4fbd53f89f6b4d010832791c2756335534a60a81ab5e3aef98314e"
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
