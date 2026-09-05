# setup/terratest/Dockerfile — pinned Go + OpenTofu runner for Terratest labs.
#
# Bump versions in versions.env (reviewable diff); never use `:latest`.
# Image tag in docker-compose.yml must stay in sync with the FROM/ARG pins.
ARG GO_IMAGE=golang:1.27.1-bookworm
FROM ${GO_IMAGE}

ARG TOFU_VERSION=1.10.3
ARG TARGETARCH

RUN set -eux; \
  arch="${TARGETARCH:-amd64}"; \
  case "$arch" in \
    amd64|x86_64) tofu_arch=amd64 ;; \
    arm64|aarch64) tofu_arch=arm64 ;; \
    *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
  esac; \
  tarball="tofu_${TOFU_VERSION}_linux_${tofu_arch}.tar.gz"; \
  base="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}"; \
  curl -fsSL "${base}/${tarball}" -o "/tmp/${tarball}"; \
  curl -fsSL "${base}/tofu_${TOFU_VERSION}_SHA256SUMS" -o /tmp/SHA256SUMS; \
  expected="$(grep -F " ${tarball}" /tmp/SHA256SUMS | awk '{print $1}')"; \
  [ -n "$expected" ] || { echo "missing checksum for ${tarball} in SHA256SUMS" >&2; exit 1; }; \
  actual="$(sha256sum "/tmp/${tarball}" | awk '{print $1}')"; \
  [ "$expected" = "$actual" ] || { echo "checksum mismatch for ${tarball}" >&2; exit 1; }; \
  tar -xzf "/tmp/${tarball}" -C /usr/local/bin tofu; \
  rm -f "/tmp/${tarball}" /tmp/SHA256SUMS; \
  tofu version; \
  go version

WORKDIR /workspace
