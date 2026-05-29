#!/usr/bin/env bash
set -euo pipefail

COBUILD_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

consumer_shell_path=""
for candidate in \
  "$COBUILD_REPO_ROOT/node_modules/@cobuild/repo-tools/src/consumer-shell.sh" \
  "$COBUILD_REPO_ROOT/../repo-tools/src/consumer-shell.sh"
do
  if [ -f "$candidate" ]; then
    consumer_shell_path="$candidate"
    break
  fi
done

if [ -z "$consumer_shell_path" ]; then
  echo "Error: missing repo-tools consumer shell helper. Install dependencies first." >&2
  exit 1
fi

source "$consumer_shell_path"

export COBUILD_AUDIT_CONTEXT_PREFIX='revolution-protocol-audit'
export COBUILD_AUDIT_CONTEXT_TITLE='Revolution Protocol Audit Bundle'
export COBUILD_AUDIT_CONTEXT_REPO_LABEL='revolution-protocol'
export COBUILD_AUDIT_CONTEXT_INCLUDE_TESTS_DEFAULT='0'
export COBUILD_AUDIT_CONTEXT_INCLUDE_DOCS_DEFAULT='0'
export COBUILD_AUDIT_CONTEXT_INCLUDE_CI_DEFAULT='0'

audit_context_binary_exclude_globs=(
  "readme-img/**"
)
repo_tools_join_lines COBUILD_AUDIT_CONTEXT_BINARY_EXCLUDE_GLOBS \
  "${audit_context_binary_exclude_globs[@]}"
repo_tools_join_lines COBUILD_AUDIT_CONTEXT_EXCLUDE_GLOBS \
  "${audit_context_binary_exclude_globs[@]}" \
  "lib/**" \
  "gas-reports/**"
repo_tools_join_lines COBUILD_AUDIT_CONTEXT_ALWAYS_PATHS \
  ".gitignore" \
  ".gitmodules" \
  ".nvmrc" \
  ".prettierrc" \
  ".solhint.json" \
  "DEVELOPING.md" \
  "LICENSE" \
  "README.md" \
  "compiler_config.json" \
  "funding.json" \
  "package.json" \
  "pnpm-workspace.yaml" \
  "slither.config.json" \
  "turbo.json"
repo_tools_join_lines COBUILD_AUDIT_CONTEXT_SCAN_SPECS \
  "packages" \
  "script"
repo_tools_join_lines COBUILD_AUDIT_CONTEXT_TEST_SCAN_SPECS \
  "packages"
repo_tools_join_lines COBUILD_AUDIT_CONTEXT_DOC_SCAN_SPECS \
  "audits:*.md"
repo_tools_join_lines COBUILD_AUDIT_CONTEXT_CI_SCAN_SPECS \
  ".github/workflows"
repo_tools_join_lines COBUILD_AUDIT_CONTEXT_PRUNE_DIR_NAMES \
  "node_modules" \
  ".git" \
  ".turbo" \
  "dist" \
  "out" \
  "cache" \
  "coverage" \
  "audit-packages" \
  "output-packages"
