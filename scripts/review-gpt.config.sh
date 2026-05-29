#!/usr/bin/env bash

name_prefix="revolution-protocol-chatgpt-audit"
include_tests=0
include_docs=0
preset_dir="scripts/chatgpt-review-presets"
package_script="scripts/package-audit-context.sh"

review_gpt_register_dir_preset "security" "security-audit.md" \
  "Security and invariant review for contracts, roles, value flow, and upgrade surfaces." \
  "security-audit" \
  "audit-security"
review_gpt_register_dir_preset "architecture" "architecture-review.md" \
  "Architecture review focused on contract boundaries, protocol seams, and long-term maintainability." \
  "architecture-review" \
  "design-review"
review_gpt_register_dir_preset "simplify" "complexity-simplification.md" \
  "Behavior-preserving simplification pass for this repo." \
  "complexity" \
  "complexity-simplification"
review_gpt_register_dir_preset "bug-hunt" "bug-hunt-high-value-seams.md" \
  "Bug-finding review focused on high-value invariants, edge cases, and failure modes." \
  "bugs" \
  "failure-modes"
