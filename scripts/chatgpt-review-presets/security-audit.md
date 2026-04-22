Run a security audit for this repository.

Prioritize:

- authorization, role, ownership, and upgrade-control surfaces
- value flow, payout accounting, escrow assumptions, and fund custody
- storage layout risks, initialization gaps, and upgrade safety
- griefing, denial-of-service, frontrunning, replay, and stale-state edge cases
- external call boundaries across contracts, scripts, and deployment wiring
- configuration mistakes that could break minting, governance, treasury routing, or metadata behavior

Prefer concrete, repo-specific issues over generic best practices.

Final response contract:

- Return a concise plain-text review with the highest-value security issues from this pass.
- For each item, cite the concrete files or seams involved, explain the risk, and recommend the smallest safe follow-up.
- Keep the response concise and factual; do not return a long prose review, a patch, or a diff.
- If you find no safe actionable changes, return a short plain-text summary saying so.
