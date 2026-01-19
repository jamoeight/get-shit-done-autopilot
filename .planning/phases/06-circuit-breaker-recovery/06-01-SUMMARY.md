---
phase: 06-circuit-breaker-recovery
plan: 01
subsystem: infra
tags: [circuit-breaker, failure-handling, bash, shell]

# Dependency graph
requires:
  - phase: 05-exit-conditions
    provides: stuck detection, exit status functions, interrupt handling
provides:
  - Circuit breaker pattern for cross-task failure detection
  - Pause menu with Resume/Skip/Abort options
  - Automatic reset on success
affects: [06-02, 07-learnings-propagation]

# Tech tracking
tech-stack:
  added: []
  patterns: [circuit-breaker-pattern]

key-files:
  created: []
  modified:
    - bin/lib/exit.sh
    - bin/ralph.sh

key-decisions:
  - "CIRCUIT_BREAKER_THRESHOLD=5 (higher than STUCK_THRESHOLD=3 to avoid overlap)"
  - "Circuit breaker increments unconditionally (no task-change reset unlike stuck detection)"
  - "Skip option resets circuit breaker (user intervention = system state change)"
  - "Non-interactive mode returns abort signal (fail fast per CONTEXT.md)"

patterns-established:
  - "Circuit breaker: track consecutive failures across different tasks, pause at threshold"
  - "Pause menu pattern: Resume/Skip/Abort with counter reset on user action"

# Metrics
duration: 4min
completed: 2026-01-19
---

# Phase 6 Plan 01: Circuit Breaker Pattern Summary

**Circuit breaker pattern that pauses execution after 5 consecutive failures across different tasks, with Resume/Skip/Abort menu in interactive mode**

## Performance

- **Duration:** 4 min
- **Started:** 2026-01-19
- **Completed:** 2026-01-19
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Circuit breaker functions added to exit.sh (check, reset, handle_pause)
- CIRCUIT_BREAKER_THRESHOLD=5 configured (higher than STUCK_THRESHOLD=3)
- ralph.sh integrates circuit breaker check in failure path after stuck detection
- Interactive mode shows Resume/Skip/Abort menu when circuit breaker trips
- Non-interactive mode fails fast with abort signal
- Success path resets circuit breaker counter

## Task Commits

Each task was committed atomically:

1. **Task 1: Add circuit breaker state and functions to exit.sh** - `c4d6d51` (feat)
2. **Task 2: Integrate circuit breaker into ralph.sh main loop** - `deb5815` (feat)

## Files Created/Modified
- `bin/lib/exit.sh` - Added CROSS_TASK_FAILURES counter, CIRCUIT_BREAKER_THRESHOLD=5, check_circuit_breaker(), reset_circuit_breaker(), handle_circuit_breaker_pause()
- `bin/ralph.sh` - Integrated circuit breaker check after stuck detection, reset on success

## Decisions Made
- CIRCUIT_BREAKER_THRESHOLD=5: Higher than STUCK_THRESHOLD=3 to avoid overlap between same-task stuck detection and cross-task circuit breaker
- Circuit breaker increments unconditionally: Unlike stuck detection which resets on task change, circuit breaker tracks total consecutive failures regardless of which task is failing
- Reset happens on Resume AND Skip: Both indicate user intervention, so counter should reset
- Non-interactive mode returns abort signal (2): Caller handles the exit, consistent with existing pattern where functions never exit directly

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Circuit breaker pattern complete and integrated
- Ready for 06-02 stuck analysis and alternative approach suggestions
- Pattern can be tested by simulating multiple task failures

---
*Phase: 06-circuit-breaker-recovery*
*Completed: 2026-01-19*
