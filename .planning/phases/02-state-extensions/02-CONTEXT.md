# Phase 2: State Extensions - Context

**Gathered:** 2026-01-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend STATE.md to track iteration state and show progress across autonomous execution. Fresh Claude instances read this to know where to resume. This phase does NOT implement the outer loop itself (Phase 3) — it creates the schema and update logic that the outer loop will use.

</domain>

<decisions>
## Implementation Decisions

### Iteration Tracking
- Record outcome + task name per iteration (not just pass/fail, not full error details)
- Include full timestamps (e.g., 2026-01-19 14:32:05)
- Claude's discretion on how to display consecutive failures (collapsed vs separate entries)
- Claude's discretion on categorizing failure types (task failure vs system error)

### Progress Display
- Use ASCII text bar style: `[████░░░░░░] 40%`
- Percentage represents plans completed (e.g., 15 of 26 plans = 57%)
- Update progress only after git commit succeeds (not immediately on completion)
- Claude's discretion on placement within STATE.md

### History Depth
- Rolling window: keep last 10-15 iterations in STATE.md
- Archive older entries to `.planning/iteration-history.md` at phase boundaries
- Git preserves full history; STATE.md is working memory only
- AGENTS.md (Phase 7) will extract patterns before entries roll off

### Resume Clarity
- Show BOTH current position AND next action at the top
- Next action format: both command-ready AND descriptive
  - Example: `/gsd:execute-phase 2` — Execute plan 02-01 (Budget config)
- Include explicit file list for context
  - Example: "Read: ROADMAP.md, 02-01-PLAN.md"
- Claude's discretion on highlighting last failure when resuming after failed iteration

### Claude's Discretion
- Exact placement of progress bar in STATE.md
- How consecutive failures display (collapsed with count vs separate entries)
- Whether to categorize failure types
- How to highlight last failure for recovery context

</decisions>

<specifics>
## Specific Ideas

- Rolling window chosen to keep fresh instances fast (not bloated with 100+ iterations)
- Archive file ensures nothing is lost even before AGENTS.md pattern extraction exists
- Command-ready next action means the outer loop could theoretically just paste and run

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-state-extensions*
*Context gathered: 2026-01-19*
