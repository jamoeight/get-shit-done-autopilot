# Phase 2: State Extensions - Research

**Researched:** 2026-01-19
**Domain:** State file persistence, iteration tracking, progress display, markdown manipulation
**Confidence:** HIGH

## Summary

Phase 2 extends STATE.md to track iteration state and show progress across autonomous execution. Fresh Claude instances read STATE.md to know exactly where to resume. The key challenges are: designing a schema that's both human-readable and machine-parseable, updating specific sections atomically without corrupting the file, implementing a rolling window that keeps STATE.md fast while archiving history, and displaying progress that accurately reflects plan completion.

The implementation approach uses proven patterns from Phase 1:
- **Iteration tracking:** Append-style logging in a dedicated section, with structured format (timestamp, outcome, task name)
- **Progress bar:** ASCII text format `[##########          ] 40%` matching user specification
- **Rolling window:** Keep last 10-15 entries in STATE.md, archive older entries at phase boundaries
- **Atomic updates:** Write-to-temp-then-rename pattern prevents corruption on crash
- **Section manipulation:** Use marker-based sed/awk patterns to update specific sections

**Primary recommendation:** Design STATE.md with clearly delineated sections using markdown headers as markers. Each section has a defined format that both humans can read and bash scripts can parse with simple regex. Use atomic write pattern for all updates.

## Standard Stack

The established patterns for this phase:

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash | 4.0+ | Script runtime | Cross-platform via Git Bash, zero dependencies |
| `sed` | GNU | Section extraction/update | Standard Unix text processing |
| `awk` | GNU | Structured parsing | Line-oriented, state-aware processing |
| `date` | GNU | Timestamp generation | ISO 8601 format support |
| `mktemp` | coreutils | Safe temp files | Avoids race conditions |
| `mv` | coreutils | Atomic rename | File system atomic operation |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `grep` | Pattern matching | Quick section existence checks |
| `wc` | Line counting | History depth checking |
| `tail`/`head` | Rolling window | Keep N most recent entries |
| `printf` | Formatted output | Progress bar character generation |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| sed/awk parsing | JSON state file | JSON adds parsing complexity, less human-readable |
| Markdown sections | YAML frontmatter | Markdown headers are simpler, already used in GSD |
| Rolling window in file | SQLite database | Overkill, loses human readability |

**Installation:**
No new dependencies required. Uses standard Unix tools available in Git Bash on Windows.

## Architecture Patterns

### Recommended STATE.md Structure

```markdown
# Project State

## Current Position
Phase: 2 of 10 (State Extensions)
Plan: 1 of 2 in current phase
Status: In progress
Last activity: 2026-01-19 14:32:05

Progress: [######################          ] 65%

## Next Action
Command: /gsd:execute-phase 2
Description: Execute plan 02-02 (Progress indicator implementation)
Read: ROADMAP.md, 02-02-PLAN.md

## Iteration History
<!-- HISTORY_START -->
| # | Timestamp | Outcome | Task |
|---|-----------|---------|------|
| 15 | 2026-01-19 14:32:05 | SUCCESS | 02-01: STATE.md schema extensions |
| 14 | 2026-01-19 14:28:12 | SUCCESS | 01-02: Fail-fast error handling |
| 13 | 2026-01-19 14:24:33 | RETRY | 01-02: Fail-fast error handling |
...
<!-- HISTORY_END -->

## Accumulated Context
...existing sections...
```

### Pattern 1: Section-Based Updates with Markers

**What:** Use HTML comments as markers to define updatable regions.
**When to use:** Any section that needs programmatic updates.
**Why:** HTML comments are invisible in rendered markdown but easily matched by regex.

**Example:**
```bash
# Source: sed marker-based processing
# https://learnbyexample.github.io/learn_gnused/processing-lines-bounded-by-distinct-markers.html

update_section() {
    local file="$1"
    local start_marker="$2"
    local end_marker="$3"
    local new_content="$4"

    # Create temp file
    local temp_file
    temp_file=$(mktemp)

    # Replace content between markers
    awk -v start="$start_marker" -v end="$end_marker" -v content="$new_content" '
        $0 ~ start { print; print content; skip=1; next }
        $0 ~ end { skip=0 }
        !skip { print }
    ' "$file" > "$temp_file"

    # Atomic replace
    mv "$temp_file" "$file"
}

# Usage
update_section "STATE.md" "<!-- HISTORY_START -->" "<!-- HISTORY_END -->" "$new_history"
```

### Pattern 2: Atomic File Write

**What:** Write to temp file, then atomic rename to target.
**When to use:** Every STATE.md update.
**Why:** Prevents file corruption if script crashes or power is lost mid-write.

**Example:**
```bash
# Source: linuxvox atomic file creation
# https://linuxvox.com/blog/atomic-create-file-if-not-exists-from-bash-script/

atomic_write() {
    local target="$1"
    local content="$2"

    # Create temp file in same directory (same filesystem for atomic mv)
    local temp_file="${target}.tmp.$$"

    # Write content
    printf '%s' "$content" > "$temp_file"

    # Sync to disk (optional but safer)
    sync "$temp_file" 2>/dev/null || true

    # Atomic rename
    mv "$temp_file" "$target"
}
```

### Pattern 3: Rolling Window History

**What:** Keep last N entries in STATE.md, move older to archive.
**When to use:** At phase boundaries (when starting a new phase).
**Why:** Keeps STATE.md fast for fresh Claude instances while preserving full history.

**Example:**
```bash
# Keep last 15 iterations in STATE.md
HISTORY_WINDOW=15

rotate_history() {
    local state_file="$1"
    local archive_file="$2"

    # Extract history section
    local history
    history=$(sed -n '/<!-- HISTORY_START -->/,/<!-- HISTORY_END -->/p' "$state_file" |
              grep -E '^\| [0-9]')

    # Count entries
    local count
    count=$(echo "$history" | wc -l)

    if [ "$count" -gt "$HISTORY_WINDOW" ]; then
        # Entries to archive (oldest first)
        local archive_count=$((count - HISTORY_WINDOW))
        local to_archive
        to_archive=$(echo "$history" | tail -n "$archive_count")

        # Append to archive with phase header
        echo "" >> "$archive_file"
        echo "## Phase Boundary: $(date -Iseconds)" >> "$archive_file"
        echo "$to_archive" >> "$archive_file"

        # Keep only recent in STATE.md
        local to_keep
        to_keep=$(echo "$history" | head -n "$HISTORY_WINDOW")

        # Update STATE.md (using update_section from Pattern 1)
        update_history_section "$state_file" "$to_keep"
    fi
}
```

### Pattern 4: ASCII Progress Bar

**What:** Text-based progress bar using filled/empty block characters.
**When to use:** Display in STATE.md and terminal output.
**Why:** User specified `[########          ] 40%` format.

**Example:**
```bash
# Source: Shell progress bar patterns
# https://www.linuxjournal.com/content/how-add-simple-progress-bar-shell-script

generate_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-30}"  # Default 30 characters

    # Calculate percentage
    local percent=$((current * 100 / total))

    # Calculate filled width
    local filled=$((current * width / total))
    local empty=$((width - filled))

    # Generate bar using Unicode block characters for compatibility
    # Alternative ASCII: use '#' and ' '
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="#"; done
    for ((i=0; i<empty; i++)); do bar+=" "; done

    printf '[%s] %d%%' "$bar" "$percent"
}

# Usage
# Plans completed: 15 of 26
progress=$(generate_progress_bar 15 26)
# Output: [#################             ] 57%
```

### Pattern 5: Structured Iteration Entry

**What:** Format each iteration outcome as parseable table row.
**When to use:** After each iteration completes.
**Why:** Table format is human-readable and easily parsed with awk.

**Example:**
```bash
# Entry format: | iteration_num | timestamp | outcome | task_name |

format_iteration_entry() {
    local iteration="$1"
    local outcome="$2"        # SUCCESS, FAILURE, RETRY
    local task_name="$3"

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    printf '| %d | %s | %s | %s |' "$iteration" "$timestamp" "$outcome" "$task_name"
}

# Categories (per user context - Claude's discretion):
# SUCCESS - Task completed successfully
# FAILURE - Task failed after all retries
# RETRY   - Task failed, retrying
# SKIPPED - Task skipped (dependency failed)
```

### Pattern 6: Resume Information Block

**What:** Machine-readable block at top with command-ready next action.
**When to use:** Every STATE.md update.
**Why:** Fresh Claude instance can immediately see what to do next.

**Example:**
```bash
# Resume block format (per user decisions):
# - Show BOTH current position AND next action
# - Command-ready format that could be pasted
# - Explicit file list for context

generate_resume_block() {
    local phase_num="$1"
    local plan_num="$2"
    local plan_name="$3"

    cat << EOF
## Next Action
Command: /gsd:execute-phase ${phase_num}
Description: Execute plan ${plan_num} (${plan_name})
Read: ROADMAP.md, ${plan_num}-PLAN.md
EOF
}
```

### Anti-Patterns to Avoid

- **Parsing markdown with regex alone:** Use markers for section boundaries; markdown syntax varies
- **In-place file editing without backup:** Always use atomic write pattern
- **Storing full error details in STATE.md:** Keep it concise; log details to separate file
- **Unbounded history growth:** Use rolling window; archive at phase boundaries
- **Progress based on iterations:** Use plans completed, not iteration count (per user decision)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Section extraction | Custom parser | `sed -n '/start/,/end/p'` | Proven, handles edge cases |
| Atomic file write | Direct overwrite | mktemp + mv | Prevents corruption on crash |
| Timestamp formatting | Manual printf | `date '+%Y-%m-%d %H:%M:%S'` | Locale-aware, standard format |
| Line counting | Manual loop | `wc -l` | Faster, handles edge cases |
| Table row parsing | Custom split | `awk -F'|'` | Handles whitespace correctly |
| Progress calculation | Manual division | Shell arithmetic `$((a * 100 / b))` | Integer math is sufficient |

**Key insight:** The challenge isn't any single operation - it's combining them correctly. Use proven patterns for each piece, focus on correct integration.

## Common Pitfalls

### Pitfall 1: Corrupted STATE.md on Crash

**What goes wrong:** Script crashes mid-write, STATE.md is truncated or empty.
**Why it happens:** Direct file overwrite is not atomic; OS can flush partial content.
**How to avoid:** Always use write-to-temp-then-rename pattern.
**Warning signs:** STATE.md shorter than expected, parse errors on resume.

```bash
# Bad: Direct overwrite
echo "$content" > STATE.md

# Good: Atomic write
temp=$(mktemp)
echo "$content" > "$temp"
mv "$temp" STATE.md
```

### Pitfall 2: Marker Mismatch

**What goes wrong:** Section update replaces wrong content or entire file.
**Why it happens:** Markers not unique, regex too greedy.
**How to avoid:** Use HTML comments with unique identifiers: `<!-- SECTION_NAME_START -->`.
**Warning signs:** Content appearing in wrong sections, lost data.

### Pitfall 3: Progress Bar Calculation Errors

**What goes wrong:** Progress shows 0% when work done, or >100%.
**Why it happens:** Integer division truncation, off-by-one errors.
**How to avoid:** Test edge cases: 0/10, 1/10, 9/10, 10/10.
**Warning signs:** "Progress: [                              ] 0%" when plans are complete.

```bash
# Handle edge case: 0 total plans
if [ "$total" -eq 0 ]; then
    percent=0
else
    percent=$((current * 100 / total))
fi
```

### Pitfall 4: Rolling Window Off-By-One

**What goes wrong:** History shows 14 or 16 entries instead of 15.
**Why it happens:** Fence-post errors in tail/head commands.
**How to avoid:** Test with exactly N, N+1, N-1 entries.
**Warning signs:** History section grows or shrinks unexpectedly.

### Pitfall 5: Timestamp Timezone Issues

**What goes wrong:** Timestamps inconsistent across machines or sessions.
**Why it happens:** Using local time without timezone, different machines have different TZ.
**How to avoid:** Use ISO 8601 format with timezone, or just use local time consistently.
**Warning signs:** Timestamps appear out of order when they shouldn't be.

```bash
# Recommended: Include timezone
date '+%Y-%m-%d %H:%M:%S %Z'  # 2026-01-19 14:32:05 EST

# Or use UTC
date -u '+%Y-%m-%dT%H:%M:%SZ'  # 2026-01-19T19:32:05Z
```

### Pitfall 6: Archive File Grows Without Bound

**What goes wrong:** iteration-history.md becomes huge over many milestones.
**Why it happens:** Archive append without cleanup.
**How to avoid:** Document that git preserves full history; archive is working memory, can be truncated.
**Warning signs:** Archive file >1MB, slow to open.

## Code Examples

Verified patterns from research:

### Complete STATE.md Update Function

```bash
# Source: Combined from Phase 1 patterns + atomic write research

#!/bin/bash
# state-update.sh - Functions for STATE.md manipulation

STATE_FILE=".planning/STATE.md"
ARCHIVE_FILE=".planning/iteration-history.md"
HISTORY_WINDOW=15

# Atomic write helper
atomic_write() {
    local target="$1"
    local content="$2"
    local temp="${target}.tmp.$$"

    printf '%s' "$content" > "$temp"
    mv "$temp" "$target"
}

# Update a section between markers
update_section() {
    local start_marker="$1"
    local end_marker="$2"
    local new_content="$3"

    local temp
    temp=$(mktemp)

    awk -v start="$start_marker" -v end="$end_marker" -v content="$new_content" '
        BEGIN { in_section = 0 }
        $0 ~ start {
            print
            print content
            in_section = 1
            next
        }
        $0 ~ end {
            in_section = 0
        }
        !in_section { print }
    ' "$STATE_FILE" > "$temp"

    mv "$temp" "$STATE_FILE"
}

# Add iteration entry
add_iteration_entry() {
    local iteration="$1"
    local outcome="$2"
    local task="$3"

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="| $iteration | $timestamp | $outcome | $task |"

    # Get existing history (without table header)
    local existing
    existing=$(sed -n '/<!-- HISTORY_START -->/,/<!-- HISTORY_END -->/{
        /<!-- HISTORY/d
        /^| #/d
        /^|---/d
        p
    }' "$STATE_FILE")

    # Prepend new entry (newest first)
    local new_history="| # | Timestamp | Outcome | Task |
|---|-----------|---------|------|
$entry
$existing"

    update_section "<!-- HISTORY_START -->" "<!-- HISTORY_END -->" "$new_history"
}

# Update progress bar
update_progress() {
    local completed="$1"
    local total="$2"

    local bar
    bar=$(generate_progress_bar "$completed" "$total" 30)

    # Update the Progress: line
    sed -i "s/^Progress: \[.*\] [0-9]*%$/Progress: $bar/" "$STATE_FILE"
}

# Generate progress bar
generate_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-30}"

    if [ "$total" -eq 0 ]; then
        printf '[%*s] 0%%' "$width" ""
        return
    fi

    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="#"; done
    for ((i=0; i<empty; i++)); do bar+=" "; done

    printf '[%s] %d%%' "$bar" "$percent"
}
```

### Complete Resume Block Update

```bash
# Update next action block for fresh instance resumption

update_next_action() {
    local phase="$1"
    local plan="$2"
    local plan_name="$3"
    local status="$4"  # "In progress" or "Ready to execute"
    local last_failure="${5:-}"  # Optional: highlight if resuming after failure

    local next_action
    if [ -n "$last_failure" ]; then
        next_action="## Next Action
Command: /gsd:execute-phase $phase
Description: Execute plan $plan ($plan_name)
Read: ROADMAP.md, $plan-PLAN.md

**Note:** Previous iteration failed on this task. See history for details."
    else
        next_action="## Next Action
Command: /gsd:execute-phase $phase
Description: Execute plan $plan ($plan_name)
Read: ROADMAP.md, $plan-PLAN.md"
    fi

    # Update Current Position section too
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local position="## Current Position
Phase: $phase of 10 ($(get_phase_name "$phase"))
Plan: $(get_plan_index "$plan") of $(get_phase_plan_count "$phase") in current phase
Status: $status
Last activity: $timestamp"

    # These would use update_section pattern
    # For now, demonstrate structure
    echo "$position"
    echo ""
    echo "$next_action"
}
```

### History Rotation at Phase Boundary

```bash
# Called when transitioning to new phase

rotate_history_at_phase_boundary() {
    local current_phase="$1"

    # Extract entries from STATE.md
    local entries
    entries=$(sed -n '/<!-- HISTORY_START -->/,/<!-- HISTORY_END -->/{
        /^| [0-9]/p
    }' "$STATE_FILE")

    local count
    count=$(echo "$entries" | grep -c '^|' || echo 0)

    if [ "$count" -gt "$HISTORY_WINDOW" ]; then
        local archive_count=$((count - HISTORY_WINDOW))

        # Archive oldest entries (they're at bottom since newest first)
        local to_archive
        to_archive=$(echo "$entries" | tail -n "$archive_count")

        # Append to archive with boundary marker
        {
            echo ""
            echo "## Phase $current_phase Boundary - $(date '+%Y-%m-%d %H:%M:%S')"
            echo ""
            echo "| # | Timestamp | Outcome | Task |"
            echo "|---|-----------|---------|------|"
            echo "$to_archive"
        } >> "$ARCHIVE_FILE"

        # Keep only recent in STATE.md
        local to_keep
        to_keep=$(echo "$entries" | head -n "$HISTORY_WINDOW")

        local new_history="| # | Timestamp | Outcome | Task |
|---|-----------|---------|------|
$to_keep"

        update_section "<!-- HISTORY_START -->" "<!-- HISTORY_END -->" "$new_history"

        echo "Archived $archive_count entries to $ARCHIVE_FILE"
    fi
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| JSON state files | Markdown with markers | 2024-2025 | Human-readable + machine-parseable |
| Unbounded history | Rolling window + archive | Standard practice | Keeps context small for fresh instances |
| Progress by iterations | Progress by plans completed | User decision | More meaningful metric |
| Direct file writes | Atomic write pattern | Standard practice | Crash-safe persistence |

**Current trends:**
- AGENTS.md emerging as standard for AI agent configuration
- Markdown-based state preferred over JSON/YAML for AI tools
- Context size management critical for fresh instance performance

## Open Questions

Things that couldn't be fully resolved:

1. **Consecutive failure display**
   - What we know: User marked as "Claude's discretion"
   - Options: Collapsed with count ("3x RETRY on task X") vs separate entries
   - Recommendation: Start with separate entries (simpler), can add collapse later if needed

2. **Failure categorization**
   - What we know: User marked as "Claude's discretion"
   - Options: Simple (SUCCESS/FAILURE/RETRY) vs detailed (TASK_FAILURE/SYSTEM_ERROR/TIMEOUT)
   - Recommendation: Start simple, add categories if patterns emerge

3. **Progress bar placement**
   - What we know: User marked as "Claude's discretion"
   - Options: In Current Position section, separate Progress section, header
   - Recommendation: In Current Position section, after "Last activity" line

4. **Highlighting last failure for resume**
   - What we know: User marked as "Claude's discretion"
   - Options: Note in Next Action, bold in history, separate "Recovery" section
   - Recommendation: Add note in Next Action section when resuming after failure

## Sources

### Primary (HIGH confidence)
- [GNU sed Manual - Bounded Markers](https://learnbyexample.github.io/learn_gnused/processing-lines-bounded-by-distinct-markers.html) - Section processing patterns
- [LinuxVox - Atomic File Creation](https://linuxvox.com/blog/atomic-create-file-if-not-exists-from-bash-script/) - Write-then-rename pattern
- [GNU awk Tutorial](https://www.grymoire.com/Unix/Awk.html) - State-aware line processing
- [Linux Journal - Progress Bar](https://www.linuxjournal.com/content/how-add-simple-progress-bar-shell-script) - ASCII progress patterns

### Secondary (MEDIUM confidence)
- [Better Stack - Logrotate Guide](https://betterstack.com/community/guides/logging/how-to-manage-log-files-with-logrotate-on-ubuntu-20-04/) - Rolling window concepts
- [AGENTS.md Specification](https://agents.md/) - AI agent configuration patterns
- [Baeldung - sed Replace Next Line](https://www.baeldung.com/linux/find-matching-text-replace-next-line) - Advanced sed patterns

### Tertiary (LOW confidence)
- [DEV.to - Crash-safe JSON](https://dev.to/constanta/crash-safe-json-at-scale-atomic-writes-recovery-without-a-db-3aic) - Atomic write concepts (verified with official sources)

## Metadata

**Confidence breakdown:**
- STATE.md schema: HIGH - Builds on existing GSD patterns, markdown is well-understood
- Progress bar: HIGH - Standard ASCII patterns, user specified format
- Section updates: HIGH - sed/awk patterns are proven, marker-based approach is reliable
- Atomic writes: HIGH - Standard Unix practice, well-documented
- Rolling window: MEDIUM - Implementation straightforward, edge cases need testing
- Archive rotation: MEDIUM - Logic is simple but timing (phase boundary) needs integration

**Research date:** 2026-01-19
**Valid until:** 60 days (stable patterns, bash/Unix tools don't change)
