#!/bin/bash
set -eu

#
# A central place to store all version numbers.
# This script will update the (static) version numbers which are embedded in other files (e.g. Dockerfile).
#

echo "Fetching tags of all submodules"
git submodule foreach --recursive "git fetch --tags"

OPERATOR_VERSION=$(cd tempo-operator && git describe --tags --abbrev=0 | sed 's/^v//')
TEMPO_VERSION=$(cd tempo && git describe --tags --abbrev=0 | sed 's/^v//')
JAEGER_VERSION=$(cd jaeger && git describe --tags --abbrev=0 | sed 's/^v//')
BUNDLE_VERSION=${OPERATOR_VERSION}-2
PREVIOUS_BUNDLE_VERSION=0.16.0-1
MIN_OPENSHIFT_VERSION=4.12

# version information in binaries
sed -Ei "s/exportOrFail OPERATOR_VERSION=[^ ]*/exportOrFail OPERATOR_VERSION=\"${OPERATOR_VERSION}\"/g" Dockerfile.operator
sed -Ei "s/exportOrFail VERSION=[^ ]*/exportOrFail VERSION=\"${TEMPO_VERSION}\"/g" Dockerfile.tempo Dockerfile.tempoquery
sed -Ei "s/exportOrFail GIT_LATEST_TAG=[^ ]*/exportOrFail GIT_LATEST_TAG=\"${JAEGER_VERSION}\"/g" Dockerfile.jaegerquery

# container labels
sed -Ei "s/ARG VERSION=.*/ARG VERSION=${BUNDLE_VERSION}/g" Dockerfile.*
sed -Ei "s/com.redhat.openshift.versions=[^ ]*/com.redhat.openshift.versions=v${MIN_OPENSHIFT_VERSION}/g" Dockerfile.bundle

# CSV
sed -Ei "s/  version: .*/  version: ${BUNDLE_VERSION}/g" bundle-patch/patch_csv.yaml
sed -Ei "s/name: tempo-operator.v.*/name: tempo-operator.v${BUNDLE_VERSION}/g" bundle-patch/patch_csv.yaml
sed -Ei "s/replaces: tempo-operator.v.*/replaces: tempo-operator.v${PREVIOUS_BUNDLE_VERSION}/g" bundle-patch/patch_csv.yaml
sed -Ei "s/olm.skipRange: '>=(.*) <[^']*/olm.skipRange: '>=\1 <${BUNDLE_VERSION}/g" bundle-patch/patch_csv.yaml
