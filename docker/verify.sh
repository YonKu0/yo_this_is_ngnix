#!/usr/bin/env bash
# Run from repository root. Builds the image, runs the container, and verifies
# that Nginx is serving the correct paths (/ and /health).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

IMAGE_NAME="${IMAGE_NAME:-yo-nginx:local}"
CONTAINER_NAME="${CONTAINER_NAME:-yo-nginx-verify}"
PORT="${PORT:-8888}"

echo "Building image (from repo root so nginx.conf path is correct)..."
docker build -f docker/Dockerfile -t "$IMAGE_NAME" .

echo "Removing any existing container with the same name..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "Starting container on port $PORT..."
docker run -d --name "$CONTAINER_NAME" -p "$PORT:80" "$IMAGE_NAME"

cleanup() {
  echo "Stopping and removing container..."
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for Nginx to be ready..."
for i in {1..30}; do
  if curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    break
  fi
  if [[ $i -eq 30 ]]; then
    echo "ERROR: Nginx did not become ready in time."
    exit 1
  fi
  sleep 0.5
done

echo "Checking root path (/)..."
ROOT_RESPONSE="$(curl -sf "http://127.0.0.1:$PORT/")"
if [[ "$ROOT_RESPONSE" != "yo this is nginx" ]]; then
  echo "ERROR: Expected root response 'yo this is nginx', got: $ROOT_RESPONSE"
  exit 1
fi

echo "Checking health path (/health)..."
HEALTH_RESPONSE="$(curl -sf "http://127.0.0.1:$PORT/health")"
if [[ "$HEALTH_RESPONSE" != "ok" ]]; then
  echo "ERROR: Expected health response 'ok', got: $HEALTH_RESPONSE"
  exit 1
fi

echo "All checks passed. Nginx is serving the correct paths."
echo "  GET /       -> $ROOT_RESPONSE"
echo "  GET /health -> $HEALTH_RESPONSE"
