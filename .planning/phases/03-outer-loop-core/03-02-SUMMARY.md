---
phase: 03-outer-loop-core
plan: 02
subsystem: infra
tags: [bash, cli, claude-invocation, json-parsing, failure-handling]

# Dependency graph
requires:
  - phase: 03-01
    provides: ralph.sh main loop skeleton, parse.sh with find_plan_file
  - phase: 03-03
    provides: display.sh with spinner functions (start_spinner/stop_spinner)
provides:
  - Claude CLI invocation wrapper (invoke_claude)
  - JSON output parsing with jq/fallback (parse_claude_output)
  - 30-minute duration alert logging
  - Interactive failure handling with Retry/Skip/Abort
  - Functional ralph.sh for actual plan execution
affects: [04-git-checkpointing, 05-result-handling]

# Tech tracking
tech-stack:
  added: []
  patterns: [CLI wrapper pattern, JSON parsing with fallback, interactive failure recovery]

key-files:
  created:
    - bin/lib/invoke.sh
  modified:
    - bin/ralph.sh

key-decisions:
  - "Claude CLI invoked with -p flag for non-interactive execution"
  - "JSON output parsed with jq when available, grep/sed fallback otherwise"
  - "Exit code > 1 treated as Claude crash (immediate abort)"
  - "Exit code 1 treated as normal failure (Retry/Skip/Abort options)"
  - "30-minute alert logged to ralph.log (no hard timeout per user decision)"
  - "Skip advances to next plan using get_next_plan_after (not hardcoded)"

patterns-established:
  - "invoke_claude: find plan file -> build prompt -> call claude -p -> return output file"
  - "parse_claude_output: check jq -> extract result/error/cost -> format summary"
  - "Failure handling: show error -> offer R/S/A -> return choice code"

# Metrics
duration: 3min
completed: 2026-01-19
---

# Phase 03 Plan 02: Claude CLI Invocation Summary

**Claude CLI wrapper with JSON output parsing, failure handling, and ralph.sh integration**

## Performance

- **Duration:** 3 min
- **Started:** 2026-01-19T20:05:55Z
- **Completed:** 2026-01-19T20:08:40Z
- **Tasks:** 3 (Tasks 1+2 combined in implementation)
- **Files created:** 1 (bin/lib/invoke.sh - 239 lines)
- **Files modified:** 1 (bin/ralph.sh)

## Accomplishments
- Created invoke.sh library with Claude CLI invocation and output parsing
- Implemented interactive failure handling with Retry/Skip/Abort options
- Integrated Claude invocation into ralph.sh main loop
- Added spinner display during execution
- Skip option correctly advances using get_next_plan_after

## Task Commits

Each task was committed atomically:

1. **Task 1: Create invoke.sh with Claude CLI wrapper** - `13f247a` (feat)
   - invoke_claude, parse_claude_output, check_iteration_duration functions
   - Also includes handle_iteration_failure and handle_claude_crash (Task 2 content)

2. **Task 2: Add failure handling with interactive pause** - (included in Task 1)
   - handle_iteration_failure with Retry/Skip/Abort options
   - handle_claude_crash for abnormal exits

3. **Task 3: Integrate invoke.sh into ralph.sh main loop** - `be3e474` (feat)
   - Source invoke.sh, replace placeholder with real invocation
   - Handle success/failure/crash paths

## Files Created/Modified
- `bin/lib/invoke.sh` - Claude CLI wrapper with JSON parsing and failure handling (239 lines)
- `bin/ralph.sh` - Updated main loop with real Claude invocation

## Key Functions

### invoke_claude(task_id)
- Finds plan file using find_plan_file from parse.sh
- Builds execution prompt with plan context
- Invokes `claude -p` with `--output-format json` and `--allowedTools`
- Returns temp file path with output

### parse_claude_output(output_file)
- Uses jq for JSON parsing when available
- Falls back to grep/sed for basic extraction
- Extracts result, error, cost_usd fields
- Returns formatted summary line

### handle_iteration_failure(task_id, error_message)
- Displays failure prominently with color
- Offers Retry/Skip/Abort options
- Returns choice code (0=Retry, 1=Skip, 2=Abort)

### check_iteration_duration(start_time)
- Logs warning if iteration exceeds 30 minutes
- Returns 0 (no hard timeout per user decision)

## Decisions Made
- Claude CLI invoked with `-p "$prompt" --output-format json --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebFetch"`
- Exit code 0 = success, exit code 1 = normal failure (offer choices), exit code > 1 = crash (abort)
- jq used for robust JSON parsing; grep/sed fallback for systems without jq
- Duration alert threshold set to 1800 seconds (30 minutes)

## Deviations from Plan

### Implementation Optimization

**1. [Optimization] Tasks 1 and 2 combined**
- **Reason:** handle_iteration_failure and handle_claude_crash are logically part of invoke.sh
- **Impact:** Single file created instead of two separate commits for Task 2
- **Result:** Cleaner organization, all invoke-related code in one place

No bugs or blocking issues encountered.

## Issues Encountered
None.

## User Setup Required

**jq (optional but recommended):**
- For robust JSON parsing, install jq: `apt install jq` / `brew install jq` / `choco install jq`
- Without jq, basic grep/sed parsing is used as fallback

## Next Phase Readiness
- ralph.sh is now functional for actual plan execution
- Invokes Claude with full context and parses results
- Failure handling allows user control over retry/skip/abort
- Ready for 04-git-checkpointing phase

---
*Phase: 03-outer-loop-core*
*Completed: 2026-01-19*
