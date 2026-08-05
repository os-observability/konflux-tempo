#!/bin/bash

set -euo pipefail

# Required architectures
REQUIRED_ARCHS=("amd64" "arm64" "s390x" "ppc64le")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 <docker-image-pullspec>"
    echo ""
    echo "Example:"
    echo "  $0 registry.redhat.io/openshift4/ose-kube-rbac-proxy@sha256:abc123..."
    echo "  $0 quay.io/example/image:latest"
    exit 1
}

# Check if image argument is provided
if [[ $# -ne 1 ]]; then
    usage
fi

IMAGE="$1"

echo -e "${YELLOW}Checking image: $IMAGE${NC}"

# Get raw manifest using docker manifest inspect
echo "Fetching manifest..."
MANIFEST=$(docker manifest inspect "$IMAGE" 2>&1) || {
    echo -e "${RED}✗ Failed to inspect image manifest${NC}"
    echo -e "${RED}Error: $MANIFEST${NC}"
    exit 1
}

# Check if it's a manifest list (multi-arch) - support both Docker and OCI formats
MEDIA_TYPE=$(echo "$MANIFEST" | jq -r '.mediaType // empty')

if [[ "$MEDIA_TYPE" != "application/vnd.docker.distribution.manifest.list.v2+json" && "$MEDIA_TYPE" != "application/vnd.oci.image.index.v1+json" ]]; then
    echo -e "${RED}✗ Not a multi-arch image${NC}"
    echo "  Media type: $MEDIA_TYPE"
    exit 1
fi

# Get available architectures
AVAILABLE_ARCHS=$(echo "$MANIFEST" | jq -r '.manifests[].platform.architecture' | sort)

echo "Available architectures:"
echo "$AVAILABLE_ARCHS" | sed 's/^/  /'

# Check if all required architectures are present
MISSING_ARCHS=()
for arch in "${REQUIRED_ARCHS[@]}"; do
    if ! echo "$AVAILABLE_ARCHS" | grep -q "^$arch$"; then
        MISSING_ARCHS+=("$arch")
    fi
done

if [[ ${#MISSING_ARCHS[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ All required architectures present (amd64, arm64, s390x, ppc64le)${NC}"
    exit 0
else
    echo -e "${RED}✗ Missing required architectures: ${MISSING_ARCHS[*]}${NC}"
    exit 1
fi
