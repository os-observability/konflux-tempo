FROM registry.redhat.io/ubi9/ubi:latest@sha256:8942b73866f8434571d6fc4c10cbebd48982995d2249c39302e4d71e7df3afd9 as builder

WORKDIR /opt/app-root/src
USER root

RUN dnf install --nodocs -y golang && \
    dnf clean all && \
    rm -rf /var/cache/yum

COPY .git .git
COPY opa-openshift opa-openshift
# this directory is checked by ecosystem-cert-preflight-checks task in Konflux
COPY api/LICENSE /licenses/
WORKDIR /opt/app-root/src/opa-openshift

RUN CGO_ENABLED=1 GOEXPERIMENT=strictfipsruntime go build -mod=mod -tags strictfipsruntime -o opa-openshift -trimpath -ldflags "-s -w"

FROM registry.redhat.io/ubi9/ubi-micro:latest@sha256:b498b3ea26111ab4b81d65139f2ebd2ef9a2abb7a4588b7fdcc54889f95e9caa AS target-base

FROM registry.redhat.io/ubi9/ubi:latest@sha256:8942b73866f8434571d6fc4c10cbebd48982995d2249c39302e4d71e7df3afd9 as install-additional-packages
COPY --from=target-base / /mnt/rootfs
RUN rpm --root /mnt/rootfs --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

RUN dnf install --installroot /mnt/rootfs --releasever 9 --setopt install_weak_deps=false --setopt reposdir=/etc/yum.repos.d --nodocs -y openssl systemd && \
    dnf clean all && \
    rm -rf /var/cache/yum
RUN rm -rf /mnt/rootfs/var/cache/*

FROM scratch
WORKDIR /
COPY --from=install-additional-packages /mnt/rootfs/ /

ARG VERSION=0.20.0-3

RUN mkdir /licenses
COPY opa-openshift/LICENSE /licenses/.
COPY --from=builder /opt/app-root/src/opa-openshift/opa-openshift /usr/bin/opa-openshift

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
      io.k8s.description="An OPA-compatible API for making OpenShift access review requests." \
      io.openshift.tags="tracing" \
      io.k8s.display-name="Tempo OPA" \
      cpe="cpe:/a:redhat:openshift_distributed_tracing:3.10::el9"
