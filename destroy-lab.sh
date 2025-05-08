#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# destroy-lab.sh
# Purpose : Stop & remove DevOps study lab containers, volumes, and Kind cluster.
# Usage   : ./destroy-lab.sh [cluster-name]  # default: study-k8s
# ---------------------------------------------------------------------------
set -euo pipefail

CLUSTER_NAME=${1:-study-k8s}

printf "
🧹  Shutting down docker‑compose stack…
"
docker compose down -v --remove-orphans || echo "(compose stack already gone)"

printf "🗑  Removing any stray devops‑lab containers…
"
LAB_CTRS=$(docker ps -a --filter "ancestor=devops-lab:latest" -q)
[ -n "$LAB_CTRS" ] && docker rm -f $LAB_CTRS || echo "(no running devops‑lab containers)"

printf "🪣  Deleting Kind cluster '%s'…
" "$CLUSTER_NAME"
kind delete cluster --name "$CLUSTER_NAME" || echo "(cluster not found)"

printf "📂  Cleaning kubeconfig file…
"
rm -f "$HOME/.kube/kind-config-$CLUSTER_NAME" || true

printf "✅  Lab resources removed. Have a clean slate!
"