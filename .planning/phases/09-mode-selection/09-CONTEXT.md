# Phase 9: Mode Selection & Base Commands - Context

**Gathered:** 2026-01-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable users to choose between Interactive and Lazy execution modes at GSD startup. Interactive mode is the current behavior (plan one phase, execute, repeat). Lazy mode is "fire and forget" — plan everything upfront, then autonomous execution until complete. Each mode has its own command set.

</domain>

<decisions>
## Implementation Decisions

### Mode Selection UX
- Explicit command only — no automatic prompting, user runs `/gsd:lazy-mode` when ready
- Toggle command design: `/gsd:lazy-mode` enables lazy mode, run again to disable
- Full mode explainer shown when toggling — paragraph explaining what changes in this mode
- Warn but allow switching mid-milestone: "Switching mid-execution may cause issues"

### Mode Persistence
- Project-local storage in `.planning/.ralph-config` — each project has its own mode
- No default mode for new projects — require explicit choice before mode-specific commands work
- Mode visible in both places: `/gsd:lazy-mode` shows current status AND `/gsd:progress` includes mode
- Mode NOT in STATE.md — keep STATE.md focused on progress, mode lives only in .ralph-config

### Command Availability
- Different command sets entirely — Interactive and Lazy modes have completely separate command namespaces
- Lazy-only commands hidden entirely in interactive mode (don't show in help, error if invoked)
- Interactive-mode commands (plan-phase, discuss-phase) not available in lazy mode
- Core philosophy: In lazy mode, you give ALL requirements upfront, then it works till complete

### Help & Discoverability
- `/gsd:help` always shows both command sets with (interactive) and (lazy) labels
- When mode not set: show all commands but emphasize "set mode first" message at top
- Passive discovery — lazy mode mentioned in help, no active promotion
- Mode comparison is part of `/gsd:lazy-mode` output — when toggling, explainer covers differences

### Claude's Discretion
- Which commands are lazy-mode specific (execution vs planning+execution)
- Exact wording of mode explainer and warnings
- How to handle edge cases when mode-restricted command is invoked

</decisions>

<specifics>
## Specific Ideas

- "The whole goal is that you give ALL requirements upfront and then it works till complete"
- "Current GSD you have to be present at your setup" — lazy mode removes that requirement
- Two fundamentally different workflows, not just a setting that tweaks behavior

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-mode-selection*
*Context gathered: 2026-01-19*
