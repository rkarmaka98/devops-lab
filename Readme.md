# DevOps Lab

> An all‑in‑one, laptop‑friendly playground that lets you practise **Go**, **Kubernetes**, **GitOps**, **Jenkins**, **Azure**, and **DevSecOps**. Every file is annotated and every external tool is referenced so a first‑time user can spin it up, break it, and rebuild it with confidence.

---

## 🖼 Lab Topology 
```
┌───────────────────┐
│  Host machine     │
│  (Docker Desktop) │
└────────┬──────────┘
         │-- docker / nerdctl
├────────┴──────────┤
│  devops-lab        │  ← one multi-purpose image (Go, kubectl, Terraform…)
│  (interactive)     │
├────────────────────┤
│  docker-compose stack          (runs alongside devops-lab)
│  ├─ jenkins.lts     :8080
│  ├─ sonar           :9000
│  ├─ nexus           :8081
│  └─ vault-server    :8200
├────────────────────┤
│  kind “study-k8s” cluster (node containers)          │
│  ├─ argo-cd (in-cluster) │
│  ├─ flux (optional)       │
│  ├─ gatekeeper (OPA)      │
│  ├─ kube-prometheus-stack │
│  └─ demo apps / Helm labs │
└───────────────────────────┘
```

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
└── README.md               
```


---

## 3  Quick‑Start (5 commands)

```bash
# 1. Clone repo & build toolbox image
git clone https://github.com/your‑git‑handle/devops‑lab.git && cd devops‑lab
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

## 5  Credits & Further Reading

* Kubernetes Hardening Guide (NSA/CISA) — [https://media.defense.gov/2021/Aug/17/2002832841/‑1/‑1/0/CSI\_Kubernetes\_Hardening\_Guide.pdf](https://media.defense.gov/2021/Aug/17/2002832841/‑1/‑1/0/CSI_Kubernetes_Hardening_Guide.pdf)
* CIS Kubernetes Benchmark v1.30 — [https://www.cisecurity.org/benchmark/kubernetes](https://www.cisecurity.org/benchmark/kubernetes)
* Sigstore `cosign` docs — [https://docs.sigstore.dev/cosign/overview/](https://docs.sigstore.dev/cosign/overview/)
* OPA Gatekeeper library — [https://github.com/open-policy-agent/gatekeeper-library](https://github.com/open-policy-agent/gatekeeper-library)
* Prometheus & Grafana tutorials — [https://prometheus.io/docs/introduction/overview/](https://prometheus.io/docs/introduction/overview/), [https://grafana.com/docs/grafana/latest/](https://grafana.com/docs/grafana/latest/)

Happy hacking!
