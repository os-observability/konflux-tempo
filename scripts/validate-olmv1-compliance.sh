#!/usr/bin/env bash
#
# OLMv1 compliance validation — bundle extraction wrapper.
#
# Pulls the built operator bundle image, extracts its layers, and hands off
# to validate-olmv1-compliance.py to perform the actual checks. See that
# script's module docstring for the full list of OLMv1 rules being validated,
# the rationale for each, and links to the authoritative OLMv1 docs.
#
# Quick reference index (full citations live in the .py docstring):
#   - OKD supported extensions:
#     https://docs.okd.io/latest/extensions/ce/olmv1-supported-extensions.html
#   - Red Hat OCP 4.21 extensions:
#     https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html-single/extensions/index
#   - operator-controller upstream limitations:
#     https://operator-framework.github.io/operator-controller/project/olmv1_limitations/
#
# Why this exists: there is no Konflux catalog task for OLMv1 static bundle
# validation yet. Once one is published upstream (konflux-ci/build-definitions),
# the pipeline step should switch to a `taskRef` and these scripts can go away.
#
# Inputs: BUNDLE_IMAGE env var — pullable bundle reference (registry/ns/name@sha256:...).
# Outputs: exits 0 if the bundle is OLMv1-compliant, non-zero otherwise.

set -euo pipefail

if [ -z "${BUNDLE_IMAGE:-}" ]; then
  echo "BUNDLE_IMAGE env var is required (e.g. registry/ns/bundle@sha256:...)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing tools"
microdnf install -y --nodocs skopeo python3 python3-pyyaml file tar gzip findutils >/dev/null

echo "Validating OLMv1 compliance for: ${BUNDLE_IMAGE}"

# Konflux passes IMAGE_URL@IMAGE_DIGEST and IMAGE_URL already carries a tag,
# yielding "repo:tag@sha256:..." which skopeo rejects ("Docker references
# with both a tag and digest are currently not supported"). Strip the tag.
PULL_REF="${BUNDLE_IMAGE}"
if [[ "${PULL_REF}" == *@* ]]; then
  _name="${PULL_REF%@*}"
  _digest="${PULL_REF##*@}"
  _last="${_name##*/}"
  if [[ "${_last}" == *:* ]]; then
    PULL_REF="${_name%/*}/${_last%%:*}@${_digest}"
  fi
fi

WORKDIR=$(mktemp -d)
OCI_DIR="${WORKDIR}/oci"
EXTRACT_DIR="${WORKDIR}/extract"
mkdir -p "${OCI_DIR}" "${EXTRACT_DIR}"

skopeo copy --retry-times 3 \
  "docker://${PULL_REF}" \
  "oci:${OCI_DIR}:latest"

# Bundle images are scratch + manifests/ + metadata/, so blind-extracting every
# gzip layer is cheap and robust against layer ordering / digest changes.
for blob in "${OCI_DIR}"/blobs/sha256/*; do
  if file -b "${blob}" 2>/dev/null | grep -q gzip; then
    tar -xzf "${blob}" -C "${EXTRACT_DIR}" 2>/dev/null || true
  fi
done

export EXTRACT_DIR
exec python3 "${SCRIPT_DIR}/validate-olmv1-compliance.py"
