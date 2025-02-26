FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:rhel_8_golang_1.23@sha256:1190c4484fd57e95660d91d6db16cf14b39d1c3b80e68ce43f2ba01df13c902e as builder

WORKDIR /opt/app-root/src
USER root

COPY .git .git
COPY opa-openshift opa-openshift
# this directory is checked by ecosystem-cert-preflight-checks task in Konflux
COPY api/LICENSE /licenses/
WORKDIR /opt/app-root/src/opa-openshift

RUN CGO_ENABLED=1 GOEXPERIMENT=strictfipsruntime go build -mod=mod -tags strictfipsruntime -o opa-openshift -trimpath -ldflags "-s -w"

FROM registry.redhat.io/ubi8/ubi-minimal:latest@sha256:c38cc770631788157f8ea989df65ff30359c9f8af3246fef244b32caed9d5862
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
