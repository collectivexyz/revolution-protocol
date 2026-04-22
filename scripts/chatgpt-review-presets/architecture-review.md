Run an architecture review for this repository.

Focus on the current contract boundaries, workspace package seams, internal APIs, and deployment flow.

Prioritize:

- places where the same concept, state, or invariant is represented multiple ways
- abstractions that increase coupling, widen blast radius, or force changes to ripple across packages
- contracts or scripts that own too many responsibilities instead of composing smaller seams
- upgrade or deployment patterns that make behavior harder to reason about
- opportunities to simplify storage ownership, mint flow, treasury routing, or metadata responsibilities without weakening core protocol invariants
- refactors that would make the system easier to test, extend, and maintain over the next few years

For each recommendation:

- cite the concrete files, symbols, and architectural seam involved
- explain the current complexity cost or maintenance risk
- describe the simpler target shape in concrete terms
- call out the main risk if the refactor is done poorly

Constraints:

- ground recommendations in the code that exists today, not generic best practices
- prefer high-leverage simplifications over style-only cleanups
- keep the review focused on non-Markdown repo changes under code, tests, scripts, or config

Final response contract:

- Return a concise plain-text review with the highest-value architecture recommendations from this pass.
- For each recommendation, cite the concrete files, symbols, and seam involved, explain the maintenance risk, and recommend the smallest safe follow-up.
- Keep the response concise and factual; do not return a long prose review, a patch, or a diff.
- If you find no safe actionable changes, return a short plain-text summary saying so.
