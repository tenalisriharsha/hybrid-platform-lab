# Helm Chart — platform-api

A Helm chart deploying `platform-api` to Kubernetes: a `Deployment` (2
replicas by default), a `ClusterIP` `Service`, and a dedicated
`ServiceAccount`.

```
helm/platform-api/
  Chart.yaml
  values.yaml           replicas, image, resources, probe paths, env
  templates/             Deployment, Service, ServiceAccount, _helpers, NOTES
  manifests/             static `helm template` output, committed for
                         inspection without a cluster
  tests/
    run-tests.sh          helm lint + helm template assertions (no cluster)
    cluster-smoke-test.sh installs the chart into whatever cluster your
                         kubeconfig points at, hits the live Service over
                         REST and /actuator/health, then uninstalls
```

## Usage

```bash
# Build and load the image into your cluster's runtime (minikube example):
docker compose build platform-api
minikube image load hybrid-platform-lab-platform-api:latest

helm install hpl helm/platform-api
kubectl port-forward svc/hpl-platform-api 8080:8080
curl localhost:8080/api/v1/summary
```

## Testing

```bash
helm/platform-api/tests/run-tests.sh           # lint + rendering assertions, no cluster needed
helm/platform-api/tests/cluster-smoke-test.sh  # real install against the current kubeconfig context
```

Health probes rely on Spring Boot Actuator's liveness/readiness groups
(`management.endpoint.health.probes.enabled: true` in
`backend/src/main/resources/application.yml`), so the chart's
`startupProbe`/`livenessProbe`/`readinessProbe` reflect the application's
real startup and dependency state, not just "the process is running".
