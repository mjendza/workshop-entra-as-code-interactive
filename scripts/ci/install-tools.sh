#!/usr/bin/env bash
# Installs terraform + tflint into ~/.local/bin (Linux/WSL, no sudo).
set -euo pipefail
BIN="$HOME/.local/bin"; mkdir -p "$BIN"
TF_VERSION="${TF_VERSION:-1.13.4}"
TFLINT_VERSION="${TFLINT_VERSION:-0.59.1}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

if ! command -v terraform >/dev/null; then
  curl -fsSL -o "$tmp/tf.zip" "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
  python3 -m zipfile -e "$tmp/tf.zip" "$tmp/tf" && install -m 755 "$tmp/tf/terraform" "$BIN/"
fi
if ! command -v tflint >/dev/null; then
  curl -fsSL -o "$tmp/tflint.zip" "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip"
  python3 -m zipfile -e "$tmp/tflint.zip" "$tmp/tflint" && install -m 755 "$tmp/tflint/tflint" "$BIN/"
fi
case ":$PATH:" in *":$BIN:"*) ;; *) echo "Add to PATH: export PATH=\"$BIN:\$PATH\"";; esac
"$BIN/terraform" version | head -1 || terraform version | head -1
"$BIN/tflint" --version | head -1 || tflint --version | head -1
