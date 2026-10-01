#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"

printf 'Enter the Groq key for the local Worcon backend (input stays hidden): '
read -rs GROQ_API_KEY
printf '\n'
if [[ -z "$GROQ_API_KEY" ]]; then
  print -u2 'No key entered.'
  exit 1
fi
export GROQ_API_KEY
NODE_BIN="${WORCON_NODE_BIN:-$(command -v node || true)}"
if [[ -z "$NODE_BIN" ]]; then
  NODE_BIN="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
fi
if [[ ! -x "$NODE_BIN" ]]; then
  print -u2 "Node.js executable not found at: $NODE_BIN"
  exit 1
fi
exec "$NODE_BIN" server.mjs
