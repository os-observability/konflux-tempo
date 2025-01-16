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
Once the PR is merged and bundle is built, create another PR `Release - update catalog x.y` with the changes from this command:
```
./hack/update-catalog --snapshot <tested_snapshot_by_QE>
```


## Test locally

Images can be found at https://quay.io/organization/redhat-user-workloads (search for `rhosdt-tenant/tempo`).

### Deploy bundle

get latest pullspec from `kubectl get component tempo-bundle-quay -o yaml`, then run:
```bash
kubectl create namespace openshift-tempo-operator
operator-sdk run bundle -n openshift-tempo-operator quay.io/redhat-user-workloads/rhosdt-tenant/tempo/tempo-bundle-quay@sha256:7b3cde3d776981c8de5b394f26e560ecd25fad29f074b7ca7b11d89ebbdfc769
operator-sdk cleanup -n openshift-tempo-operator tempo-product
```

### Extract file based catalog from OpenShift index

```bash
podman cp $(podman create --name tc registry.redhat.io/redhat/redhat-operator-index:v4.17):/configs/tempo-product tempo-product-4.17 && podman rm tc
opm migrate tempo-product-4.17 tempo-product-4.17-migrated
opm alpha convert-template basic --output yaml ./tempo-product-4.17-migrated/tempo-product/catalog.json > catalog/catalog-template.yaml
```
