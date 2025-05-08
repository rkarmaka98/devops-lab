# ⚙️ 1 — Base OS
FROM ubuntu:24.04 AS base
ENV DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------
# 🔗 2 — Core packages + helpers
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git ca-certificates wget unzip gnupg lsb-release \
        make build-essential software-properties-common apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# 🔑 3 — Third‑party APT repositories (all keys stored under /usr/share/keyrings)
# ——— Kubernetes (kubectl) ———
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
      | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
      https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
      > /etc/apt/sources.list.d/kubernetes.list
# ——— Helm ———
RUN curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor -o /usr/share/keyrings/helm.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] \
      https://baltocdn.com/helm/stable/debian/ all main" \
      > /etc/apt/sources.list.d/helm-stable-debian.list
# ——— HashiCorp (Terraform) ———
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp.gpg] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/hashicorp.list
# ——— Ansible PPA (latest stable) ———
RUN add-apt-repository --yes ppa:ansible/ansible

# --------------------------------------------------
# 📦 4 — Install repo‑based packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        kubectl helm terraform ansible python3-pip \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# ☁️ 5 — Azure CLI (script install because Ubuntu 24.04 repo not yet published)
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# --------------------------------------------------
# 🔽 6 — Single‑binary tools (latest GitHub releases)
RUN curl -s https://fluxcd.io/install.sh | bash && \
    curl -L https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
         -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign && \
    curl -L https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static \
         -o /usr/local/bin/opa && chmod +x /usr/local/bin/opa && \
    curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64 && chmod +x /usr/local/bin/kind && \
    curl -Lo k9s.tgz https://github.com/derailed/k9s/releases/download/v0.50.4/k9s_Linux_amd64.tar.gz && \
         tar -xzOf k9s.tgz k9s > /usr/local/bin/k9s && chmod +x /usr/local/bin/k9s && rm -f k9s.tgz

# --------------------------------------------------
# 🔧 7 — Latest stable Go (1.23)
RUN curl -L https://go.dev/dl/go1.23.0.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# 🐚 8 — Default entrypoint
CMD ["/bin/bash"]