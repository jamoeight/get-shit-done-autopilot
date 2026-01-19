---
phase: 03-outer-loop-core
plan: 01
subsystem: infra
tags: [bash, cli, state-parsing, outer-loop]

# Dependency graph
requires:
  - phase: 01-safety-foundation
    provides: Budget configuration (MAX_ITERATIONS, TIMEOUT_HOURS), fail-fast error handling
  - phase: 02-state-extensions
    provides: STATE.md manipulation functions (add_iteration_entry, update_progress, update_next_action)
provides:
  - ralph.sh main entry point for outer loop execution
  - parse.sh library for STATE.md/ROADMAP.md parsing
  - Iteration logging to ralph.log
  - State update integration with state.sh functions
affects: [03-02, 03-03, 04-git-checkpointing]

# Tech tracking
tech-stack:
  added: []
  patterns: [main loop with budget checking, iteration timing tracking, state-based task determination]

key-files:
  created:
    - bin/ralph.sh
    - bin/lib/parse.sh
  modified: []

key-decisions:
  - "parse_next_task extracts plan ID from STATE.md Description line using grep -oE '[0-9]{2}-[0-9]{2}'"
  - "get_next_plan_after finds next uncompleted plan by parsing ROADMAP.md checkboxes"
  - "Iteration success advances to next plan via update_next_action; failure stays on same task"
  - "ralph.sh sources all lib files (budget, state, display, failfast, parse)"
  - "--start-from flag allows overriding starting plan with NN-MM format validation"

patterns-established:
  - "Main loop pattern: check limits -> get task -> execute -> update state -> repeat"
  - "State-driven task determination: parse_next_task reads STATE.md, no hardcoded sequences"
  - "Iteration logging: dual output to ralph.log (detailed) and STATE.md history (summary)"

# Metrics
duration: 5min
completed: 2026-01-19
---

# Phase 3 Plan 1: Ralph Loop Skeleton Summary

**ralph.sh outer loop with STATE.md parsing, iteration tracking, and state update integration**

## Performance

- **Duration:** 5 min
- **Started:** 2026-01-19T19:58:13Z
- **Completed:** 2026-01-19T20:03:34Z
- **Tasks:** 3
- **Files created:** 2

## Accomplishments
- Created parse.sh with functions to extract task info from STATE.md and ROADMAP.md
- Built ralph.sh main script with iteration loop and budget checking
- Integrated iteration logging and state updates for success/failure paths

## Task Commits

Each task was committed atomically:

1. **Task 1: Create parse.sh library** - `adcc42f` (feat)
2. **Task 2: Create ralph.sh main script** - `d35b5fe` (feat)
3. **Task 3: Add iteration logging and state updates** - `139f88f` (feat)

## Files Created/Modified
- `bin/lib/parse.sh` - STATE.md/ROADMAP.md parsing functions (parse_next_task, find_plan_file, get_plan_name, get_next_plan_after)
- `bin/ralph.sh` - Main outer loop entry point with iteration control and state integration

## Decisions Made
- parse_next_task uses `grep -oE '[0-9]{2}-[0-9]{2}'` to extract plan ID from Description line
- get_next_plan_after parses ROADMAP.md `- [ ] NN-MM-PLAN.md` checkboxes to find next uncompleted plan
- Iteration success calls handle_iteration_success which advances to next plan
- Iteration failure calls handle_iteration_failure_state which stays on same task for retry
- --start-from flag validates NN-MM format before use

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed local variable usage outside function**
- **Found during:** Task 2 (ralph.sh testing)
- **Issue:** Used `local next_task` in main loop body - `local` only valid inside functions
- **Fix:** Moved variable declaration to script-level initialization (`next_task=""`)
- **Files modified:** bin/ralph.sh
- **Verification:** Script runs without "local: can only be used in a function" error
- **Committed in:** d35b5fe (included in Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor syntax fix required for script execution. No scope creep.

## Issues Encountered
None - plan executed as specified after bug fix.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- ralph.sh skeleton ready for Claude CLI invocation (03-02)
- parse.sh functions tested and working
- State update integration verified
- Placeholder in main loop marked for Claude invocation replacement

---
*Phase: 03-outer-loop-core*
*Completed: 2026-01-19*
