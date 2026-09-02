FROM registry.redhat.io/ubi9/ubi:latest@sha256:25a147defd01e19674714f55d17538c8dbe55d8c305fa157ecc3f9c8977b05b6 AS builder

WORKDIR /opt/app-root/src
USER root

RUN dnf install --nodocs -y golang && \
    dnf clean all && \
    rm -rf /var/cache/yum

COPY .git .git
COPY opa-openshift opa-openshift
# this directory is checked by ecosystem-cert-preflight-checks task in Konflux
COPY opa-openshift/LICENSE /licenses/
WORKDIR /opt/app-root/src/opa-openshift

RUN CGO_ENABLED=0 GOFIPS140=certified go build -mod=mod -tags no_openssl -o opa-openshift -trimpath -ldflags "-s -w"

FROM registry.redhat.io/ubi9/ubi-micro:latest@sha256:f332c99eb8f798a8486821c91937f10ad64ee83d7e739303be2df051040918f6
ARG VERSION=0.22.0-1

RUN mkdir /licenses
COPY opa-openshift/LICENSE /licenses/.
COPY --from=builder /opt/app-root/src/opa-openshift/opa-openshift /usr/bin/opa-openshift

ENV GODEBUG=fips140=auto
ARG USER_UID=1001
USER ${USER_UID}
ENTRYPOINT ["/usr/bin/opa-openshift"]

LABEL release="${VERSION}" \
      version="${VERSION}" \
      vendor="Red Hat, Inc." \
      distribution-scope="public" \
      url="https://github.com/grafana/tempo-operator" \
      com.redhat.component="tempo-gateway-opa-container" \
      name="rhosdt/tempo-gateway-opa-rhel9" \
      summary="Tempo OPA OpenShift" \
      description="An OPA-compatible API for making OpenShift access review requests" \
      maintainer="Red Hat <support@redhat.com>" \
      io.k8s.description="An OPA-compatible API for making OpenShift access review requests." \
      io.openshift.tags="tracing" \
      io.k8s.display-name="Tempo OPA" \
      cpe="cpe:/a:redhat:openshift_distributed_tracing:3.11::el9"
