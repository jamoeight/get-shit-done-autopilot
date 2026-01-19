# Phase 7: Learnings Propagation - Context

**Gathered:** 2026-01-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Share patterns discovered during autonomous execution via AGENTS.md. Learnings accumulate across iterations and are consumed by future iterations to improve execution quality. System manages curation automatically.

</domain>

<decisions>
## Implementation Decisions

### Learning capture
- Capture both error fixes ("When X happens, do Y") and codebase patterns ("This project uses X")
- Learnings are project-specific only — stored in .planning/AGENTS.md
- Claude's Discretion: Trigger mechanism (after recovery, after success, after stuck resolution)
- Claude's Discretion: Whether executing agent or outer loop extracts learnings

### AGENTS.md structure
- Mixed format: If-then rules for error fixes, notes style for discovered patterns
- Minimal metadata — just the learning itself, no dates/sources/confidence
- Claude's Discretion: Organization scheme (by category, by phase, flat list)
- Claude's Discretion: When to merge similar learnings vs keep separate

### Context management
- System manages entirely — users do not need to manually edit/curate
- Claude's Discretion: Size management strategy (hard cap, relevance-based, summarization)
- Claude's Discretion: Maximum entry count
- Claude's Discretion: Staleness/pruning strategy

### Consumption mechanism
- Filtered loading: Load learnings from same phase/code area as current task (section match)
- Apply both proactively (review at start) and reactively (check when stuck)
- Log learning application only on success ("Applied learning: X")
- Claude's Discretion: What happens when applied learning doesn't help

### Claude's Discretion
- Trigger mechanism for learning capture
- Who extracts learnings (agent vs outer loop)
- AGENTS.md organization structure
- Deduplication strategy
- Size limits and pruning approach
- Handling of failed learning applications

</decisions>

<specifics>
## Specific Ideas

- Section-based relevance: current task's phase/area determines which learnings are loaded
- Attribution logging only when a learning successfully helps resolve an issue

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-learnings-propagation*
*Context gathered: 2026-01-19*
