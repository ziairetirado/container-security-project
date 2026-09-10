#!/usr/bin/env bash
# Build the container image and scan it with Trivy before allowing it to be pushed.
set -euo pipefail

IMAGE_NAME="demo-app"
IMAGE_TAG="${1:-local}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
SEVERITY_GATE="HIGH,CRITICAL"

echo "==> Building image: ${FULL_IMAGE}"
docker build -t "${FULL_IMAGE}" ./docker

echo "==> Scanning ${FULL_IMAGE} with Trivy (failing on ${SEVERITY_GATE})"
# --exit-code 1 makes the script (and CI job) fail if matching vulns are found
trivy image \
  --severity "${SEVERITY_GATE}" \
  --exit-code 1 \
  --ignore-unfixed \
  --format table \
  "${FULL_IMAGE}"

echo "==> No HIGH/CRITICAL vulnerabilities with a fix available. Safe to push."
