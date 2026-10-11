#!/usr/bin/env bash
# Build the Strapi app into a Docker image and push it to a container registry.
# Default registry: GitHub Container Registry (ghcr.io)
#
# Usage:
#   CR_PAT=ghp_xxx ./scripts/docker-publish.sh
#   TAG=1.0.0 CR_PAT=ghp_xxx ./scripts/docker-publish.sh
#   NO_PUSH=true ./scripts/docker-publish.sh        # build only
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io}"
OWNER="${OWNER:-kittipong-kum-ai}"
NAME="${NAME:-}"
TAG="${TAG:-}"
USER="${USER:-$OWNER}"
TOKEN="${CR_PAT:-${GHCR_TOKEN:-}}"
NO_LATEST="${NO_LATEST:-false}"
NO_PUSH="${NO_PUSH:-false}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v docker >/dev/null 2>&1 || { echo "docker was not found in PATH" >&2; exit 1; }

if [ -z "$NAME" ] || [ -z "$TAG" ]; then
  NAME_DEFAULT="$(basename "$ROOT")"
  TAG_DEFAULT="$(node -p "require('$ROOT/package.json').version")"
  NAME="${NAME:-$NAME_DEFAULT}"
  TAG="${TAG:-$TAG_DEFAULT}"
fi

IMAGE_BASE="$(echo "$REGISTRY/$OWNER/$NAME" | tr '[:upper:]' '[:lower:]')"
TAGS=("$IMAGE_BASE:$TAG")
if [ "$NO_LATEST" != "true" ] && [ "$TAG" != "latest" ]; then
  TAGS+=("$IMAGE_BASE:latest")
fi

BUILD_ARGS=(build -f "$ROOT/Dockerfile")
for t in "${TAGS[@]}"; do BUILD_ARGS+=(-t "$t"); done
BUILD_ARGS+=("$ROOT")

echo "==> Building: ${TAGS[*]}"
docker "${BUILD_ARGS[@]}"

if [ "$NO_PUSH" = "true" ]; then
  echo "==> Skipping push (NO_PUSH=true)"
  exit 0
fi

if [ -n "$TOKEN" ]; then
  echo "==> Logging in to $REGISTRY as $USER"
  echo "$TOKEN" | docker login "$REGISTRY" -u "$USER" --password-stdin
else
  echo "==> No token supplied; assuming an existing session for $REGISTRY"
fi

for t in "${TAGS[@]}"; do
  echo "==> Pushing $t"
  docker push "$t"
done

echo "==> Done:"
printf '  %s\n' "${TAGS[@]}"
