# Phase 12: Failure Learnings - Context

**Gathered:** 2026-01-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Capture and structure failure context from Claude's output so retries learn from mistakes. Builds on existing learnings.sh infrastructure from Phase 7. Failures are extracted, stored in AGENTS.md, and available to subsequent iterations within the same phase.

</domain>

<decisions>
## Implementation Decisions

### Failure Extraction
- Any non-zero exit code triggers learning extraction
- Use structured markers for reliable parsing (e.g., `FAILURE_REASON: ...` in Claude's output)
- No severity levels — all failures are equal

### Learning Structure
- Detailed fields: Task ID, error message, what was attempted, relevant file paths, last successful state, timestamp
- "What was attempted" field: 2-3 sentences with context and reasoning (paragraph, not one-liner)
- No "suggested alternative" field — keep learnings factual, let retry figure out alternatives

### Prompt Injection
- Failure learnings live inline in AGENTS.md — no special prompt injection needed
- Show all failures from the current phase (not just current task)
- No display limit — trust 256k context window, let Claude filter for relevance

### Retention Policy
- Clear all failure learnings when phase completes successfully
- Delete entirely — no archive, no history file
- Hard cap: 100 failures per phase, oldest dropped first when exceeded

### Claude's Discretion
- Fallback extraction method when structured markers are missing
- Storage format (markdown vs JSON) — whatever integrates best with learnings.sh
- Organization of failure entries within AGENTS.md (chronological, grouped by task, etc.)
- Whether to clear individual task failures immediately on task success vs keeping until phase end

</decisions>

<specifics>
## Specific Ideas

- "256k context window means we don't need to aggressively filter — let Claude see everything and find patterns"
- Phase completion is the natural cleanup boundary — fresh start for each phase

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-failure-learnings*
*Context gathered: 2026-01-20*
