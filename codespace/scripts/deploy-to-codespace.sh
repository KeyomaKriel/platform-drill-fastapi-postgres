#!/bin/bash
set -euo pipefail

#
# Deploy a drill app to a GitHub Codespace.
#
# Usage:
#   ./scripts/deploy-to-codespace.sh <app-folder> [codespace-name]
#
# Examples:
#   ./scripts/deploy-to-codespace.sh drill-app
#   ./scripts/deploy-to-codespace.sh drill-app-django
#   ./scripts/deploy-to-codespace.sh drill-app-go my-codespace-name
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODESPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CODESPACE_DIR/.." && pwd)"

APP_FOLDER="${1:?Usage: $0 <app-folder> [codespace-name]}"
APP_DIR="$CODESPACE_DIR/$APP_FOLDER"
CODESPACE_NAME="${2:-}"

REPO="KeyomaKriel/platform-drill-fastapi-postgres"
BRANCH="mac-eks-drill"

if [ ! -d "$APP_DIR" ]; then
  echo "ERROR: App directory not found: $APP_DIR"
  echo "Available apps:"
  ls -d "$CODESPACE_DIR"/drill-app* 2>/dev/null | xargs -I{} basename {}
  exit 1
fi

if [ ! -f "$APP_DIR/deploy.sh" ]; then
  echo "ERROR: No deploy.sh found in $APP_DIR"
  exit 1
fi

echo "=== Drill App Deployment ==="
echo "App: $APP_FOLDER"
echo "Repo: $REPO"
echo "Branch: $BRANCH"
echo ""

# --- Step 1: Ensure changes are pushed ---
echo "=== Step 1: Push to remote ==="
cd "$REPO_ROOT"
if ! git diff --quiet HEAD -- "codespace/$APP_FOLDER/" .devcontainer/ 2>/dev/null; then
  echo "Uncommitted changes detected in $APP_FOLDER or .devcontainer/."
  echo "Commit and push first, or pass --force to skip this check."
  exit 1
fi

REMOTE_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
if [ -z "$REMOTE_BRANCH" ]; then
  echo "No upstream tracking branch. Push with:"
  echo "  git push -u origin $BRANCH"
  exit 1
fi
echo "Branch $BRANCH is tracking $REMOTE_BRANCH. OK."

# --- Step 2: Find or create Codespace ---
echo ""
echo "=== Step 2: Find or create Codespace ==="

if [ -n "$CODESPACE_NAME" ]; then
  echo "Using specified codespace: $CODESPACE_NAME"
else
  CODESPACE_NAME=$(gh codespace list -R "$REPO" --json name,state,branch -q "[.[] | select(.branch==\"$BRANCH\")] | .[0].name // empty" 2>/dev/null || echo "")

  if [ -n "$CODESPACE_NAME" ]; then
    echo "Found existing codespace: $CODESPACE_NAME"
  else
    echo "No existing codespace found. Creating one..."
    CODESPACE_NAME=$(gh codespace create \
      -R "$REPO" \
      -b "$BRANCH" \
      -m basicLinux32gb \
      --idle-timeout 30m \
      --default-permissions \
      -s 2>&1 | tail -1)
    echo "Created codespace: $CODESPACE_NAME"
    echo "Waiting for environment setup (this takes 2-4 minutes on first create)..."
    sleep 10
  fi
fi

# --- Step 3: Copy app to Codespace ---
echo ""
echo "=== Step 3: Copy app to Codespace ==="

# Remove any previous drill-app in the codespace
gh codespace ssh -c "$CODESPACE_NAME" -- 'rm -rf ~/drill-app' 2>/dev/null || true

# Copy the app folder
gh codespace cp -r "$APP_DIR" "remote:~/drill-app" -c "$CODESPACE_NAME"
echo "Copied $APP_FOLDER to ~/drill-app in codespace."

# --- Step 4: Deploy inside Codespace ---
echo ""
echo "=== Step 4: Deploy inside Codespace ==="

gh codespace ssh -c "$CODESPACE_NAME" -- 'bash ~/drill-app/deploy.sh'

echo ""
echo "=== Deployment complete ==="
echo "Codespace: $CODESPACE_NAME"
echo ""
echo "To SSH into the codespace:"
echo "  gh codespace ssh -c $CODESPACE_NAME"
echo ""
echo "To start a drill session:"
echo "  gh codespace ssh -c $CODESPACE_NAME"
echo "  cd ~/drill-app && script -q -a ./session.log"
echo ""
echo "To tear down:"
echo "  gh codespace ssh -c $CODESPACE_NAME -- 'kubectl delete namespace <namespace>'"
echo "  gh codespace delete -c $CODESPACE_NAME"
