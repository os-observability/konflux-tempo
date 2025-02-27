# konflux-tempo

This repository contains Konflux configuration to build Red Hat OpenShift distributed tracing platform (Tempo).

## Build locally

```bash
docker login brew.registry.redhat.io -u
docker login registry.redhat.io -u

git submodule update --init --recursive

podman build -t docker.io/user/tempo-operator:$(date +%s) -f Dockerfile.operator
```

## Release
### Application
Update all base images (merge renovatebot PRs).

Create a PR `Release - update upstream sources x.y`:
1. Update git submodules with upstream versions.
  **Note:** If you use a forked repository instead of upstream, you must sync the git tags.
  The version information is set dynamically using `git describe --tags` in the Dockerfile, and is crucial for e.g. the upgrade process of the operator.

### Bundle
Wait for renovatebot to create PRs to update the hash in the `bundle-patch/update_bundle.sh` file, and merge all of them.

Create a PR `Release - update bundle version x.y` and update [patch_csv.yaml](./bundle-patch/patch_csv.yaml) by submitting a PR with follow-up changes:
1. `metadata.name` with the current version e.g. `tempo-operator.v1.58.0-1`
1. `metadata.extra_annotations.olm.skipRange` with the version being productized e.g. `'>=0.33.0 <1.58.0-1'`
1. `spec.version` with the current version e.g. `tempo-operator.v1.58.0-1`
1. `spec.replaces` with [the previous shipped version](https://catalog.redhat.com/software/containers/rhosdt/tempo-operator-bundle/642c3e0eacf1b5bdbba7654a) of CSV e.g. `tempo-operator.v1.57.0-1`
1. Update `release`, `version` and `com.redhat.openshift.versions` (minimum OCP version) labels in [bundle dockerfile](./Dockerfile.bundle)
1. Verify diff of upstream and downstream ClusterServiceVersion
   ```bash
   podman build -t tempo-bundle -f Dockerfile.bundle . && podman cp $(podman create tempo-bundle):/manifests/tempo-operator.clusterserviceversion.yaml .
   git diff --no-index tempo-operator/bundle/openshift/manifests/tempo-operator.clusterserviceversion.yaml tempo-operator.clusterserviceversion.yaml
   rm tempo-operator.clusterserviceversion.yaml
   ```

### Catalog
Once the PR is merged and bundle is built, create another PR `Release - update catalog x.y` with:
* Updated [catalog template](./catalog/catalog-template.yaml) with the new bundle (get the bundle pullspec from `kubectl get component tempo-bundle -o yaml`):
   ```bash
   opm alpha render-template basic --output yaml catalog/catalog-template.yaml > catalog/tempo-product/catalog.yaml && \
   opm alpha render-template basic --output yaml --migrate-level bundle-object-to-csv-metadata catalog/catalog-template.yaml > catalog/tempo-product-4.17/catalog.yaml && \
   sed -i 's#quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-bundle#registry.redhat.io/rhosdt/tempo-operator-bundle#g' catalog/tempo-product/catalog.yaml  && \
   sed -i 's#quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-bundle#registry.redhat.io/rhosdt/tempo-operator-bundle#g' catalog/tempo-product-4.17/catalog.yaml  && \
   opm validate catalog/tempo-product && \
   opm validate catalog/tempo-product-4.17
   ```

## Test locally

Images can be found at https://quay.io/organization/redhat-user-workloads (search for `rhosdt-tenant/tempo`).

### Deploy Image Digest Mirror Set

Before using the bundle or catalog method for installing the operator, the ImageDigestMirrorSet needs to be created. The bundle and catalog uses pullspecs from `registry.redhat.io` which are not available before the release. Therefore the images need to be re-mapped.

From https://konflux.pages.redhat.com/docs/users/getting-started/building-olm-products.html#releasing-a-fbc-component

```yaml
kubectl apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: tempo-idms
spec:
  imageDigestMirrors:
  - source: registry.redhat.io/rhosdt/tempo-rhel8-operator
    mirrors:
      - quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-operator
  - source: registry.redhat.io/rhosdt/tempo-rhel8
    mirrors:
      - quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo
  - source: registry.redhat.io/rhosdt/tempo-query-rhel8
    mirrors:
      - quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-query
  - source: registry.redhat.io/rhosdt/tempo-jaeger-query-rhel8
    mirrors:
      - quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-jaeger-query
  - source: registry.redhat.io/rhosdt/tempo-gateway-rhel8
    mirrors:
      - quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-gateway
  - source: registry.redhat.io/rhosdt/tempo-gateway-opa-rhel8
    mirrors:
      - quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-opa
  - source: registry.redhat.io/rhosdt/tempo-operator-bundle
    mirrors:
      - quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-bundle
EOF
```

### Deploy bundle

get latest pullspec from `kubectl get component tempo-bundle-main -o yaml`, then run:
```bash
kubectl create namespace openshift-tempo-operator
operator-sdk run bundle -n openshift-tempo-operator quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-bundle-main@sha256:7b3cde3d776981c8de5b394f26e560ecd25fad29f074b7ca7b11d89ebbdfc769
operator-sdk cleanup -n openshift-tempo-operator tempo-product
```
### Deploy catalog

Get catalog for specific version from [Konflux](https://console.redhat.com/application-pipeline/workspaces/rhosdt/applications/tempo-fbc-v4-15-main/components/tempo-fbc-v4-15-main)

```yaml
kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
   name: konflux-catalog-tempo
   namespace: openshift-marketplace
spec:
   sourceType: grpc
   image: 
Latest image
quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-fbc-v4-15:d64cfe50d37c2ceece690d283806f8170f27a4d0
   displayName: Konflux Catalog Tempo
   publisher: grpc
EOF

kubectl get pods -w -n openshift-marketplace
kubectl delete CatalogSource konflux-catalog-tempo -n openshift-marketplace
```

`Konflux catalog Tempo` menu should appear in the OCP console under Operators->OperatorHub.

### Extract file based catalog from OpenShift index

```bash
podman cp $(podman create --name tc registry.redhat.io/redhat/redhat-operator-index:v4.17):/configs/tempo-product tempo-product-4.17 && podman rm tc
opm migrate tempo-product-4.17 tempo-product-4.17-migrated
opm alpha convert-template basic --output yaml ./tempo-product-4.17-migrated/tempo-product/catalog.json > catalog/catalog-template.yaml
```
