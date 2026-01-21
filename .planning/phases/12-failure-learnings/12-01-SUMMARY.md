---
phase: 12-failure-learnings
plan: 01
subsystem: infra
tags: [bash, learnings, failure-tracking, awk, jq]

# Dependency graph
requires:
  - phase: 07-learnings-propagation
    provides: "AGENTS.md infrastructure with section-based storage and get_learnings_for_phase function"
provides:
  - "Failure extraction functions (ensure_failure_section, extract_failure_reason)"
  - "Failure storage functions (append_failure_learning, enforce_failure_cap)"
  - "Failure cleanup function (clear_phase_failures)"
  - "## Failure Context section in AGENTS.md with phase-scoped subsections"
affects: [ralph, retry-logic, phase-completion]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Failure learnings stored in ## Failure Context section with ### Phase N: subsections"
    - "FAILURE_REASON: marker for structured error extraction from Claude output"
    - "100-failure cap per phase enforced with oldest-first pruning"
    - "Phase completion triggers failure cleanup via clear_phase_failures"

key-files:
  created: []
  modified:
    - "bin/lib/learnings.sh"

key-decisions:
  - "Use jq for JSON parsing with grep/sed fallback for systems without jq"
  - "Store failures with multi-line format: task ID, timestamp, error, attempted, files, context"
  - "Clear all failures when phase completes successfully (no archiving)"
  - "Enforce 100-failure cap per phase, dropping oldest first"

patterns-established:
  - "extract_failure_reason: Multi-strategy extraction (FAILURE_REASON marker → .error field → grep patterns)"
  - "append_failure_learning: Structured failure entry with escaping for awk/sed safety"
  - "clear_phase_failures: Awk-based phase subsection removal while preserving structure"

# Metrics
duration: 10min
completed: 2026-01-21
---

# Phase 12 Plan 01: Failure Extraction & Storage Summary

**Failure learning infrastructure with JSON extraction, structured storage in AGENTS.md, and phase-scoped cleanup**

## Performance

- **Duration:** 10 min
- **Started:** 2026-01-21T03:14:28Z
- **Completed:** 2026-01-21T03:24:56Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Failure Context section infrastructure in AGENTS.md with phase-scoped subsections
- Multi-strategy failure extraction from Claude's JSON output (jq with grep/sed fallback)
- Structured failure storage with 5 fields: task ID, timestamp, error, attempted, files, context
- 100-failure-per-phase cap enforcement with oldest-first pruning
- Phase completion cleanup removes all failures for completed phase

## Task Commits

Each task was committed atomically:

1. **Task 1: Add ensure_failure_section and extract_failure_reason functions** - `326c756` (feat)
   - ensure_failure_section creates ## Failure Context section
   - extract_failure_reason parses Claude JSON (FAILURE_REASON marker → .error field → grep fallback)
   - Works with or without jq (grep/sed fallback implemented)
   - Truncates at 500 chars preserving complete words

2. **Task 2: Add append_failure_learning and enforce_failure_cap functions** - `22043a4` (feat)
   - append_failure_learning stores structured failures with all 5 fields
   - Creates phase subsections (### Phase N:) under ## Failure Context
   - Escapes special characters for awk/sed safety
   - enforce_failure_cap drops oldest when at 100 per phase

3. **Task 3: Add clear_phase_failures function** - `c0235df` (feat)
   - Removes entire ### Phase N: subsection from ## Failure Context
   - Uses awk to track section boundaries
   - Preserves other sections and Failure Context header
   - Called when phase boundary crossed

## Files Created/Modified
- `bin/lib/learnings.sh` - Added 5 failure learning functions (239 lines total)
- `.planning/AGENTS.md` - Created with initial structure including ## Failure Context section

## Decisions Made

**Decision 1: jq with grep/sed fallback**
- **Rationale:** Not all systems have jq installed; grep/sed provides universal fallback for JSON field extraction
- **Impact:** extract_failure_reason works on any system
- **Implementation:** Check `command -v jq`, fall back to `grep -o '"field": "value"'` pattern

**Decision 2: Multi-line failure entry format**
- **Rationale:** Single-line entries lack context for effective retry learning
- **Format:** `- [task-id | timestamp] **Error:** ... **Attempted:** ... **Files:** ... **Context:** ...`
- **Impact:** Retries have full context about what failed, what was tried, and surrounding circumstances

**Decision 3: Special character escaping in append_failure_learning**
- **Rationale:** Error messages can contain sed/awk metacharacters (/, &, ', \) that break awk variables
- **Implementation:** `sed "s/&/\\\\&/g; s/'/'\\\\''/g"` before passing to awk
- **Impact:** Prevents "unterminated command" errors when storing failures with special characters

**Decision 4: Phase-scoped subsections**
- **Rationale:** Enables selective cleanup on phase completion without affecting other phases
- **Structure:** `## Failure Context` → `### Phase N:` → failure entries
- **Impact:** clear_phase_failures can remove just one phase's failures via awk pattern matching

## Deviations from Plan

**1. [Rule 1 - Bug] Fixed CRLF line ending issue**
- **Found during:** Task 3 verification
- **Issue:** Edit tool was creating CRLF line endings on Windows, causing "unexpected end of file" syntax errors
- **Fix:** Ran `dos2unix bin/lib/learnings.sh` to convert to LF (Unix) line endings
- **Files modified:** bin/lib/learnings.sh
- **Verification:** `source bin/lib/learnings.sh` succeeded without errors
- **Committed in:** c0235df (Task 3 commit)

**2. [Rule 2 - Missing Critical] Added whitespace normalization in enforce_failure_cap**
- **Found during:** Task 2 verification
- **Issue:** `grep -c` output had whitespace/newlines, causing `[[: 0\n0: syntax error in expression`
- **Fix:** Added `count=$(echo "$count" | tr -d '[:space:]')` to strip whitespace
- **Files modified:** bin/lib/learnings.sh
- **Verification:** `enforce_failure_cap 12` ran without errors
- **Committed in:** 22043a4 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 missing critical)
**Impact on plan:** Both fixes necessary for correct operation on Windows systems. No scope creep.

## Issues Encountered

**Issue 1: jq not available on test system**
- **Problem:** Initial tests failed because jq was not installed
- **Resolution:** Implemented grep/sed fallback extraction as part of planned multi-strategy approach
- **Outcome:** Function works universally with or without jq

**Issue 2: Syntax error investigation during Task 3**
- **Problem:** Adding clear_phase_failures caused "unexpected end of file" errors
- **Root cause:** Edit tool created CRLF line endings, confusing bash parser
- **Resolution:** Restored file from git, re-applied changes, converted to Unix line endings
- **Outcome:** All functions source correctly, all tests pass

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for integration:**
- All 5 failure learning functions implemented and tested
- AGENTS.md Failure Context section created
- End-to-end verification passed (store → retrieve → cleanup)

**Integration points for next plan:**
- ralph.sh: Call `extract_failure_reason` and `append_failure_learning` on task failure
- ralph.sh: Call `clear_phase_failures` when phase boundary crossed
- invoke.sh: Extend `get_learnings_for_phase` to include ## Failure Context section

**No blockers** - foundation complete, ready for plan 12-02 (Ralph Integration)

---
*Phase: 12-failure-learnings*
*Completed: 2026-01-21*
