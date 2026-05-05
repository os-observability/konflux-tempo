#!/usr/bin/env bash
#
# Generic operator bundle validation via `operator-sdk bundle validate`.
#
# Catches generic bundle issues (RBAC shape, CRD validity, annotations,
# image references, etc.) that the OLMv1-specific checks in
# validate-olmv1-compliance.py do not cover. Runs the default validator
# plus selected optional validators.
#
# Reference:
#   https://sdk.operatorframework.io/docs/cli/operator-sdk_bundle_validate/
#
# Selectors enabled (start conservative; add more as the bundle stabilizes):
#   - name=operatorhub      — OperatorHub publishing rules (Red Hat
#                             products effectively follow this)
#   - name=good-practices   — generic operator best practices
#
# Why this exists: there is no Konflux catalog task that wraps
# `operator-sdk bundle validate` against a pre-built bundle image today.
# When one is published upstream, replace the pipeline step with a
# `taskRef` and remove this script.
#
# Inputs: BUNDLE_IMAGE env var — pullable bundle reference.
# Outputs: exits 0 if all selected validators pass, non-zero otherwise.

set -euo pipefail

if [ -z "${BUNDLE_IMAGE:-}" ]; then
  echo "BUNDLE_IMAGE env var is required (e.g. registry/ns/bundle@sha256:...)" >&2
  exit 1
fi

OPERATOR_SDK_VERSION="${OPERATOR_SDK_VERSION:-v1.41.0}"

echo "Installing tools"
microdnf install -y --nodocs skopeo file tar gzip findutils >/dev/null

ARCH=$(uname -m)
case "${ARCH}" in
  x86_64)  SDK_ARCH=amd64 ;;
  aarch64) SDK_ARCH=arm64 ;;
  *) echo "unsupported arch: ${ARCH}" >&2; exit 1 ;;
esac

echo "Installing operator-sdk ${OPERATOR_SDK_VERSION} (${SDK_ARCH})"
curl -fsSL -o /usr/local/bin/operator-sdk \
  "https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/operator-sdk_linux_${SDK_ARCH}"
chmod +x /usr/local/bin/operator-sdk

echo "Pulling and extracting bundle: ${BUNDLE_IMAGE}"
WORKDIR=$(mktemp -d)
OCI_DIR="${WORKDIR}/oci"
EXTRACT_DIR="${WORKDIR}/extract"
mkdir -p "${OCI_DIR}" "${EXTRACT_DIR}"

skopeo copy --retry-times 3 \
  "docker://${BUNDLE_IMAGE}" \
  "oci:${OCI_DIR}:latest"

# Bundle images are scratch + manifests/ + metadata/, so the extracted
# layers form a valid bundle root that operator-sdk can validate directly.
for blob in "${OCI_DIR}"/blobs/sha256/*; do
  if file -b "${blob}" 2>/dev/null | grep -q gzip; then
    tar -xzf "${blob}" -C "${EXTRACT_DIR}" 2>/dev/null || true
  fi
done

echo "Running operator-sdk bundle validate against ${EXTRACT_DIR}"
exec operator-sdk bundle validate "${EXTRACT_DIR}" \
  --select-optional=name=operatorhub \
  --select-optional=name=good-practices
