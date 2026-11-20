# Dev container for the experimental Workforce Intune path (experimental-workforce/).
# Everything is installed here (no devcontainer "features"), so a plain
# `docker build` gives exactly the same toolbox as VS Code / Codespaces.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Same versions as scripts/ci/install-tools.sh
ARG TF_VERSION=1.13.4
ARG TFLINT_VERSION=0.59.1

RUN apt-get update \
 && export DEBIAN_FRONTEND=noninteractive \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip git openssl jq \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    tmp="$(mktemp -d)"; \
    curl -fsSL -o "$tmp/tf.zip" "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${arch}.zip"; \
    unzip -q "$tmp/tf.zip" -d "$tmp/tf"; install -m 755 "$tmp/tf/terraform" /usr/local/bin/terraform; \
    curl -fsSL -o "$tmp/tflint.zip" "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${arch}.zip"; \
    unzip -q "$tmp/tflint.zip" -d "$tmp/tflint"; install -m 755 "$tmp/tflint/tflint" /usr/local/bin/tflint; \
    rm -rf "$tmp"; \
    terraform version; tflint --version

# Shared provider cache (validate.sh honours TF_PLUGIN_CACHE_DIR)
ENV TF_PLUGIN_CACHE_DIR=/home/vscode/.terraform.d/plugin-cache
RUN mkdir -p "$TF_PLUGIN_CACHE_DIR" && chown -R vscode:vscode /home/vscode/.terraform.d
