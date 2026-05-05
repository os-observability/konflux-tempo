#!/usr/bin/env python3
"""Static OLMv1 compliance validation for an extracted operator bundle.

Background — what is OLMv1?
---------------------------
OLMv1 (Operator Lifecycle Manager v1) is the next-generation operator
install/management framework on OpenShift, GA on OCP 4.21+. It replaces
OLMv0's Subscription / InstallPlan / CSV-driven install flow with a
ClusterExtension-based model. Bundles still ship in the same OCI format
(manifests/ + metadata/) but must additionally satisfy OLMv1's stricter
install constraints in order to install successfully under OLMv1.

Authoritative references for everything below:

  [1] OKD — Supported extensions (OLMv1):
      https://docs.okd.io/latest/extensions/ce/olmv1-supported-extensions.html
  [2] Red Hat OpenShift 4.21 — Extensions (mirrored content of [1]):
      https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html-single/extensions/index
  [3] operator-controller upstream — OLMv1 limitations:
      https://operator-framework.github.io/operator-controller/project/olmv1_limitations/

What this script validates (and why)
------------------------------------
Hard failures (block the pipeline):

  1. AllNamespaces install mode is supported in the CSV.
     Why: OLMv1 only honors AllNamespaces today; per [3], a bundle
     "must support installation via the AllNamespaces install mode".
     SingleNamespace / OwnNamespace are accepted by OLMv1 for OLMv0
     backwards compatibility but "are not recommended" [3], and per [1]
     watching a specific namespace is Tech Preview only. A CSV without
     AllNamespaces=true is therefore unsafe to ship under OLMv1.
     Refs: [1], [3].

  2. metadata/dependencies.yaml does not declare olm.package, olm.gvk,
     or olm.constraint runtime dependencies.
     Why: OLMv1 does not implement OLM-style dependency resolution. Per
     [3], a bundle "must not declare dependencies using any of the
     following file-based catalog properties: olm.gvk.required,
     olm.package.required, olm.constraint". The same constraint applies
     to the equivalent runtime-dependency entries in
     metadata/dependencies.yaml — OLMv1 will not satisfy them either.
     Refs: [1], [3].

Advisory warning (does not fail the pipeline):

  - Deployment containers should not read OPERATOR_CONDITIONS_NAME.
    Why: OLMv1 does not implement the OperatorConditions API. Per [1]
    and [3], "OLM v1 does not support the OperatorConditions API".
    OLMv1 therefore does not inject OPERATOR_CONDITIONS_NAME into the
    operator's pod env. Operators that branch on this var will silently
    degrade. Warning only — not all operators that read this var
    actually require it to be set.
    Refs: [1], [3].

What this script intentionally does NOT check
---------------------------------------------
ConversionWebhook in the CSV: per [1], "OLM v1 supports Operators that
use webhooks for validation, mutation, or conversion." Conversion
webhooks are explicitly supported on OCP 4.21+, so we do not block on
them. (Earlier OLMv1 tech-preview releases did not support conversion
webhooks; that restriction was lifted at GA.)

Why this script exists (and not a Konflux task)
-----------------------------------------------
There is no Konflux catalog task for OLMv1 static bundle validation
today. This in-tree script fills the gap. If/when an upstream task is
published (e.g., in konflux-ci/build-definitions), the pipeline step in
.tekton/single-arch-build-pipeline.yaml should be replaced with a
`taskRef` to that canonical task and these scripts removed.

Inputs
------
Reads EXTRACT_DIR from env — the path where the bundle image's gzip
layers have already been extracted (done by the .sh wrapper). Expects
to find manifests/*.clusterserviceversion.yaml and, optionally,
metadata/dependencies.yaml under that root.

Exit code: 0 if compliant (warnings allowed), non-zero otherwise.
"""
import glob
import os
import sys
import yaml

extract_dir = os.environ["EXTRACT_DIR"]

csv_matches = glob.glob(
    f"{extract_dir}/**/manifests/*.clusterserviceversion.yaml",
    recursive=True,
)
if not csv_matches:
    print("FAIL: no ClusterServiceVersion found under manifests/ in bundle image")
    sys.exit(1)
csv_path = csv_matches[0]
print(f"Found CSV: {csv_path}")

with open(csv_path) as f:
    csv = yaml.safe_load(f)

errors = []
warnings = []

# Check 1: AllNamespaces install mode must be supported by the CSV.
# OLMv1 currently only honors AllNamespaces; SingleNamespace / OwnNamespace
# exist for OLMv0 backwards compatibility but are not recommended, and
# watching a specific namespace under OLMv1 is Tech Preview only.
# Refs:
#   https://docs.okd.io/latest/extensions/ce/olmv1-supported-extensions.html
#   https://operator-framework.github.io/operator-controller/project/olmv1_limitations/
install_modes = (csv.get("spec") or {}).get("installModes") or []
all_ns = next((m for m in install_modes if m.get("type") == "AllNamespaces"), None)
if not all_ns or not all_ns.get("supported", False):
    errors.append(
        "CSV does not support AllNamespaces install mode "
        "(required by OLMv1 — see "
        "https://operator-framework.github.io/operator-controller/project/olmv1_limitations/)."
    )

# Check 2: No OLMv0-only runtime dependencies in metadata/dependencies.yaml.
# OLMv1 does not implement OLM-style dependency resolution, so
# olm.package / olm.gvk / olm.constraint entries are never satisfied.
# Refs:
#   https://operator-framework.github.io/operator-controller/project/olmv1_limitations/
#   https://docs.okd.io/latest/extensions/ce/olmv1-supported-extensions.html
deps_files = glob.glob(
    f"{extract_dir}/**/metadata/dependencies.yaml",
    recursive=True,
)
blocked_dep_types = {"olm.package", "olm.gvk", "olm.constraint"}
for dep_path in deps_files:
    with open(dep_path) as f:
        deps = yaml.safe_load(f) or {}
    for dep in deps.get("dependencies") or []:
        t = dep.get("type", "")
        if t in blocked_dep_types:
            errors.append(
                f"metadata/dependencies.yaml declares OLMv0 runtime dependency "
                f"type='{t}' (not supported by OLMv1 — see "
                f"https://operator-framework.github.io/operator-controller/project/olmv1_limitations/)."
            )

# Advisory check: OPERATOR_CONDITIONS_NAME in deployment env.
# OLMv1 does not implement the OperatorConditions API and does not inject
# OPERATOR_CONDITIONS_NAME into the operator's pod env. Operators that
# branch on this var may silently degrade. Warning only — many operators
# read it defensively but do not actually require it.
# Refs:
#   https://docs.okd.io/latest/extensions/ce/olmv1-supported-extensions.html
#   https://operator-framework.github.io/operator-controller/project/olmv1_limitations/
deployments = (
    ((csv.get("spec") or {}).get("install") or {})
    .get("spec", {})
    .get("deployments", [])
    or []
)
for d in deployments:
    containers = (
        (d.get("spec") or {})
        .get("template", {})
        .get("spec", {})
        .get("containers", [])
        or []
    )
    for c in containers:
        for env in c.get("env") or []:
            if env.get("name") == "OPERATOR_CONDITIONS_NAME":
                warnings.append(
                    f"deployment '{d.get('name')}' container '{c.get('name')}' "
                    f"reads OPERATOR_CONDITIONS_NAME; OLMv1 does not set this env var."
                )

if warnings:
    print("OLMv1 advisory warnings:")
    for w in warnings:
        print(f"  WARN: {w}")

if errors:
    print("OLMv1 compliance check FAILED:")
    for e in errors:
        print(f"  FAIL: {e}")
    sys.exit(1)

print("OLMv1 compliance check PASSED")
