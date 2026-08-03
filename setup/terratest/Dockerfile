# setup/terratest/Dockerfile — pinned Go + OpenTofu runner for Terratest labs.
#
# Bump versions deliberately (reviewable diff); never use `:latest`.
# Image tag in docker-compose.yml must stay in sync with the FROM/ARG pins.
ARG GO_IMAGE=golang:1.23.6-bookworm
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
  curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_${tofu_arch}.tar.gz" \
    | tar -xz -C /usr/local/bin tofu; \
  tofu version; \
  go version

WORKDIR /workspace
