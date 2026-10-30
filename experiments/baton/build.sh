#!/usr/bin/env bash
# Build the host for x86_64 Linux (musl) and place it where platform/main.roc expects it.
set -euo pipefail
cd "$(dirname "$0")"
cargo build --release --lib --target x86_64-unknown-linux-musl
cp target/x86_64-unknown-linux-musl/release/libhost.a platform/targets/x64musl/
