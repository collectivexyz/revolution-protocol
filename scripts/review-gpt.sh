#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="$ROOT_DIR/scripts/review-gpt.config.sh"
LOCAL_REVIEW_GPT_ROOT="$ROOT_DIR/../review-gpt"
LOCAL_REVIEW_GPT_PACKAGE_JSON="$LOCAL_REVIEW_GPT_ROOT/package.json"
LOCAL_REVIEW_GPT_BIN="$LOCAL_REVIEW_GPT_ROOT/dist/bin.mjs"
LOCAL_INSTALLED_REVIEW_GPT_BIN="$ROOT_DIR/node_modules/@cobuild/review-gpt/dist/bin.mjs"

resolve_review_gpt_node() {
  local candidates=()
  local candidate=""
  local resolved=""

  if [[ -n "${REVIEW_GPT_NODE_PATH:-}" ]]; then
    candidates+=("$REVIEW_GPT_NODE_PATH")
  fi
  if [[ -n "${NODE_BINARY_PATH:-}" ]]; then
    candidates+=("$NODE_BINARY_PATH")
  fi
  candidates+=("node" "/opt/homebrew/bin/node" "/usr/local/bin/node")

  for candidate in "${candidates[@]}"; do
    if [[ "$candidate" == */* ]]; then
      if [[ ! -x "$candidate" ]]; then
        continue
      fi
      resolved="$candidate"
    else
      resolved="$(command -v "$candidate" 2>/dev/null || true)"
      if [[ -z "$resolved" ]]; then
        continue
      fi
    fi

    if "$resolved" -e 'process.exit(typeof WebSocket === "function" ? 0 : 1)' >/dev/null 2>&1; then
      printf '%s\n' "$resolved"
      return 0
    fi
  done

  echo "Error: review:gpt requires a Node.js runtime with global WebSocket support. Set REVIEW_GPT_NODE_PATH to a compatible node binary." >&2
  exit 1
}

NODE_BIN="$(resolve_review_gpt_node)"

if [[ -f "$LOCAL_REVIEW_GPT_PACKAGE_JSON" ]]; then
  if [[ ! -f "$LOCAL_REVIEW_GPT_BIN" ]]; then
    echo "Error: local ../review-gpt checkout found but dist/bin.mjs is missing. Run 'pnpm --dir ../review-gpt build' first." >&2
    exit 1
  fi
  REVIEW_GPT_BIN="$LOCAL_REVIEW_GPT_BIN"
elif [[ -f "$LOCAL_INSTALLED_REVIEW_GPT_BIN" ]]; then
  REVIEW_GPT_BIN="$LOCAL_INSTALLED_REVIEW_GPT_BIN"
else
  echo "Error: missing @cobuild/review-gpt runtime. Run 'pnpm install' first." >&2
  exit 1
fi

declare -a REVIEW_GPT_ARGS=()
if [[ $# -gt 0 && "$1" == "--" ]]; then
  shift
fi
if [[ $# -gt 0 && "$1" == "thread" ]]; then
  REVIEW_GPT_ARGS=("$@")
elif [[ $# -gt 0 && "$1" == "delay" ]]; then
  shift
  REVIEW_GPT_ARGS=(delay --config "$CONFIG_PATH" "$@")
else
  REVIEW_GPT_ARGS=(--config "$CONFIG_PATH" "$@")
fi

exec "$NODE_BIN" "$REVIEW_GPT_BIN" "${REVIEW_GPT_ARGS[@]}"
