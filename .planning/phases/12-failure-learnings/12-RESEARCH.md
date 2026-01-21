# Phase 12: Failure Learnings - Research

**Researched:** 2026-01-20
**Domain:** Failure extraction, learning propagation, retry context
**Confidence:** HIGH

## Summary

Phase 12 implements failure learning extraction and propagation, building on the existing learnings.sh infrastructure from Phase 7. The goal is to capture structured failure context from Claude's output when tasks fail, store it in a dedicated "Failure Context" section of AGENTS.md, and ensure retry attempts have access to previous failure information.

The key insight is that this phase extends an already-proven pattern - the learnings system already has section-based storage, deduplication, size management, and prompt injection. Failure learnings need: (1) extraction from Claude's JSON output, (2) a new storage section, (3) phase-based cleanup, and (4) integration into the existing prompt injection flow.

**Primary recommendation:** Add failure extraction functions to learnings.sh that parse Claude's JSON output for error context, store failures in a `## Failure Context` section with phase-scoped subsections, clear failures on phase completion, and let the existing `get_learnings_for_phase` function include failure context automatically.

## Standard Stack

The established tools/patterns for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| jq | system | JSON parsing for Claude output | Already used in parse_claude_output, robust JSON handling |
| sed | GNU | Section extraction/manipulation | Already used throughout learnings.sh, state.sh |
| awk | GNU | Line-by-line processing | Already used for append_learning, update_section |
| grep | GNU | Pattern matching | Already used for deduplication, section detection |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| mktemp | POSIX | Atomic file writes | Standard pattern from state.sh, learnings.sh |
| date | GNU | Timestamp generation | For failure entry timestamps |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| jq for JSON | grep/sed fallback | Already have jq fallback in parse_claude_output, use same pattern |
| Section markers | Separate file | Section-based approach matches existing learnings.sh architecture |

**No installation needed:** All tools are already available and used in the existing codebase.

## Architecture Patterns

### Recommended AGENTS.md Structure Extension
```markdown
# Project Learnings

## Error Fixes
[existing error fixes]

## Codebase Patterns
[existing codebase patterns]

## Phase-Specific
[existing phase-specific learnings]

## Failure Context

Failure learnings from current phase - cleared on phase completion.

### Phase 12:

- [12-01 | 2026-01-20 14:32:15] **Error:** Command 'npm test' failed with exit code 1
  **Attempted:** Ran test suite to verify implementation
  **Files:** bin/lib/learnings.sh, bin/ralph.sh
  **Context:** Tests failed because jest config was missing in package.json

- [12-01 | 2026-01-20 14:35:22] **Error:** sed: -e expression #1, char 15: unterminated `s' command
  **Attempted:** Tried to extract failure reason using sed pattern
  **Files:** bin/lib/learnings.sh
  **Context:** Single quotes in error message broke sed pattern

```

### Pattern 1: Failure Extraction from Claude JSON Output
**What:** Parse Claude's JSON output to extract failure information
**When to use:** When exit code is non-zero (task failure)
**Example:**
```bash
# Source: Extension of existing parse_claude_output pattern
extract_failure_reason() {
    local output_file="$1"

    if [[ -z "$output_file" || ! -f "$output_file" ]]; then
        echo "Unknown failure (no output file)"
        return 0
    fi

    # Primary extraction: Look for structured markers in Claude's result
    local result=""
    if command -v jq &>/dev/null; then
        result=$(jq -r '.result // empty' "$output_file" 2>/dev/null)
    fi

    # Try to find FAILURE_REASON marker
    if [[ -n "$result" ]]; then
        local reason
        reason=$(echo "$result" | grep -oP 'FAILURE_REASON:\s*\K.*' | head -1)
        if [[ -n "$reason" ]]; then
            echo "$reason"
            return 0
        fi
    fi

    # Fallback: Extract error field from JSON
    if command -v jq &>/dev/null; then
        local error
        error=$(jq -r '.error // empty' "$output_file" 2>/dev/null)
        if [[ -n "$error" ]]; then
            echo "$error"
            return 0
        fi
    fi

    # Fallback: Look for common error patterns in output
    local error_pattern
    error_pattern=$(grep -iE '(error|failed|exception|cannot|not found):?' "$output_file" 2>/dev/null | head -1)
    if [[ -n "$error_pattern" ]]; then
        echo "$error_pattern" | cut -c1-200
        return 0
    fi

    echo "Task failed (no specific error message captured)"
    return 0
}
```

### Pattern 2: Structured Failure Learning Storage
**What:** Store failure with task ID, timestamp, error, attempted action, files, context
**When to use:** After extracting failure reason
**Example:**
```bash
# Source: Extension of append_learning pattern
append_failure_learning() {
    local task_id="$1"
    local error_msg="$2"
    local attempted="$3"
    local files="$4"
    local context="$5"

    local phase_num="${task_id%%-*}"
    phase_num=$((10#$phase_num))  # Remove leading zeros

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Format the failure entry
    local entry="[$task_id | $timestamp] **Error:** $error_msg
  **Attempted:** $attempted
  **Files:** $files
  **Context:** $context"

    # Ensure AGENTS.md exists with Failure Context section
    ensure_failure_section

    # Check failure count for phase, drop oldest if at cap
    enforce_failure_cap "$phase_num"

    # Append under Phase N subsection of Failure Context
    append_to_failure_section "$phase_num" "$entry"
}
```

### Pattern 3: Phase Boundary Cleanup
**What:** Clear all failure learnings when phase completes successfully
**When to use:** After last task in phase succeeds
**Example:**
```bash
# Source: Adaptation of rotate_history_at_phase_boundary pattern
clear_phase_failures() {
    local phase_num="$1"

    if [[ ! -f "$AGENTS_FILE" ]]; then
        return 0
    fi

    phase_num=$((10#$phase_num))  # Remove leading zeros

    # Remove ### Phase N: subsection from ## Failure Context
    local temp
    temp=$(mktemp)

    awk -v phase="### Phase ${phase_num}:" '
        BEGIN { in_phase = 0; in_failure = 0 }
        /^## Failure Context/ { in_failure = 1; print; next }
        /^## / && in_failure { in_failure = 0 }
        $0 == phase && in_failure { in_phase = 1; next }
        /^### Phase/ && in_phase { in_phase = 0 }
        !in_phase { print }
    ' "$AGENTS_FILE" > "$temp"

    mv "$temp" "$AGENTS_FILE"
}
```

### Pattern 4: Failure Count Enforcement
**What:** Enforce 100-failure-per-phase cap, dropping oldest when exceeded
**When to use:** Before appending new failure
**Example:**
```bash
# Source: Adaptation of prune_agents_if_needed pattern
enforce_failure_cap() {
    local phase_num="$1"
    local max_failures=100

    if [[ ! -f "$AGENTS_FILE" ]]; then
        return 0
    fi

    # Count failures for this phase
    local count
    count=$(grep -c "^\- \[${phase_num}-" "$AGENTS_FILE" 2>/dev/null || echo "0")

    if [[ "$count" -lt "$max_failures" ]]; then
        return 0
    fi

    # Drop oldest failure (failures are appended, so first is oldest)
    local temp
    temp=$(mktemp)
    local dropped=false

    awk -v phase="${phase_num}" -v dropped="$dropped" '
        /^- \[/ && $0 ~ "^- \\[" phase "-" && !dropped {
            dropped = 1
            next  # Skip this line (drop oldest)
        }
        { print }
    ' "$AGENTS_FILE" > "$temp"

    mv "$temp" "$AGENTS_FILE"
}
```

### Anti-Patterns to Avoid
- **Extracting only on exit code 1:** Any non-zero exit code should trigger extraction (CONTEXT.md decision)
- **Verbose failure entries:** Keep entries concise but informative; "Attempted" field should be 2-3 sentences max
- **Storing alternative suggestions:** Per CONTEXT.md, keep learnings factual, let retry figure out alternatives
- **Keeping failures after phase success:** Clear on phase completion, not task success
- **Multiple extraction attempts per failure:** Extract once, store once, no retry on extraction

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | Custom regex | jq + grep fallback | Already proven in parse_claude_output |
| Section manipulation | String concatenation | awk patterns from learnings.sh | Handles edge cases, atomic |
| Deduplication | Custom hash table | grep -qF exact match | Proven in append_learning |
| Atomic file writes | echo >> | mktemp + mv pattern | Already used throughout codebase |
| Timestamp generation | Manual formatting | date '+%Y-%m-%d %H:%M:%S' | Standard, used in state.sh |

**Key insight:** The existing learnings.sh provides most of the infrastructure. This phase adds failure-specific extraction and a new section - it does NOT reinvent the learnings storage system.

## Common Pitfalls

### Pitfall 1: Over-Extracting from Non-Failures
**What goes wrong:** Extracting "failures" from successful tasks that had warnings
**Why it happens:** Looking for error patterns without checking exit code first
**How to avoid:** Only call failure extraction when exit_code != 0
**Warning signs:** Failure context contains entries from successful tasks

### Pitfall 2: Truncating Critical Error Context
**What goes wrong:** Error message cut off mid-word, losing the actionable part
**Why it happens:** Hard character limits on error extraction
**How to avoid:** Use intelligent truncation that preserves complete words/lines
**Warning signs:** Failure context ends with "..." or cut-off words

### Pitfall 3: Failure Entries Too Terse
**What goes wrong:** "Error: failed" provides no context for retry
**Why it happens:** Extracting only the first error line
**How to avoid:** Include "Attempted" and "Context" fields per CONTEXT.md decision
**Warning signs:** Retry makes the same mistake

### Pitfall 4: Not Integrating with Existing Loading
**What goes wrong:** Failure context not included in retry prompts
**Why it happens:** Building separate loading mechanism instead of extending get_learnings_for_phase
**How to avoid:** Modify get_learnings_for_phase to include failure context section
**Warning signs:** Retries don't mention previous failures

### Pitfall 5: sed/awk Injection from Error Messages
**What goes wrong:** Error message containing special characters breaks sed/awk
**Why it happens:** Error messages can contain `/`, `\`, `'`, `&` and other special chars
**How to avoid:** Escape special characters before passing to sed/awk, or use awk variables
**Warning signs:** "unterminated command" errors when storing failures

## Code Examples

Verified patterns from official sources and existing codebase:

### Ensure Failure Context Section Exists
```bash
# Source: Adapted from init_agents_file pattern
ensure_failure_section() {
    if [[ ! -f "$AGENTS_FILE" ]]; then
        init_agents_file
    fi

    # Check if Failure Context section exists
    if grep -q "^## Failure Context" "$AGENTS_FILE" 2>/dev/null; then
        return 0
    fi

    # Append Failure Context section at end
    {
        echo ""
        echo "## Failure Context"
        echo ""
        echo "Failure learnings from current phase - cleared on phase completion."
        echo ""
    } >> "$AGENTS_FILE"
}
```

### Extend get_learnings_for_phase
```bash
# Source: Extension of existing get_learnings_for_phase
# Add to existing function, after phase_specific extraction:

    # Extract failure context for this phase
    local failure_context
    if [[ -n "$phase_num" ]]; then
        failure_context=$(sed -n "/^### Phase ${phase_num}:/,/^### /{
            /^### Phase ${phase_num}:/d
            /^### /d
            p
        }" "$AGENTS_FILE" | \
        sed -n '/^## Failure Context/,/^## /{
            /^## Failure Context/d
            /^## /d
            p
        }')
    fi

    # Add failure context to output if any
    if [[ -n "$failure_context" && -n "$(echo "$failure_context" | tr -d '[:space:]')" ]]; then
        if [[ -n "$output" ]]; then
            output+=$'\n'
        fi
        output+="Failure Context (avoid repeating these mistakes):"
        output+=$'\n'
        output+="$failure_context"
    fi
```

### Handle Iteration Failure with Learning Extraction
```bash
# Source: Extension of handle_iteration_failure_state in ralph.sh
handle_iteration_failure_state() {
    local iteration_num="$1"
    local task="$2"
    local error="$3"
    local duration="$4"
    local output_file="${5:-}"

    # Log the iteration (existing)
    log_iteration "$iteration_num" "FAILURE" "$task" "$error" "$duration"
    add_iteration_entry "$iteration_num" "FAILURE" "$task: $error"

    # NEW: Extract and store failure learning
    if type extract_and_store_failure &>/dev/null; then
        extract_and_store_failure "$task" "$output_file" "$error"
    fi
}
```

### Complete Failure Extraction and Storage
```bash
# Source: New function combining extraction and storage
extract_and_store_failure() {
    local task_id="$1"
    local output_file="$2"
    local error_msg="$3"

    # Extract detailed failure info from Claude's output
    local failure_reason
    failure_reason=$(extract_failure_reason "$output_file")

    # Extract what was attempted (look for last action in result)
    local attempted
    attempted=$(extract_attempted_action "$output_file")

    # Extract relevant file paths mentioned
    local files
    files=$(extract_mentioned_files "$output_file")

    # Build context from error message and failure reason
    local context
    if [[ -n "$failure_reason" && "$failure_reason" != "$error_msg" ]]; then
        context="$failure_reason"
    else
        context="$error_msg"
    fi

    # Store the failure learning
    append_failure_learning "$task_id" "$error_msg" "$attempted" "$files" "$context"
}
```

### Detecting Phase Completion for Cleanup
```bash
# Source: Adaptation of get_next_plan_after logic
check_phase_complete() {
    local current_task="$1"
    local next_task="$2"

    if [[ -z "$current_task" || -z "$next_task" ]]; then
        return 1
    fi

    local current_phase="${current_task%%-*}"
    local next_phase="${next_task%%-*}"

    # Remove leading zeros
    current_phase=$((10#$current_phase))
    if [[ "$next_task" == "COMPLETE" ]]; then
        return 0  # Phase complete (all done)
    fi
    next_phase=$((10#$next_phase))

    # Phase changed = previous phase complete
    if [[ "$next_phase" -gt "$current_phase" ]]; then
        return 0
    fi

    return 1
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No failure context | Store errors in history | Phase 5 | Errors logged but not used for learning |
| Failures lost between sessions | Persistent AGENTS.md | Phase 7 | Learnings survive restarts |
| Fixed retry prompts | Context-aware retries | This phase | Retries avoid repeated mistakes |

**Current codebase state:**
- Phase 7 established AGENTS.md with Error Fixes, Codebase Patterns, Phase-Specific sections
- learnings.sh has init, get_learnings_for_phase, append_learning, extract_learnings_from_summary
- invoke.sh builds prompts with learnings from get_learnings_for_phase
- ralph.sh calls extract_learnings_from_summary after SUCCESS

**What this phase adds:**
- Failure Context section in AGENTS.md
- extract_failure_reason for parsing Claude JSON output
- append_failure_learning for structured failure storage
- clear_phase_failures for cleanup on phase completion
- Extended get_learnings_for_phase to include failure context

## Open Questions

Things that couldn't be fully resolved:

1. **Structured marker format for Claude to output**
   - What we know: CONTEXT.md says use `FAILURE_REASON: ...` markers
   - What's unclear: Should we prompt Claude to output these, or detect failure from its natural output?
   - Recommendation: Try structured markers first, fall back to pattern detection

2. **When exactly to clear individual task failures**
   - What we know: CONTEXT.md marks this as Claude's discretion
   - What's unclear: Clear on task retry success vs keep until phase end
   - Recommendation: Keep until phase end (simpler, provides more context for pattern detection)

3. **Handling very long error output**
   - What we know: 256k context window is generous
   - What's unclear: Should extremely long errors be summarized?
   - Recommendation: Truncate at 500 chars for error field, but keep full context in dedicated field

4. **Organization within Failure Context section**
   - What we know: CONTEXT.md marks this as Claude's discretion
   - What's unclear: Chronological vs grouped by task
   - Recommendation: Chronological (newest last) for simplicity, grouped by phase via subsections

## Sources

### Primary (HIGH confidence)
- Existing learnings.sh implementation - Direct codebase reference
- Existing recovery.sh get_recent_failures - Pattern for failure extraction from state
- Existing parse_claude_output - Pattern for JSON parsing with jq/fallback
- Phase 7 research (07-RESEARCH.md) - Established patterns for AGENTS.md

### Secondary (MEDIUM confidence)
- Claude CLI --output-format json documentation - Verified via --help output
- Existing state.sh update_section - Pattern for marker-based section manipulation

### Tertiary (LOW confidence)
- General patterns for error handling in bash - Informational, verified against codebase patterns

## Metadata

**Confidence breakdown:**
- Failure extraction approach: HIGH - Builds on proven parse_claude_output pattern
- Storage in AGENTS.md: HIGH - Direct extension of existing learnings.sh
- Phase boundary cleanup: MEDIUM - Logic is clear, timing of cleanup needs verification
- Prompt injection: HIGH - Uses existing get_learnings_for_phase mechanism
- 100-failure cap: MEDIUM - Per CONTEXT.md decision, implementation straightforward

**Research date:** 2026-01-20
**Valid until:** 60 days (extends stable codebase patterns)
