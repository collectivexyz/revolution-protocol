Run a bug-finding review for this repository.

Prioritize:

- mint lifecycle invariants and supply accounting
- auction, sale, payout, or claim state transitions
- initialization, upgrade, and pause-path edge cases
- rounding, bounds, overflow, underflow, and timing assumptions
- deployment-script drift versus on-chain expectations
- test gaps around the highest-value failure modes

Prefer issues that could lead to broken minting, incorrect payouts, locked funds, bad metadata state, or governance/operator surprises.

Final response contract:

- Return a concise plain-text review with the highest-value bugs or missing tests from this pass.
- For each item, cite the concrete files or seams involved, explain the failure mode, and recommend the smallest safe follow-up.
- Keep the response concise and factual; do not return a long prose review, a patch, or a diff.
- If you find no safe actionable changes, return a short plain-text summary saying so.
