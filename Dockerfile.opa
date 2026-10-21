FROM registry.redhat.io/ubi9/ubi:latest@sha256:16e9e43d99e181463513cc84a514859b1abb9460f1c4d9e208da4b4e51cd5cc3 AS builder
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

FROM registry.redhat.io/ubi9/ubi-micro:latest@sha256:5be877a2a280ae36eb9ab80ca4efb28bbf77c57abbba38137cdc37a03b8465e6 AS ubi-micro-base
FROM registry.redhat.io/ubi9/ubi:latest@sha256:16e9e43d99e181463513cc84a514859b1abb9460f1c4d9e208da4b4e51cd5cc3 AS image-builder
COPY --from=ubi-micro-base / /mnt/rootfs

RUN rpm --root /mnt/rootfs --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release && \
    dnf install -y \
      --installroot /mnt/rootfs \
      --releasever 9 \
      --setopt install_weak_deps=false \
      --setopt reposdir=/etc/yum.repos.d \
      --nodocs \
      ca-certificates && \
    dnf clean all --installroot /mnt/rootfs && \
    rm -rf /mnt/rootfs/var/cache/*

FROM scratch
WORKDIR /
COPY --from=image-builder /mnt/rootfs/ /
COPY opa-openshift/LICENSE /licenses/
COPY --from=builder /opt/app-root/src/opa-openshift/opa-openshift /usr/bin/opa-openshift

ENV GODEBUG=fips140=auto
ARG USER_UID=1001
USER ${USER_UID}
ENTRYPOINT ["/usr/bin/opa-openshift"]

ARG VERSION=0.22.0-4
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
