#!/bin/bash
set -eu

# Propagates version information to various static files.
# This file is intentionally kept as a shellscript, to simplify product-specific modifications.

echo "Fetching tags of all submodules..."
git submodule foreach --recursive "git fetch --tags" > /dev/null 2>&1

OPERATOR_VERSION=$(cd tempo-operator && git describe --tags --abbrev=0 | sed 's/^v//')
TEMPO_VERSION=$(cd tempo && git describe --tags --abbrev=0 | sed 's/^v//')
JAEGER_VERSION=$(cd jaeger && git describe --tags --abbrev=0 | sed 's/^v//')

RHOSDT_VERSION=3.7
BUNDLE_VERSION=${OPERATOR_VERSION}-1
PREVIOUS_BUNDLE_VERSION=0.16.0-2
MIN_OPENSHIFT_VERSION=4.12

echo "Updating version numbers in Dockerfiles and bundle..."
echo
echo "Operator: ${OPERATOR_VERSION}"
echo "Tempo: ${TEMPO_VERSION}"
echo "Jaeger: ${JAEGER_VERSION}"
echo "Bundle: ${BUNDLE_VERSION} (previous: ${PREVIOUS_BUNDLE_VERSION})"
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
yq -i e ".spec.replaces = \"tempo-operator.v${PREVIOUS_BUNDLE_VERSION}\"" bundle-patch/patch_csv.yaml
sed -Ei "s/olm.skipRange: '>=(.*) <[^']*/olm.skipRange: '>=\1 <${BUNDLE_VERSION}/g" bundle-patch/patch_csv.yaml
