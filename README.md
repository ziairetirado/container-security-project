# Container Security

A hands-on project covering the container security lifecycle: understanding
what a container actually is, building a hardened image, scanning it for
known vulnerabilities, and locking down how it runs in Kubernetes.

## Architecture

<img width="1408" height="768" alt="Aws Container Security Architecture" src="https://github.com/user-attachments/assets/c5a52c7c-d4bb-4195-ae36-eb5a3e7d28be" />



## 1. Containers & Docker basics

A container is **not** a lightweight VM — it's a normal Linux process that
the kernel isolates using namespaces (its own view of PIDs, network, mount
points, hostname) and cgroups (CPU/memory limits). An **image** is a
read-only, layered filesystem snapshot (each `RUN`/`COPY` in a Dockerfile
adds a layer); a **container** is a running instance of that image with a
writable layer on top.

`docker/Dockerfile` demonstrates the core build concepts:

- **Multi-stage build** — dependencies are installed in a throwaway
  `builder` stage; only the compiled artifacts are copied into the final
  image, keeping it small and reducing attack surface.
- **Minimal base image** (`python:3.12-slim`) instead of a full OS image.
- **Non-root user** — the app never runs as root inside the container.
- **HEALTHCHECK** so the container runtime can detect an unhealthy app.

Build it locally:

```bash
docker build -t demo-app:local ./docker
docker run -p 8080:8080 demo-app:local
```

## 2. Scanning images with Trivy

Vulnerabilities live in the OS packages and language dependencies baked
into an image, not just in your own code. [Trivy](https://github.com/aquasecurity/trivy)
scans an image's layers against known-CVE databases (OS packages, Python/Node/Go
dependencies, misconfigurations, and secrets).

`scripts/build_and_scan.sh` builds the image and fails the build if any
**HIGH or CRITICAL** vulnerability with an available fix is found:

```bash
./scripts/build_and_scan.sh
```

`.github/workflows/trivy-scan.yml` wires this into CI: every push/PR that
touches `docker/**` builds the image, scans it, uploads results as SARIF to
GitHub's Security tab, and blocks the merge on HIGH/CRITICAL findings.

## 3. Kubernetes security

Once the image is clean, `kubernetes/` shows how it should actually be run:

| File | What it enforces |
|---|---|
| `pod-security-context.yaml` | Runs as non-root UID, read-only root filesystem, `allowPrivilegeEscalation: false`, drops **all** Linux capabilities, sets CPU/memory limits |
| `serviceaccount.yaml` | Dedicated identity for the app instead of using `default` |
| `rbac-role.yaml` / `rbac-rolebinding.yaml` | **RBAC** — the app's ServiceAccount can only `get/list/watch` pods and configmaps in its own namespace; no cluster-wide access, no write verbs |
| `network-policy-deny-all.yaml` | **Default-deny** baseline — by default Kubernetes allows all pod-to-pod traffic; this closes that off |
| `network-policy-allow-app.yaml` | A narrow exception: only frontend-labeled pods can reach the app on port 8080, and the app can only reach the database pods on 5432 and DNS on 53 |

### Port security

Containers should only `EXPOSE`/listen on the ports they actually need
(here, just 8080). Combined with a default-deny `NetworkPolicy`, this means
even if an attacker gets code execution in the pod, they can't reach
anything else in the cluster except what's explicitly allow-listed.

## Why this matters

This mirrors a real supply-chain-to-runtime security flow: **build small →
scan before you ship → run with least privilege**. Each layer (image
hygiene, vulnerability scanning, RBAC, network segmentation) is independent
defense-in-depth — a miss in one doesn't automatically compromise the
others.
