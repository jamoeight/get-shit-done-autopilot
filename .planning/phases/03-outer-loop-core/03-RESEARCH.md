# Phase 3: Outer Loop Core - Research

**Researched:** 2026-01-19
**Domain:** Bash scripting, Claude Code CLI, cross-platform compatibility
**Confidence:** HIGH

## Summary

This research covers implementing ralph.sh - a bash script that automates GSD plan execution by spawning fresh Claude Code instances. The script reads STATE.md to determine the next task, invokes Claude with full GSD context via CLI, parses JSON output, updates state, and loops until completion or budget cap.

The Claude Code CLI provides excellent non-interactive support via `-p` (print) flag with `--output-format json` for structured parsing. System prompt customization via `--append-system-prompt` or `--append-system-prompt-file` allows passing GSD context while preserving Claude's built-in capabilities. Cross-platform compatibility requires attention to line endings, file paths, and POSIX-compliant bash features.

**Primary recommendation:** Use `claude -p` with `--output-format json` and `--append-system-prompt-file` for reliable non-interactive execution with full GSD context. Implement NO_COLOR support and use ASCII-only spinner characters for cross-platform compatibility.

## Standard Stack

The core technology is bash scripting with Claude Code CLI. No external dependencies required.

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Bash | 4.x+ | Script runtime | Pre-installed on Unix, available via Git Bash on Windows |
| Claude Code CLI | Latest | LLM invocation | Official Anthropic CLI, supports non-interactive mode |
| jq | 1.6+ | JSON parsing | De facto standard for bash JSON processing |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| date | Timestamps for logging | Every iteration for log entries |
| mktemp | Temp file creation | Store Claude JSON output safely |
| tput | Terminal capability detection | Color support check (optional) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| jq | grep/sed | jq is cleaner but requires installation; sed works everywhere |
| bash arrays | temp files | Arrays more elegant but Git Bash array support varies |

**Installation:**
```bash
# jq (optional - can parse JSON with grep/sed fallback)
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows (via Git Bash with scoop)
scoop install jq
```

**Note:** jq is optional. The script should include a fallback using grep/sed for environments without jq.

## Architecture Patterns

### Recommended Project Structure
```
bin/
├── ralph.sh               # Main entry point (this phase)
├── lib/
│   ├── budget.sh          # Budget configuration (Phase 1, exists)
│   ├── display.sh         # Progress display (Phase 1, exists)
│   ├── failfast.sh        # Error handling (Phase 1, exists)
│   ├── state.sh           # State management (Phase 2, exists)
│   ├── parse.sh           # STATE.md parsing (new, this phase)
│   └── invoke.sh          # Claude CLI wrapper (new, this phase)
```

### Pattern 1: Main Loop Structure
**What:** Top-level iteration control with budget checking and state reading
**When to use:** Entry point for ralph.sh
**Example:**
```bash
#!/bin/bash
# Source: Derived from existing lib structure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/budget.sh"
source "${SCRIPT_DIR}/lib/state.sh"
source "${SCRIPT_DIR}/lib/display.sh"
source "${SCRIPT_DIR}/lib/failfast.sh"

# Load configuration
load_config

# Initialize timing
START_TIME=$(date +%s)

# Main loop
iteration=0
while true; do
    iteration=$((iteration + 1))

    # Check budget limits
    if ! check_limits "$iteration"; then
        handle_limit_reached
        exit 1
    fi

    # Parse next task from STATE.md
    next_task=$(parse_next_task)
    if [[ -z "$next_task" || "$next_task" == "COMPLETE" ]]; then
        show_status "All tasks complete!" "success"
        break
    fi

    # Show running indicator
    start_spinner "[$iteration/$MAX_ITERATIONS] Running ${next_task}..."

    # Invoke Claude
    result=$(invoke_claude "$next_task")
    exit_code=$?

    stop_spinner

    # Handle result
    if [[ $exit_code -ne 0 ]]; then
        handle_iteration_failure "$next_task" "$result"
    else
        handle_iteration_success "$next_task" "$result"
    fi
done
```

### Pattern 2: Claude CLI Invocation
**What:** Non-interactive Claude execution with JSON output
**When to use:** Each iteration to execute a plan
**Example:**
```bash
# Source: https://code.claude.com/docs/en/headless

invoke_claude() {
    local task="$1"
    local phase_num plan_id

    # Extract phase and plan from task identifier
    phase_num=$(echo "$task" | cut -d'-' -f1)
    plan_id="$task"

    # Build the prompt
    local prompt="Execute plan ${plan_id} of phase ${phase_num}.

Read the plan file at .planning/phases/${phase_num}-*/${plan_id}-PLAN.md
Follow the execute-plan workflow.
Commit each task atomically.
Create SUMMARY.md when complete.
Update STATE.md with position and decisions."

    # Create temp file for output
    local output_file
    output_file=$(mktemp)

    # Invoke Claude with full context
    claude -p "$prompt" \
        --output-format json \
        --append-system-prompt-file "${GSD_CONTEXT_FILE}" \
        --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
        > "$output_file" 2>&1

    local exit_code=$?

    # Parse and return result
    if [[ $exit_code -eq 0 ]]; then
        cat "$output_file"
    else
        echo "ERROR: Claude invocation failed with exit code $exit_code" >&2
        cat "$output_file" >&2
    fi

    rm -f "$output_file"
    return $exit_code
}
```

### Pattern 3: STATE.md Parsing
**What:** Extract next task from STATE.md Next Action section
**When to use:** Beginning of each iteration
**Example:**
```bash
# Source: Derived from STATE.md structure

parse_next_task() {
    local state_file="${STATE_FILE:-.planning/STATE.md}"

    if [[ ! -f "$state_file" ]]; then
        echo "ERROR" >&2
        return 1
    fi

    # Extract "Description: Execute plan XX-YY" line
    local description
    description=$(grep "^Description: Execute plan" "$state_file" | head -1)

    if [[ -z "$description" ]]; then
        # No next action - might be complete
        echo "COMPLETE"
        return 0
    fi

    # Extract plan ID (e.g., "03-01")
    local plan_id
    plan_id=$(echo "$description" | grep -oE '[0-9]+-[0-9]+' | head -1)

    echo "$plan_id"
    return 0
}
```

### Pattern 4: NO_COLOR Support
**What:** Respect terminal color preferences
**When to use:** All terminal output
**Example:**
```bash
# Source: https://no-color.org/

# Check for NO_COLOR at startup
if [[ -n "${NO_COLOR:-}" ]]; then
    # Disable all color codes
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    BOLD=''
    RESET=''
else
    RED='\e[31m'
    GREEN='\e[32m'
    YELLOW='\e[33m'
    CYAN='\e[36m'
    BOLD='\e[1m'
    RESET='\e[0m'
fi
```

### Pattern 5: Cross-Platform Spinner
**What:** Background spinner process with ASCII characters
**When to use:** While Claude is executing
**Example:**
```bash
# Source: https://willcarh.art/blog/how-to-write-better-bash-spinners

SPINNER_PID=""

start_spinner() {
    local message="$1"

    # Use ASCII-only characters for Git Bash compatibility
    local spin_chars='|/-\'

    # Disable job control messages
    set +m

    {
        local i=0
        while true; do
            local char="${spin_chars:$i:1}"
            printf "\r${CYAN}%s %s${RESET}" "$message" "$char"
            i=$(( (i + 1) % 4 ))
            sleep 0.25
        done
    } &

    SPINNER_PID=$!

    # Re-enable job control
    set -m
}

stop_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null
        SPINNER_PID=""
        # Clear the spinner line
        printf "\r\033[2K"
    fi
}

# Ensure cleanup on exit
trap stop_spinner EXIT
```

### Anti-Patterns to Avoid
- **Polling loops for Claude status:** Claude CLI blocks until complete; don't poll
- **Using `git add .`:** Always stage files individually to avoid accidental commits
- **Hardcoding paths:** Use variables for all paths for cross-platform compatibility
- **Ignoring exit codes:** Always check `$?` after Claude invocation
- **Using bash-only features:** Avoid `[[` extended tests, prefer `[` for POSIX compatibility where possible

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in bash | Custom grep/awk chains | jq | Edge cases: nested objects, escaped quotes, arrays |
| Terminal spinner | Custom animation loop | Pattern above with trap | Cleanup on error/interrupt requires careful handling |
| Atomic file writes | Direct echo to file | atomic_write from state.sh | Crash safety, temp file pattern |
| Progress bar | Custom calculation | generate_progress_bar from state.sh | Already implemented with correct width/format |
| Color output | Hardcoded escape codes | Pattern with NO_COLOR check | Accessibility, user preference respect |

**Key insight:** The existing lib/ files (state.sh, display.sh, failfast.sh, budget.sh) already implement most utility functions. ralph.sh should compose these, not duplicate.

## Common Pitfalls

### Pitfall 1: Git Bash Path Handling
**What goes wrong:** Scripts fail on Windows because paths use backslashes or drive letters differ
**Why it happens:** Git Bash translates paths inconsistently; `C:\Users` becomes `/c/Users`
**How to avoid:**
- Use relative paths from project root wherever possible
- Use `$(pwd)` or `$PWD` for current directory
- Avoid hardcoded absolute paths
**Warning signs:** Scripts work on Unix but fail on Windows with "file not found"

### Pitfall 2: Line Ending Issues
**What goes wrong:** Scripts fail to execute or produce strange output on Windows
**Why it happens:** Windows uses CRLF (`\r\n`), Unix uses LF (`\n`)
**How to avoid:**
- Configure git: `git config core.autocrlf input` (on Unix) or `true` (on Windows)
- Add `.gitattributes` with `*.sh text eol=lf`
- Use editors that preserve LF endings
**Warning signs:** `^M` characters in error messages, "bad interpreter" errors

### Pitfall 3: Claude CLI Output Parsing
**What goes wrong:** JSON parsing fails or extracts wrong fields
**Why it happens:** Claude output format varies; errors may not be JSON
**How to avoid:**
- Always check exit code before parsing
- Handle non-JSON error output separately
- Use jq's `-e` flag to fail on null/missing fields
**Warning signs:** Empty variables, "null" strings, parse errors

### Pitfall 4: Background Process Cleanup
**What goes wrong:** Spinner process continues running after script exits
**Why it happens:** `trap` not set up, or uses wrong signal
**How to avoid:**
- Always `trap stop_spinner EXIT`
- Kill with `kill -9` if needed
- Use `wait` to prevent zombie processes
**Warning signs:** Orphan processes, terminal corruption after Ctrl+C

### Pitfall 5: Variable Scope in Subshells
**What goes wrong:** Variables set in loops/pipes aren't visible outside
**Why it happens:** Pipes create subshells; variables don't export back
**How to avoid:**
- Use process substitution: `while read line; do ...; done < <(command)`
- Or use temp files instead of pipes
- Or use `lastpipe` shell option (bash 4.2+)
**Warning signs:** Variables mysteriously empty after loops

### Pitfall 6: Iteration Timeout Without Hard Kill
**What goes wrong:** Claude hangs indefinitely, burning context/time
**Why it happens:** No timeout mechanism on the Claude CLI call
**How to avoid:**
- Log alert after 30 minutes (per user decision - no hard timeout)
- Consider `timeout` command for future hard timeout option
- Track iteration start time for alerting
**Warning signs:** Single iteration taking hours

## Code Examples

Verified patterns from official sources and existing codebase:

### Claude CLI JSON Output Parsing
```bash
# Source: https://code.claude.com/docs/en/headless

# Invoke and capture output
output=$(claude -p "query" --output-format json)

# Parse with jq (if available)
if command -v jq &>/dev/null; then
    result=$(echo "$output" | jq -r '.result // empty')
    session_id=$(echo "$output" | jq -r '.session_id // empty')
else
    # Fallback: grep for result field (simplified)
    result=$(echo "$output" | grep -oP '"result"\s*:\s*"\K[^"]+')
fi
```

### Startup Configuration Display
```bash
# Source: Context requirement for iteration feedback

show_startup_summary() {
    echo -e "${BOLD}${CYAN}=== Ralph Outer Loop ===${RESET}"
    echo ""
    echo -e "Config: ${GREEN}$MAX_ITERATIONS iterations${RESET}, ${GREEN}${TIMEOUT_HOURS}h timeout${RESET}"

    # Parse current position from STATE.md
    local phase plan status
    phase=$(grep "^Phase:" "$STATE_FILE" | head -1 | sed 's/Phase: //')
    plan=$(grep "^Plan:" "$STATE_FILE" | head -1 | sed 's/Plan: //')
    status=$(grep "^Status:" "$STATE_FILE" | head -1 | sed 's/Status: //')

    echo -e "Position: Phase ${phase}, Plan ${plan}"
    echo -e "Status: ${status}"

    # Show next task
    local next_task
    next_task=$(parse_next_task)
    echo -e "Next: ${YELLOW}${next_task}${RESET}"
    echo ""
}
```

### Log File Append Pattern
```bash
# Source: Context requirement for logging

LOG_FILE="${LOG_FILE:-.planning/ralph.log}"

log_iteration() {
    local iteration="$1"
    local status="$2"
    local task="$3"
    local summary="$4"
    local duration="$5"

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Append to log file (create if not exists)
    {
        echo "---"
        echo "Iteration: $iteration"
        echo "Timestamp: $timestamp"
        echo "Task: $task"
        echo "Status: $status"
        echo "Duration: ${duration}s"
        echo "Summary: $summary"
    } >> "$LOG_FILE"
}
```

### Failure Pause with Options
```bash
# Source: Context requirement for pause on failure

handle_iteration_failure() {
    local task="$1"
    local error="$2"

    echo ""
    echo -e "${RED}${BOLD}FAILURE: Task '$task' failed${RESET}"
    echo -e "${RED}$error${RESET}"
    echo ""

    # Pause and offer options
    echo -e "Options:"
    echo -e "  ${YELLOW}r${RESET} - Retry this task"
    echo -e "  ${YELLOW}s${RESET} - Skip and continue"
    echo -e "  ${YELLOW}a${RESET} - Abort ralph loop"
    echo ""

    while true; do
        read -p "Choice [r/s/a]: " choice
        case "$choice" in
            r|R)
                return 0  # Signal retry
                ;;
            s|S)
                return 1  # Signal skip
                ;;
            a|A)
                return 2  # Signal abort
                ;;
            *)
                echo "Invalid choice. Enter r, s, or a."
                ;;
        esac
    done
}
```

### Existing state.sh Functions to Use
```bash
# Source: bin/lib/state.sh (existing)

# These functions already exist and should be used:

# Add iteration entry to history
add_iteration_entry "$iteration" "SUCCESS" "03-01: Schema extensions"

# Update next action in STATE.md
update_next_action "$phase_num" "$plan_id" "$plan_name"

# Update current position
update_current_position "$phase_num" "$plan_num" "$phase_name" "$status"

# Update progress bar
update_progress "$completed" "$total"

# Get iteration count
count=$(get_iteration_count)

# Rotate history at phase boundaries
rotate_history_at_phase_boundary "$current_phase"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Claude API direct calls | Claude Code CLI | 2024 | CLI handles auth, context, tools natively |
| Session resume | Fresh invocation | Current | Each iteration gets clean 200k context |
| Complex process management | Simple blocking call | Current | `-p` flag blocks until complete |
| Manual tool approval | `--allowedTools` | 2024-2025 | Automation-friendly permission control |

**Deprecated/outdated:**
- Manual API token management: CLI handles authentication
- Complex session state serialization: Fresh context per iteration preferred
- Interactive mode with automation: `-p` flag provides proper non-interactive mode

## Open Questions

Things that couldn't be fully resolved:

1. **Exit code semantics for partial failures**
   - What we know: Claude CLI returns 0 on success
   - What's unclear: Exit code when some tasks succeed but later ones fail
   - Recommendation: Treat any non-zero as failure, parse JSON for details

2. **Context file size limits**
   - What we know: `--append-system-prompt-file` accepts file path
   - What's unclear: Maximum file size before issues occur
   - Recommendation: Keep GSD context file under 50KB, test with actual content

3. **Git Bash process management edge cases**
   - What we know: Background processes work differently than Unix
   - What's unclear: Exact behavior of `trap` and `wait` on Git Bash
   - Recommendation: Test spinner cleanup thoroughly on Windows

## Sources

### Primary (HIGH confidence)
- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference) - All CLI flags and options
- [Claude Code Headless Mode](https://code.claude.com/docs/en/headless) - Non-interactive execution patterns
- [NO_COLOR Standard](https://no-color.org/) - Terminal color preference specification

### Secondary (MEDIUM confidence)
- [How to Write Better Bash Spinners](https://willcarh.art/blog/how-to-write-better-bash-spinners) - Spinner implementation patterns
- [Cross-Platform Bash Scripting](https://www.plcourses.com/cross-platform-bash-scripting/) - Compatibility considerations
- Existing codebase: `bin/lib/state.sh`, `bin/lib/display.sh`, `bin/lib/failfast.sh`, `bin/lib/budget.sh`

### Tertiary (LOW confidence)
- Various Stack Overflow and blog posts on bash JSON parsing - patterns vary, jq is most reliable

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Claude CLI documentation is authoritative and current
- Architecture: HIGH - Based on existing codebase patterns and official docs
- Pitfalls: MEDIUM - Some based on community experience, not all tested on Windows
- Cross-platform: MEDIUM - Git Bash behavior varies; testing will be needed

**Research date:** 2026-01-19
**Valid until:** 2026-02-19 (30 days - CLI is stable, unlikely major changes)
