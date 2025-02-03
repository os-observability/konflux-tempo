FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_8_golang_1.22@sha256:414352c89e06f25f79b4927328504edcdbfe676cd9596b44afff2eb4117c17e0 as builder

WORKDIR /opt/app-root/src
USER root

COPY .git .git
COPY opa-openshift opa-openshift
# this directory is checked by ecosystem-cert-preflight-checks task in Konflux
COPY api/LICENSE /licenses/
WORKDIR /opt/app-root/src/opa-openshift

RUN CGO_ENABLED=1 GOEXPERIMENT=strictfipsruntime go build -mod=mod -tags strictfipsruntime -o opa-openshift -trimpath -ldflags "-s -w"

FROM registry.redhat.io/ubi8/ubi-minimal:latest@sha256:d16d4445b1567f29449fba3b6d2bc37db467dc3067d33e940477e55aecdf6e8e
WORKDIR /

RUN microdnf update -y && rm -rf /var/cache/yum && \
    microdnf install openssl -y && \
    microdnf clean all

RUN mkdir /licenses
COPY opa-openshift/LICENSE /licenses/.
COPY --from=builder /opt/app-root/src/opa-openshift/opa-openshift /usr/bin/opa-openshift

ARG USER_UID=1001
USER ${USER_UID}
ENTRYPOINT ["/usr/bin/opa-openshift"]

LABEL com.redhat.component="tempo-gateway-opa-container" \
      name="rhosdt/tempo-gateway-opa-rhel8" \
      summary="Tempo OPA OpenShift" \
      description="An OPA-compatible API for making OpenShift access review requests" \
      io.k8s.description="An OPA-compatible API for making OpenShift access review requests." \
      io.openshift.tags="tracing" \
      io.k8s.display-name="Tempo OPA"
