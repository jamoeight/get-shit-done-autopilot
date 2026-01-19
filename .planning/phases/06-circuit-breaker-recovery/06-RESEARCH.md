# Phase 6: Circuit Breaker & Recovery - Research

**Researched:** 2026-01-19
**Domain:** Bash shell scripting - failure handling, state management, interactive prompts
**Confidence:** HIGH

## Summary

This phase extends the existing failure handling in ralph.sh with two new capabilities: (1) a circuit breaker that pauses execution after N consecutive failures across *different* tasks, and (2) stuck analysis that examines failure patterns to identify root causes before resuming.

The codebase already has solid foundation pieces:
- Global failure tracking variables (`CONSECUTIVE_FAILURES`, `LAST_FAILED_TASK`) in exit.sh
- `check_stuck()` function that detects N failures on the *same* task
- Interactive `handle_iteration_failure()` that presents Retry/Skip/Abort menu
- STATE.md iteration history with timestamps, outcomes, and task info
- Established color codes (YELLOW for warnings) and display patterns

The circuit breaker pattern differs from existing stuck detection: stuck = same task failing repeatedly (current), circuit breaker = different tasks failing consecutively (new). This catches systemic issues like environment problems or cascading failures.

**Primary recommendation:** Add a new `check_circuit_breaker()` function that tracks failures across different tasks, using similar patterns to existing `check_stuck()`. For stuck analysis, parse the last N failure entries from STATE.md history to identify common patterns (same error type, same file mentioned, related task prefixes).

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bash | 4.0+ | Shell scripting | Already in use, cross-platform via Git Bash |
| grep/sed/awk | POSIX | Text parsing | Already established in codebase for STATE.md manipulation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| read | builtin | Interactive input | User prompts for Resume/Skip/Abort |
| date | POSIX | Timestamps | Already used for iteration logging |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Global variables | File-based state | Files add I/O overhead; globals already established pattern in exit.sh |
| Complex log parsing | Simple grep patterns | Complexity adds fragility; simple patterns match established codebase style |

**Installation:**
No additional dependencies required. All tools already available.

## Architecture Patterns

### Recommended File Structure
```
bin/lib/
├── exit.sh           # Extended with circuit breaker (parallel to existing stuck detection)
├── recovery.sh       # NEW: Stuck analysis and pattern detection functions
├── invoke.sh         # Extended handle_iteration_failure with Skip option handling
└── state.sh          # Potentially extended for analysis section in STATE.md
```

### Pattern 1: Two-Level Failure Detection

**What:** Separate single-task stuck detection from cross-task circuit breaker
**When to use:** When you need to distinguish between "one thing is broken" vs "everything is broken"

Current behavior (exit.sh):
```bash
# Existing: Track failures on SAME task
CONSECUTIVE_FAILURES=0
LAST_FAILED_TASK=""
STUCK_THRESHOLD=3

check_stuck() {
    local task_id="$1"
    if [[ "$task_id" == "$LAST_FAILED_TASK" ]]; then
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    else
        CONSECUTIVE_FAILURES=1
        LAST_FAILED_TASK="$task_id"
    fi
    [[ "$CONSECUTIVE_FAILURES" -ge "$STUCK_THRESHOLD" ]]
}
```

New pattern needed:
```bash
# NEW: Track failures across DIFFERENT tasks
CROSS_TASK_FAILURES=0
CIRCUIT_BREAKER_THRESHOLD=5  # Recommended: higher than stuck threshold

check_circuit_breaker() {
    # Increments on any failure regardless of task
    # Does NOT reset when task changes (unlike check_stuck)
    CROSS_TASK_FAILURES=$((CROSS_TASK_FAILURES + 1))
    [[ "$CROSS_TASK_FAILURES" -ge "$CIRCUIT_BREAKER_THRESHOLD" ]]
}

reset_circuit_breaker() {
    CROSS_TASK_FAILURES=0
}
```

### Pattern 2: Interactive Pause with Three Options

**What:** Present Resume/Skip/Abort menu when circuit breaker triggers
**When to use:** In interactive mode (terminal detected via `[[ -t 0 ]]`)

```bash
# Source: Established pattern from invoke.sh handle_iteration_failure
handle_circuit_breaker_pause() {
    echo ""
    echo -e "${YELLOW}${BOLD}CIRCUIT BREAKER: $CROSS_TASK_FAILURES consecutive failures${RESET}"
    echo -e "${YELLOW}Multiple tasks are failing - systemic issue suspected${RESET}"
    echo ""

    # Show analysis summary (3-5 lines)
    generate_stuck_analysis

    echo ""
    echo -e "Options:"
    echo -e "  ${YELLOW}r${RESET} - Resume execution"
    echo -e "  ${YELLOW}s${RESET} - Skip current task and continue"
    echo -e "  ${YELLOW}a${RESET} - Abort ralph loop"
    echo ""

    while true; do
        read -p "Choice [r/s/a]: " choice
        case "$choice" in
            r|R) reset_circuit_breaker; return 0 ;;  # Resume
            s|S) reset_circuit_breaker; return 1 ;;  # Skip
            a|A) return 2 ;;  # Abort
            *) echo "Invalid choice. Enter r, s, or a." ;;
        esac
    done
}
```

### Pattern 3: Stuck Analysis from History

**What:** Parse recent failure entries from STATE.md to identify patterns
**When to use:** When circuit breaker triggers, before showing pause prompt

```bash
# Parse last N entries from STATE.md history for patterns
generate_stuck_analysis() {
    local history_entries
    local failure_count
    local common_error=""
    local common_file=""

    # Extract recent FAILURE entries from history
    history_entries=$(sed -n '/<!-- HISTORY_START -->/,/<!-- HISTORY_END -->/{
        /FAILURE/p
    }' "$STATE_FILE" | head -5)

    # Look for common patterns
    # Pattern 1: Same error message appearing multiple times
    common_error=$(echo "$history_entries" | grep -oE 'Error: [^|]+' | sort | uniq -c | sort -rn | head -1)

    # Pattern 2: Same file mentioned across failures
    common_file=$(echo "$history_entries" | grep -oE '[a-zA-Z0-9_/-]+\.(sh|md|ts|js)' | sort | uniq -c | sort -rn | head -1)

    echo -e "${YELLOW}Failure Analysis:${RESET}"
    if [[ -n "$common_error" ]]; then
        echo "  Pattern: $common_error"
    fi
    if [[ -n "$common_file" ]]; then
        echo "  Affected: $common_file"
    fi
    echo "  Suggestion: Check recent changes or environment"
}
```

### Anti-Patterns to Avoid
- **Writing analysis to separate file:** Per CONTEXT.md decision, inline in STATE.md or console only
- **Complex ML-based pattern detection:** Simple grep patterns match codebase style
- **Hard exits from functions:** Per established pattern, return codes only - caller decides exit
- **Resetting circuit breaker on task change:** That defeats the purpose - circuit breaker tracks cross-task failures

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| User input prompts | Custom input loops | Existing `handle_iteration_failure` pattern | Already handles edge cases, consistent UX |
| Color output | Raw ANSI codes | Existing `$YELLOW`, `$RED` etc. from display.sh | Respects NO_COLOR, consistent styling |
| STATE.md parsing | Custom parsers | Existing `sed -n '/.../p'` patterns from state.sh | Proven patterns, marker-based sections |
| Atomic writes | Direct writes | `atomic_write` from state.sh | Crash-safe pattern already established |

**Key insight:** The codebase has established idioms for all building blocks. Phase 6 composes existing patterns rather than inventing new ones.

## Common Pitfalls

### Pitfall 1: Conflating Stuck Detection with Circuit Breaker

**What goes wrong:** Trying to use single counter for both same-task and cross-task failures
**Why it happens:** Both are "consecutive failures" but semantically different
**How to avoid:** Use separate counters with separate thresholds
- `CONSECUTIVE_FAILURES` + `STUCK_THRESHOLD=3` = same task (existing)
- `CROSS_TASK_FAILURES` + `CIRCUIT_BREAKER_THRESHOLD=5` = different tasks (new)
**Warning signs:** Circuit breaker triggers when user skips a single failing task

### Pitfall 2: Forgetting Non-Interactive Mode

**What goes wrong:** Calling `read` in non-interactive mode hangs forever
**Why it happens:** Per CONTEXT.md, non-interactive should fail fast
**How to avoid:** Check `[[ -t 0 ]]` before any interactive prompts
```bash
if [[ -t 0 ]]; then
    handle_circuit_breaker_pause  # Interactive
else
    exit_with_status "STUCK" "Circuit breaker triggered" ...
    exit $EXIT_STUCK  # Non-interactive: fail fast
fi
```
**Warning signs:** ralph.sh hangs in CI/cron environments

### Pitfall 3: Analysis Section Bloat

**What goes wrong:** Stuck analysis grows unboundedly in STATE.md
**Why it happens:** Appending analysis on each pause without cleanup
**How to avoid:** Keep analysis to 3-5 lines (per CONTEXT.md); overwrite rather than append
**Warning signs:** STATE.md grows by KB per iteration

### Pitfall 4: Not Resetting After User Action

**What goes wrong:** Circuit breaker triggers again immediately after resume
**Why it happens:** Forgetting to reset counter when user chooses Resume
**How to avoid:** Call `reset_circuit_breaker()` on Resume choice
**Warning signs:** User gets stuck in pause loop

### Pitfall 5: Skip Doesn't Advance Task

**What goes wrong:** After Skip, loop retries same task
**Why it happens:** Skip needs to update STATE.md next_action
**How to avoid:** Reuse existing skip logic from main loop case statement
**Warning signs:** Skip acts like Retry

## Code Examples

Verified patterns from existing codebase:

### Reading User Input with Validation
```bash
# Source: bin/lib/invoke.sh handle_iteration_failure (lines 196-221)
while true; do
    read -p "Choice [r/s/a]: " choice
    case "$choice" in
        r|R) return 0 ;;  # Retry
        s|S) return 1 ;;  # Skip
        a|A) return 2 ;;  # Abort
        *) echo "Invalid choice. Enter r, s, or a." ;;
    esac
done
```

### Checking Interactive Mode
```bash
# Source: Established in CONTEXT.md decisions
if [[ -t 0 ]]; then
    # Interactive mode - prompt user
    handle_circuit_breaker_pause
    choice=$?
else
    # Non-interactive - fail fast
    exit_with_status "STUCK" "Circuit breaker triggered (non-interactive)"
    exit $EXIT_STUCK
fi
```

### Parsing STATE.md History Section
```bash
# Source: bin/lib/state.sh (lines 262-265)
existing_entries=$(sed -n '/<!-- HISTORY_START -->/,/<!-- HISTORY_END -->/{
    /^| [0-9]/p
}' "$STATE_FILE")
```

### Color-Coded Status Output
```bash
# Source: bin/lib/display.sh show_status pattern
echo -e "${YELLOW}${BOLD}CIRCUIT BREAKER TRIGGERED${RESET}"
echo -e "${YELLOW}$message${RESET}"
```

### Global Variable State Tracking
```bash
# Source: bin/lib/exit.sh (lines 33-36)
CONSECUTIVE_FAILURES=0
LAST_FAILED_TASK=""
STUCK_THRESHOLD=3
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Exit on any failure | Retry/Skip/Abort menu | Phase 3 | User control over failure handling |
| Single stuck detection | Two-level detection | Phase 6 (this) | Distinguishes task vs systemic failures |
| Exit on stuck | Pause + analysis | Phase 6 (this) | Preserves progress, enables recovery |

**Deprecated/outdated:**
- None - this is new functionality building on established patterns

## Open Questions

Things that couldn't be fully resolved:

1. **Optimal Circuit Breaker Threshold**
   - What we know: Must be higher than STUCK_THRESHOLD (3) to avoid overlap
   - What's unclear: Exact optimal value - 5? 7? 10?
   - Recommendation: Start with 5 (allows 2 different tasks to fail before triggering), make configurable if needed

2. **Analysis Granularity**
   - What we know: 3-5 lines per CONTEXT.md
   - What's unclear: How much pattern detection is "enough"?
   - Recommendation: Start simple (common error, common file), iterate based on usage

3. **Alternative Approaches (LOOP-04)**
   - What we know: Requirement says "try alternative approaches before giving up"
   - What's unclear: What constitutes an "alternative approach" in this context?
   - Recommendation: Could mean (a) different model parameters, (b) modified prompt, or (c) task decomposition. Start with analysis + manual user decision, add automation later if needed

## Sources

### Primary (HIGH confidence)
- bin/lib/exit.sh - Existing stuck detection pattern
- bin/lib/invoke.sh - Existing user prompt pattern
- bin/lib/state.sh - STATE.md manipulation patterns
- bin/ralph.sh - Main loop integration points
- 06-CONTEXT.md - User decisions constraining implementation

### Secondary (MEDIUM confidence)
- [Bash best practices](https://bertvv.github.io/cheat-sheets/Bash.html) - Global variable conventions
- [Interactive Bash Scripts](https://www.owais.io/blog/2025-08-25_bash-user-input/) - read command patterns
- [Circuit Breaker Pattern Guide](https://www.shadecoder.com/topics/the-circuit-breaker-pattern-a-comprehensive-guide-for-2025) - Pattern theory

### Tertiary (LOW confidence)
- WebSearch for bash log parsing patterns - verified against existing codebase patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all tools already in use in codebase
- Architecture: HIGH - follows established patterns from exit.sh, invoke.sh
- Pitfalls: HIGH - derived from codebase analysis and established bash practices

**Research date:** 2026-01-19
**Valid until:** 2026-02-19 (stable domain, bash patterns don't change fast)
