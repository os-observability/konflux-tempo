#!/bin/bash
set -euo pipefail

# Propagates version information to various static files.
# This file is intentionally kept as a shellscript, to simplify product-specific modifications.


# TODO: update version
RHOSDT_VERSION=3.7
# TODO: set latest supported OCP version, see https://access.redhat.com/support/policy/updates/openshift#dates
MIN_OPENSHIFT_VERSION=4.12


echo "Fetching tags of all submodules..."
git submodule foreach --recursive "git fetch --tags" > /dev/null 2>&1
OPERATOR_VERSION=$(cd tempo-operator && git describe --tags --abbrev=0 | sed 's/^v//')
TEMPO_VERSION=$(cd tempo && git describe --tags --abbrev=0 | sed 's/^v//')
JAEGER_VERSION=$(cd jaeger && git describe --tags --abbrev=0 | sed 's/^v//')

echo "Fetching version of latest released bundle..."
RELEASED_BUNDLE_VERSION=$(kubectl get packagemanifests.packages.operators.coreos.com tempo-product -o jsonpath='{.status.channels[0].currentCSV}' | sed 's/^.*\.v//')
RELEASED_VERSION=${RELEASED_BUNDLE_VERSION%%-*}
RELEASED_BUILDNUMBER=${RELEASED_BUNDLE_VERSION##*-}
if [[ "${OPERATOR_VERSION}" = "${RELEASED_VERSION}" ]]; then
  BUNDLE_BUILDNUMBER=$((RELEASED_BUILDNUMBER+1))
else
  BUNDLE_BUILDNUMBER=1
fi
BUNDLE_VERSION=${OPERATOR_VERSION}-${BUNDLE_BUILDNUMBER}

echo "Updating version numbers in Dockerfiles and bundle..."
echo
echo "Operator: ${OPERATOR_VERSION}"
echo "Tempo: ${TEMPO_VERSION}"
echo "Jaeger: ${JAEGER_VERSION}"
echo "Bundle: ${BUNDLE_VERSION} (previous: ${RELEASED_BUNDLE_VERSION})"
echo "Min OpenShift version: ${MIN_OPENSHIFT_VERSION}"

# version information in binaries
sed -Ei "s/exportOrFail OPERATOR_VERSION=[^ ]*/exportOrFail OPERATOR_VERSION=\"${OPERATOR_VERSION}\"/g" Dockerfile.operator
sed -Ei "s/exportOrFail VERSION=[^ ]*/exportOrFail VERSION=\"${TEMPO_VERSION}\"/g" Dockerfile.tempo Dockerfile.tempoquery
sed -Ei "s/exportOrFail GIT_LATEST_TAG=[^ ]*/exportOrFail GIT_LATEST_TAG=\"${JAEGER_VERSION}\"/g" Dockerfile.jaegerquery

# container labels
sed -Ei "s/ARG VERSION=.*/ARG VERSION=${BUNDLE_VERSION}/g" Dockerfile.*
sed -Ei "s/cpe=[^ ]*/cpe=\"cpe:\/a:redhat:openshift_distributed_tracing:${RHOSDT_VERSION}::el8\"/g" Dockerfile.*
sed -Ei "s/com.redhat.openshift.versions=[^ ]*/com.redhat.openshift.versions=v${MIN_OPENSHIFT_VERSION}/g" Dockerfile.bundle

# CSV
yq -i e ".spec.version = \"${BUNDLE_VERSION}\"" bundle-patch/patch_csv.yaml
yq -i e ".metadata.name = \"tempo-operator.v${BUNDLE_VERSION}\"" bundle-patch/patch_csv.yaml
yq -i e ".spec.replaces = \"tempo-operator.v${RELEASED_BUNDLE_VERSION}\"" bundle-patch/patch_csv.yaml
sed -Ei "s/olm.skipRange: '>=(.*) <[^']*/olm.skipRange: '>=\1 <${BUNDLE_VERSION}/g" bundle-patch/patch_csv.yaml
