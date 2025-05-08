#!/usr/bin/env bash
set -euo pipefail
CLUSTER_NAME=${1:-study-k8s}

printf "\n🛠  Creating Kind cluster '%s' (skip if exists)...\n" "$CLUSTER_NAME"
kind get clusters | grep -q "^${CLUSTER_NAME}$" || \
  kind create cluster --name "$CLUSTER_NAME" --image kindest/node:v1.30.0

# 🔑 New: retrieve kubeconfig via the supported sub‑command
# 🗂  Safe: write kubeconfig to a file, then point to that *path* (avoids ENAMETOOLONG)
KCFG="$HOME/.kube/kind-config-$CLUSTER_NAME"
kind get kubeconfig --name "$CLUSTER_NAME" > "$KCFG"
export KUBECONFIG="$KCFG"

printf "🔌 Validating connectivity...\n"
kubectl cluster-info

printf "📦 Adding (or updating) Helm repos...\n"
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts || true
# 📚  Popular public charts (Bitnami) – needed for tutorial commands like `bitnami/nginx`
helm repo add bitnami https://charts.bitnami.com/bitnami || true
helm repo update

printf "🚀 Installing / upgrading Argo CD...\n"
helm upgrade --install argo argo/argo-cd \
  --namespace argocd --create-namespace

printf "🛡  Installing / upgrading Gatekeeper...\n"
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system --create-namespace \
  --set enableExternalData=true

printf "📊 Installing / upgrading kube-prometheus-stack...\n"
helm upgrade --install kp prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

cat <<EOF
✅  Kind lab is ready!
* Argo CD UI : kubectl -n argocd port-forward svc/argo-cd-argocd-server 8084:80
* Grafana UI : kubectl -n monitoring port-forward svc/kp-grafana 3000:80
* k9s quick  : k9s --context kind-${CLUSTER_NAME}
EOF