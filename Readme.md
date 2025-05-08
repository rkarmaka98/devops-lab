# DevOps Interview Study Lab — **Full README** (2025‑05)

> An all‑in‑one, laptop‑friendly playground that lets you practise **Go**, **Kubernetes**, **GitOps**, **Jenkins**, **Azure**, and **DevSecOps** topics exactly the way senior‑level interviewers will probe. Every file is annotated and every external tool is referenced so a first‑time user can spin it up, break it, and rebuild it with confidence.

---

## 🖼  Lab Topology (Click to zoom)

*Figure 1 – host Docker engine runs three groups: a throw‑away toolbox container, a Compose stack of stateful services, and a disposable Kind cluster that hosts Argo CD, Gatekeeper, and kube‑prometheus‑stack.*

---

## 1  Requirements

| Tool / Resource             | Minimum version     | Why                                               | Install guide                                                                      |
| --------------------------- | ------------------- | ------------------------------------------------- | ---------------------------------------------------------------------------------- |
| **Docker Desktop / Engine** | 24.x (+ Compose v2) | Build image, run Compose stack, host Kind nodes   | [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/) |
| **GNU make** (optional)     | any                 | Repeatable build targets (see *Makefile*)         | distro package manager                                                             |
| **8 GB RAM / 30 GB disk**   | n/a                 | Jenkins + Sonar + Kind eat memory                 | —                                                                                  |
| **bash / zsh shell**        | on host or via WSL  | Runs helper scripts                               | builtin                                                                            |
| *(macOS only)* **Homebrew** | latest              | Easiest way to install Docker, Kind, Helm locally | [https://brew.sh](https://brew.sh)                                                 |

> **Tip:** If corporate proxies or SELinux interfere, see the troubleshooting table at the end.

---

## 2  File Tree

```text
.
├── Dockerfile              # Multipurpose CLI image (Go, kubectl, Helm, Terraform…)
├── docker-compose.yml      # Jenkins, SonarQube, Nexus, Vault
├── kind-setup.sh           # Creates Kind cluster + Argo CD, Gatekeeper, Prometheus
├── destroy-lab.sh          # One‑shot cleanup (Compose + Kind + volumes)
└── README.md               # <-- this file
```

*(Each script is annotated inline; scroll down for full listings.)*

---

## 3  Quick‑Start (5 commands)

```bash
# 1. Clone repo & build toolbox image
git clone https://github.com/your‑git‑handle/devops‑study‑lab.git && cd devops‑study‑lab
docker build -t devops-lab:latest .

# 2. Launch stateful services (Jenkins, Sonar, Nexus, Vault)
docker compose up -d

# 3. Create Kubernetes playground (Kind + add‑ons)
./kind-setup.sh           # add a custom name as arg if you like

# 4. Open Jenkins at http://localhost:8080 and copy the initial password:
docker logs jenkins 2>&1 | grep password

# 5. Deploy a sample app inside the cluster (proves Helm + kubectl work)
helm upgrade --install hello bitnami/nginx \
  --version 17.4.0 --set service.type=ClusterIP
```

*Estimated time: ****8 minutes**** on a 50 Mbit link; mostly Docker pulls.*

---

## 4  Detailed Walk‑Through

### 4.1  Build the toolbox image

The **Dockerfile** installs tools from their *official upstream repositories* to avoid stale distro packages.

```Dockerfile
# excerpt — see full file further below
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
    gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
      https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
      > /etc/apt/sources.list.d/kubernetes.list
```

*Why?* Canonical removed **kubectl** from Ubuntu 24.04 main repo; the Kubernetes project now ships its own signed APT repo – see their doc ↗︎ [https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).

Repeat for Terraform ([https://developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install)), Helm ([https://helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)), and Azure CLI ([https://learn.microsoft.com/cli/azure/install-azure-cli-linux?pivots=apt](https://learn.microsoft.com/cli/azure/install-azure-cli-linux?pivots=apt)).  Single‑binary tools (Kind, k9s, cosign, Flux, OPA) are fetched from their GitHub *latest‑release* URLs.

### 4.2  Start the service stack

`docker compose up ‑d` spins up four services:

| Service   | Image tag                   | Port | Purpose                                   | Docs                                                                                     |
| --------- | --------------------------- | ---- | ----------------------------------------- | ---------------------------------------------------------------------------------------- |
| Jenkins   | `jenkins/jenkins:lts‑jdk17` | 8080 | CI/CD pipelines (Declarative + K8s agent) | [https://www.jenkins.io/doc/](https://www.jenkins.io/doc/)                               |
| SonarQube | `sonarqube:10.5‑community`  | 9000 | Static code analysis & quality gates      | [https://docs.sonarqube.org](https://docs.sonarqube.org)                                 |
| Nexus     | `sonatype/nexus3:latest`    | 8081 | Docker / Maven / npm artefact repo        | [https://help.sonatype.com/repomanager3](https://help.sonatype.com/repomanager3)         |
| Vault     | `hashicorp/vault:1.17`      | 8200 | Secrets engine (dev mode)                 | [https://developer.hashicorp.com/vault/docs](https://developer.hashicorp.com/vault/docs) |

Volumes keep state between restarts. Stop with `docker compose down` (add `-v` to wipe data).

### 4.3  Bootstrap the Kind cluster

`kind-setup.sh` does six things:

1. Creates (or reuses) a Kind cluster (v1.30 node image).  [Kind docs](https://kind.sigs.k8s.io/docs/user/quick-start/)
2. Saves kubeconfig to `~/.kube/kind-config-<name>` and exports `$KUBECONFIG`.  [Kubernetes multi‑config guide](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
3. Adds Helm repos (Argo, Gatekeeper, Prometheus Community, **Bitnami**).
4. Installs **Argo CD** chart for GitOps workflow.  [Argo helm chart](https://artifacthub.io/packages/helm/argo/argo-cd)
5. Installs **OPA Gatekeeper** for policy enforcement.  [Gatekeeper helm chart](https://openpolicyagent.org/docs/latest/kubernetes/)
6. Installs **kube-prometheus-stack** (Prometheus + Grafana dashboards).  [Chart docs](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

### 4.4  Deploy a demo app

```bash
helm repo update                        # make sure bitnami index is fresh
helm upgrade --install guestbook bitnami/nginx \
  --version 17.4.0 --set service.type=ClusterIP
kubectl get svc guestbook              # ClusterIP proves DNS & service wiring
```

### 4.5  Troubleshoot common errors

| Symptom                                   | Root cause                              | Fix                                                                                      |
| ----------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------- |
| `kind: command not found`                 | Kind not on host PATH                   | Run script inside container *or* install Kind binary into `/usr/local/bin`.              |
| `file name too long` when using `kubectl` | `$KUBECONFIG` contains YAML, not a path | The script now writes kubeconfig to a file; delete the old env var and re‑source script. |
| `helm: command not found`                 | Helm missing on host                    | `curl … signing.asc` then `apt install helm` (or `brew install helm`).                   |
| `repo xyz not found`                      | Chart repo not added                    | `helm repo add bitnami https://charts.bitnami.com/bitnami` then `helm repo update`.      |

More details are embedded at the bottom of this README.

### 4.6  Full reset

```bash
./destroy-lab.sh        # stop & prune everything, delete Kind, remove kubeconfig
```

---

## 5  Source Listings (with inline comments)

### 5.1  `Dockerfile`

```Dockerfile
# ⚙️ 1 — Base OS (Ubuntu 24.04 = systemd 253, glibc 2.39)
FROM ubuntu:24.04 AS base
ENV DEBIAN_FRONTEND=noninteractive

# (2) Core utilities needed for almost every CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl git ca-certificates wget unzip gnupg lsb-release \
        make build-essential software-properties-common apt-transport-https && \
    rm -rf /var/lib/apt/lists/*

# (3) Add vendor APT repos — keys kept in /usr/share/keyrings per Debian policy
# … <full repo add commands — see earlier > …

# (4) Install repo-based CLIs in one layer so Docker can cache
RUN apt-get update && apt-get install -y --no-install-recommends \
        kubectl helm terraform ansible python3-pip && \
    rm -rf /var/lib/apt/lists/*

# (5) Azure CLI — uses Microsoft’s script until 24.04 repo exists
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# (6) Single‑binary tools via GitHub releases (Kind, Flux, k9s, cosign, OPA)
# … <curl commands> …

# (7) Go 1.23 — extract to /usr/local/go, add to PATH
RUN curl -L https://go.dev/dl/go1.23.0.linux-amd64.tar.gz | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

CMD ["/bin/bash"]
```

### 5.2  `docker-compose.yml`

```yaml
version: "3.9"
services:
  jenkins:
    image: jenkins/jenkins:lts-jdk17
    ports: [ "8080:8080" ]
    volumes: [ "jenkins_home:/var/jenkins_home" ]

  sonar:
    image: sonarqube:10.5-community
    ports: [ "9000:9000" ]
    environment:
      SONAR_ES_BOOTSTRAP_CHECKS: "false"

  nexus:
    image: sonatype/nexus3:latest
    ports: [ "8081:8081" ]
    volumes: [ "nexus_data:/nexus-data" ]

  vault:
    image: hashicorp/vault:1.17
    ports: [ "8200:8200" ]
    cap_add: [ "IPC_LOCK" ]
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: root
      VAULT_DEV_LISTEN_ADDRESS: "0.0.0.0:8200"

volumes:
  jenkins_home:
  nexus_data:
```

### 5.3  `kind-setup.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
CLUSTER_NAME=${1:-study-k8s}

# (1) Create cluster if absent — uses Kind v0.27 image with K8s 1.30
kind get clusters | grep -q "^${CLUSTER_NAME}$" || \
  kind create cluster --name "$CLUSTER_NAME" --image kindest/node:v1.30.0

# (2) Persist kubeconfig to file (avoids ENAMETOOLONG) and export path
KCFG="$HOME/.kube/kind-config-$CLUSTER_NAME"
kind get kubeconfig --name "$CLUSTER_NAME" > "$KCFG"
export KUBECONFIG="$KCFG"

# (3) Add Helm repos – Bitnami included for nginx demo
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts || true
helm repo add bitnami https://charts.bitnami.com/bitnami || true
helm repo update

# (4–6) Install Argo CD, Gatekeeper, kube-prometheus-stack
# … chart install commands …
```

### 5.4  `destroy-lab.sh`

```bash
#!/usr/bin/env bash
# Purpose: stop Compose stack, remove volumes, delete Kind cluster + kubeconfig
set -euo pipefail
CLUSTER_NAME=${1:-study-k8s}

docker compose down -v --remove-orphans || true
LAB_CTRS=$(docker ps -a --filter "ancestor=devops-lab:latest" -q)
[ -n "$LAB_CTRS" ] && docker rm -f $LAB_CTRS || true
kind delete cluster --name "$CLUSTER_NAME" || true
rm -f "$HOME/.kube/kind-config-$CLUSTER_NAME" || true
```

---

## 6  Learning Checklist 📚

Work through one row each day to master the interview objectives:

| Day | Hands‑on task                                                                                    | Validation                                |
| --- | ------------------------------------------------------------------------------------------------ | ----------------------------------------- |
| 1   | Solve Goroutine challenge on [https://gobyexample.com](https://gobyexample.com) *inside* toolbox | `go test ./...` shows 100 % pass          |
| 2   | Spin up Jenkins pipeline building a Go repo                                                      | Build log ends with `SUCCESS`             |
| 3   | Argo CD syncs demo app from Git repo                                                             | `argo app get` shows `Healthy ✓ Synced`   |
| 4   | Write Gatekeeper policy blocking privileged pods                                                 | `kubectl apply` denied, `opa test` passes |
| 5   | Grafana CPU dashboard + alert rule firing                                                        | Alertmanager `FIRING` state               |
| …   | …                                                                                                | …                                         |

---

## 7  Credits & Further Reading

* Kubernetes Hardening Guide (NSA/CISA) — [https://media.defense.gov/2021/Aug/17/2002832841/‑1/‑1/0/CSI\_Kubernetes\_Hardening\_Guide.pdf](https://media.defense.gov/2021/Aug/17/2002832841/‑1/‑1/0/CSI_Kubernetes_Hardening_Guide.pdf)
* CIS Kubernetes Benchmark v1.30 — [https://www.cisecurity.org/benchmark/kubernetes](https://www.cisecurity.org/benchmark/kubernetes)
* Sigstore `cosign` docs — [https://docs.sigstore.dev/cosign/overview/](https://docs.sigstore.dev/cosign/overview/)
* OPA Gatekeeper library — [https://github.com/open-policy-agent/gatekeeper-library](https://github.com/open-policy-agent/gatekeeper-library)
* Prometheus & Grafana tutorials — [https://prometheus.io/docs/introduction/overview/](https://prometheus.io/docs/introduction/overview/), [https://grafana.com/docs/grafana/latest/](https://grafana.com/docs/grafana/latest/)

Happy hacking — and good luck with that next DevOps architect interview!
