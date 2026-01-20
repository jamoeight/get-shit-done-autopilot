# Phase 9: Mode Selection & Base Commands - Research

**Researched:** 2026-01-19
**Domain:** GSD command system architecture, mode switching, configuration persistence
**Confidence:** HIGH

## Summary

This phase adds Interactive vs Lazy mode selection to GSD. The infrastructure already exists in the form of `.planning/.ralph-config` for budget configuration (budget.sh), and the command architecture follows a consistent pattern of markdown files with frontmatter. The implementation path is well-defined: extend the existing config file with a `MODE` field, create a `/gsd:lazy-mode` toggle command, modify the help command to show mode-appropriate content, and add mode checking to mode-restricted commands.

The codebase already has patterns for:
- Configuration persistence (budget.sh load_config/save_config)
- Command routing based on state (progress.md routes based on project state)
- Conditional command availability (various commands check for .planning/ existence)

The key insight is that mode is a filter on command availability, not a fundamental behavior change. Interactive mode commands (plan-phase, discuss-phase, execute-phase) and Lazy mode commands (plan-milestone-all, run-milestone, ralph) are distinct sets.

**Primary recommendation:** Extend .ralph-config with MODE field, create lazy-mode.md command with toggle behavior, add mode gating to restricted commands via a shared check pattern.

## Existing Infrastructure

### Configuration Storage: .ralph-config

The `.planning/.ralph-config` file already exists and stores budget configuration. It's a sourceable bash file.

**Current Structure (from budget.sh):**
```bash
# GSD Ralph configuration
# Last updated: [date]
MAX_ITERATIONS=50
TIMEOUT_HOURS=8
```

**Location:** `.planning/.ralph-config` (project-local)

**Read/Write Functions (bin/lib/budget.sh):**
```bash
# Load
load_config() {
    if [ -f "$RALPH_CONFIG_FILE" ]; then
        source "$RALPH_CONFIG_FILE"
    fi
    MAX_ITERATIONS="${MAX_ITERATIONS:-50}"
    TIMEOUT_HOURS="${TIMEOUT_HOURS:-8}"
    export MAX_ITERATIONS TIMEOUT_HOURS
}

# Save
save_config() {
    mkdir -p "$(dirname "$RALPH_CONFIG_FILE")"
    cat > "$RALPH_CONFIG_FILE" << EOF
# GSD Ralph configuration
# Last updated: $(date)
MAX_ITERATIONS=$MAX_ITERATIONS
TIMEOUT_HOURS=$TIMEOUT_HOURS
EOF
}
```

**Extension approach:** Add `GSD_MODE` variable to the same file. Existing functions can be extended or a new mode.sh library created.

### Command Architecture

All commands are markdown files in `commands/gsd/` with:

**Frontmatter pattern:**
```yaml
---
name: gsd:command-name
description: Brief description
argument-hint: "[args]"
allowed-tools:
  - Read
  - Write
  - ...
---
```

**Process pattern:**
```xml
<objective>What this command does</objective>
<context>Input files</context>
<process>Steps</process>
<success_criteria>Checklist</success_criteria>
```

**Total commands:** 25 files in commands/gsd/

### Help Command Structure (help.md)

The help command outputs static reference content from a `<reference>` block. It's entirely self-contained - no dynamic generation.

**Current structure:**
- Quick Start section
- Core Workflow section
- Phase Planning section
- Execution section
- Roadmap Management section
- Milestone Management section
- Progress Tracking section
- Session Management section
- Debugging section
- Todo Management section
- Utility Commands section
- Workflow Modes section (currently describes interactive/yolo)
- Common Workflows section

**Key insight:** The help.md `<reference>` block needs modification to:
1. Show both command sets with (interactive)/(lazy) labels
2. Add "set mode first" message when mode unset
3. Update Workflow Modes section for new mode system

### Progress Command (progress.md)

Progress.md already loads project state and routes to next action. It has a rich status display.

**Relevant sections:**
- "Current Position" box
- "What's Next" routing
- Route A/B/C/D/E/F patterns

**Mode display integration point:** Add to the status display between "Current Position" and "Key Decisions Made":
```
## Mode
[Interactive | Lazy | Not Set] - /gsd:lazy-mode to change
```

### State Loading Patterns

Commands commonly check for state existence:

```bash
# From multiple commands
ls .planning/ 2>/dev/null  # Verify planning structure
[ -f .planning/PROJECT.md ] || { echo "ERROR: ..."; exit 1; }
[ -f .planning/ROADMAP.md ] && echo "ACTIVE_MILESTONE" || echo "READY_FOR_NEW"
```

**Mode check pattern (to be created):**
```bash
# Check mode from .ralph-config
source .planning/.ralph-config 2>/dev/null
if [[ "$GSD_MODE" == "lazy" ]]; then
    # Allow lazy-mode commands
elif [[ "$GSD_MODE" == "interactive" ]]; then
    # Allow interactive-mode commands
else
    # Mode not set - require /gsd:lazy-mode first for mode-specific commands
fi
```

## Command Inventory

### Mode-Independent Commands (Always Available)

These commands work regardless of mode setting:

| Command | Purpose | Notes |
|---------|---------|-------|
| `/gsd:new-project` | Initialize project | Sets up .planning/ |
| `/gsd:map-codebase` | Analyze existing code | Pre-project or refresh |
| `/gsd:progress` | Show status | Add mode display |
| `/gsd:help` | Show commands | Modified for dual-mode display |
| `/gsd:lazy-mode` | Toggle mode | NEW - this phase |
| `/gsd:whats-new` | Version info | Generic utility |
| `/gsd:update` | Update GSD | Generic utility |
| `/gsd:resume-work` | Resume session | Works either mode |
| `/gsd:pause-work` | Save session | Works either mode |
| `/gsd:debug` | Debug issues | Works either mode |
| `/gsd:add-todo` | Capture idea | Works either mode |
| `/gsd:check-todos` | Review todos | Works either mode |
| `/gsd:new-milestone` | Start milestone | Planning phase, either mode |

### Interactive-Mode Commands

These commands are the current GSD workflow (plan one phase, execute, repeat):

| Command | Purpose | Notes |
|---------|---------|-------|
| `/gsd:discuss-phase` | Gather phase context | Pre-planning conversation |
| `/gsd:research-phase` | Deep domain research | Optional pre-planning |
| `/gsd:list-phase-assumptions` | Preview Claude's approach | Pre-planning check |
| `/gsd:plan-phase` | Create phase plans | One phase at a time |
| `/gsd:execute-phase` | Execute phase plans | One phase at a time |
| `/gsd:verify-work` | UAT testing | Post-phase validation |
| `/gsd:add-phase` | Add phase to roadmap | Roadmap editing |
| `/gsd:insert-phase` | Insert urgent phase | Roadmap editing |
| `/gsd:remove-phase` | Remove future phase | Roadmap editing |
| `/gsd:complete-milestone` | Archive milestone | Milestone transition |
| `/gsd:audit-milestone` | Cross-phase audit | Pre-completion check |
| `/gsd:plan-milestone-gaps` | Fix gaps | Gap planning |

### Lazy-Mode Commands

These commands enable "fire and forget" execution (plan all upfront, run unattended):

| Command | Purpose | Notes |
|---------|---------|-------|
| `/gsd:plan-milestone-all` | Generate all plans | Already exists (Phase 8) |
| `/gsd:ralph` | Configure loop settings | Phase 10 |
| `/gsd:run-milestone` | Start autonomous exec | Phase 10 |

**Note:** `plan-milestone-all` already exists but should be lazy-mode restricted.

### Gating Behavior

Per CONTEXT.md decisions:
- Lazy-only commands hidden entirely in interactive mode (don't show in help, error if invoked)
- Interactive-mode commands not available in lazy mode
- Error message when wrong mode: "This command is only available in [interactive/lazy] mode. Run /gsd:lazy-mode to switch."

## Implementation Patterns

### Pattern 1: Mode Storage Extension

Extend budget.sh or create mode.sh in bin/lib/:

```bash
# bin/lib/mode.sh (NEW FILE)

RALPH_CONFIG_FILE="${RALPH_CONFIG_FILE:-.planning/.ralph-config}"

# get_mode - Return current GSD mode (interactive, lazy, or "")
get_mode() {
    if [ -f "$RALPH_CONFIG_FILE" ]; then
        source "$RALPH_CONFIG_FILE"
    fi
    echo "${GSD_MODE:-}"
}

# set_mode - Set GSD mode and save
# Args: mode (interactive|lazy)
set_mode() {
    local mode="$1"

    # Load existing config
    if [ -f "$RALPH_CONFIG_FILE" ]; then
        source "$RALPH_CONFIG_FILE"
    fi

    # Set mode
    GSD_MODE="$mode"
    export GSD_MODE

    # Save all config (preserve existing values)
    mkdir -p "$(dirname "$RALPH_CONFIG_FILE")"
    cat > "$RALPH_CONFIG_FILE" << EOF
# GSD Ralph configuration
# Last updated: $(date)
MAX_ITERATIONS=${MAX_ITERATIONS:-50}
TIMEOUT_HOURS=${TIMEOUT_HOURS:-8}
GSD_MODE=$GSD_MODE
EOF
}

# is_mode - Check if current mode matches expected
# Args: expected_mode
# Returns: 0 if match, 1 if not
is_mode() {
    local expected="$1"
    local current
    current=$(get_mode)
    [[ "$current" == "$expected" ]]
}

# require_mode - Exit with error if mode doesn't match
# Args: expected_mode, command_name
require_mode() {
    local expected="$1"
    local command="$2"
    local current
    current=$(get_mode)

    if [[ -z "$current" ]]; then
        echo "Error: Mode not set. Run /gsd:lazy-mode first." >&2
        return 1
    fi

    if [[ "$current" != "$expected" ]]; then
        echo "Error: $command is only available in $expected mode." >&2
        echo "Current mode: $current" >&2
        echo "Run /gsd:lazy-mode to toggle." >&2
        return 1
    fi

    return 0
}
```

### Pattern 2: Toggle Command (lazy-mode.md)

New command in commands/gsd/:

```markdown
---
name: gsd:lazy-mode
description: Toggle between Interactive and Lazy execution modes
allowed-tools:
  - Read
  - Write
  - Bash
---

<objective>
Toggle GSD execution mode between Interactive and Lazy.

- If no mode set: Enable lazy mode
- If lazy mode: Disable (switch to interactive)
- If interactive mode: Enable lazy mode

Shows mode explainer and current status.
</objective>

<process>
1. Check current mode from .ralph-config
2. Toggle to opposite mode (or set lazy if unset)
3. If mid-milestone, show warning but allow
4. Show mode explainer
5. Save mode to .ralph-config
6. Confirm new mode
</process>
```

### Pattern 3: Mode Checking in Commands

For commands that are mode-restricted, add check at start:

```markdown
<process>
## 0. Validate Mode

**MANDATORY FIRST STEP:**

```bash
# Source mode library
source bin/lib/mode.sh 2>/dev/null || true

# For interactive-only commands:
current_mode=$(get_mode)
if [[ "$current_mode" == "lazy" ]]; then
    echo "Error: /gsd:plan-phase is only available in interactive mode."
    echo "In lazy mode, use /gsd:plan-milestone-all instead."
    exit 1
fi

# For lazy-only commands:
if [[ "$current_mode" != "lazy" ]]; then
    echo "Error: /gsd:run-milestone is only available in lazy mode."
    echo "Run /gsd:lazy-mode to enable."
    exit 1
fi
```

## 1. [Rest of existing process...]
</process>
```

### Pattern 4: Help Display Modification

The help.md `<reference>` block needs restructuring. Since it's static markdown, the modification involves:

1. Add mode section at top:
```markdown
## Current Mode

[Shows after running /gsd:progress or /gsd:lazy-mode]

If mode not set, mode-specific commands require `/gsd:lazy-mode` first.
```

2. Label commands with mode:
```markdown
**`/gsd:plan-phase <number>`** (interactive)
Create detailed execution plan for a specific phase.

**`/gsd:plan-milestone-all`** (lazy)
Generate all plans for entire milestone before autonomous execution.
```

3. Update Workflow Modes section:
```markdown
## Workflow Modes

**Interactive Mode** (default concept)
- Plan one phase at a time
- Execute with human supervision
- Iterate: plan -> execute -> plan -> execute
- Commands: discuss-phase, plan-phase, execute-phase

**Lazy Mode**
- Plan ALL phases upfront before execution
- Execute autonomously until complete
- "Fire and forget" - walk away after planning
- Commands: plan-milestone-all, ralph, run-milestone

Toggle with `/gsd:lazy-mode`
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Config persistence | Custom config parser | Extend existing .ralph-config | Already has read/write patterns, sourceable bash |
| Mode checking | Inline mode checks everywhere | Shared mode.sh library | Consistency, single source of truth |
| Help generation | Dynamic help from command files | Static markdown with labels | Simpler, current pattern, predictable |
| Command gating | Complex routing logic | Early exit pattern | Each command checks its own restriction |

## Common Pitfalls

### Pitfall 1: Changing Mode Mid-Execution
**What goes wrong:** User switches mode while plans are executing, causing confusion about which commands to use.
**Why it happens:** No guardrail on mode switching during active work.
**How to avoid:** Per CONTEXT.md decision: "Warn but allow switching mid-milestone: 'Switching mid-execution may cause issues'". Show warning but don't block.
**Warning signs:** STATE.md shows active phase with plans in progress.

### Pitfall 2: Forgetting to Set Mode
**What goes wrong:** User tries to run mode-specific command, gets confusing error.
**Why it happens:** Mode defaults to unset, user doesn't know about mode system.
**How to avoid:** Clear error message: "Mode not set. Run /gsd:lazy-mode first." Also: /gsd:help emphasizes "set mode first" when mode unset.
**Warning signs:** GSD_MODE variable empty or missing from .ralph-config.

### Pitfall 3: Inconsistent Mode Checking
**What goes wrong:** Some commands check mode, others don't. User gets inconsistent experience.
**Why it happens:** Mode checking added piecemeal without systematic approach.
**How to avoid:** Create checklist of all commands, classify each, add mode check systematically.
**Warning signs:** Some interactive commands work in lazy mode, others don't.

### Pitfall 4: Config File Corruption
**What goes wrong:** Multiple writers to .ralph-config cause race conditions or data loss.
**Why it happens:** Both budget.sh and mode.sh write to same file independently.
**How to avoid:** Extend existing save_config() to write all fields, or ensure each writer preserves other fields by reading first.
**Warning signs:** MAX_ITERATIONS resets to default after mode change.

## Code Examples

### Reading Mode from Config (Bash)
```bash
# Source: bin/lib/budget.sh pattern extended
RALPH_CONFIG_FILE="${RALPH_CONFIG_FILE:-.planning/.ralph-config}"

get_mode() {
    if [ -f "$RALPH_CONFIG_FILE" ]; then
        source "$RALPH_CONFIG_FILE" 2>/dev/null
    fi
    echo "${GSD_MODE:-}"
}
```

### Mode Check in Command Markdown
```markdown
<process>
## 0. Validate Mode

Check if this is a mode-restricted command:

\`\`\`bash
# Read current mode
source .planning/.ralph-config 2>/dev/null || true
CURRENT_MODE="${GSD_MODE:-}"

# For interactive-only command:
if [[ "$CURRENT_MODE" == "lazy" ]]; then
    echo ""
    echo "Error: This command is only available in Interactive mode."
    echo "Current mode: Lazy"
    echo ""
    echo "In Lazy mode, use /gsd:plan-milestone-all instead of /gsd:plan-phase."
    echo "Run /gsd:lazy-mode to switch modes."
    exit 1
fi
\`\`\`
</process>
```

### Toggle Command Implementation
```markdown
<process>
## 1. Read Current Mode

\`\`\`bash
source .planning/.ralph-config 2>/dev/null || true
CURRENT_MODE="${GSD_MODE:-}"
\`\`\`

## 2. Determine New Mode

- If CURRENT_MODE is empty or "interactive": set to "lazy"
- If CURRENT_MODE is "lazy": set to "interactive"

## 3. Check for Active Work

\`\`\`bash
# Check if mid-milestone
if [ -f .planning/ROADMAP.md ]; then
    # Check for incomplete phases
    incomplete=$(grep "^- \[ \]" .planning/ROADMAP.md | wc -l)
    if [ "$incomplete" -gt 0 ]; then
        echo "Warning: You have $incomplete incomplete phases."
        echo "Switching modes mid-milestone may cause workflow issues."
        echo ""
    fi
fi
\`\`\`

## 4. Show Mode Explainer

Display appropriate explainer based on new mode:

**If switching to Lazy:**
\`\`\`
Lazy Mode Enabled

In Lazy mode, you plan everything upfront, then walk away.

What changes:
- Use /gsd:plan-milestone-all to generate ALL plans at once
- Use /gsd:run-milestone for autonomous execution
- Individual phase commands (plan-phase, execute-phase) are disabled

The workflow becomes:
new-project -> plan-milestone-all -> configure ralph -> run-milestone -> done

Fire and forget. Wake up to completed work.
\`\`\`

**If switching to Interactive:**
\`\`\`
Interactive Mode Enabled

In Interactive mode, you work phase-by-phase with Claude.

What changes:
- Use /gsd:plan-phase to plan one phase at a time
- Use /gsd:execute-phase to execute with supervision
- Lazy mode commands (plan-milestone-all, run-milestone) are disabled

The workflow becomes:
new-project -> discuss-phase -> plan-phase -> execute-phase -> repeat

Collaborate with Claude on each phase.
\`\`\`

## 5. Save Mode

Write updated mode to config (preserving other values).

## 6. Confirm

\`\`\`
Mode set to: [Interactive|Lazy]
Run /gsd:lazy-mode again to toggle back.
\`\`\`
</process>
```

## Key Files to Modify

| File | Change | Priority |
|------|--------|----------|
| `bin/lib/mode.sh` | NEW - Mode read/write functions | HIGH |
| `bin/lib/budget.sh` | Extend save_config to preserve mode | HIGH |
| `commands/gsd/lazy-mode.md` | NEW - Toggle command | HIGH |
| `commands/gsd/help.md` | Add mode labels, update workflow section | HIGH |
| `commands/gsd/progress.md` | Add mode to status display | HIGH |
| `commands/gsd/plan-phase.md` | Add mode check (interactive-only) | MEDIUM |
| `commands/gsd/discuss-phase.md` | Add mode check (interactive-only) | MEDIUM |
| `commands/gsd/execute-phase.md` | Add mode check (interactive-only) | MEDIUM |
| `commands/gsd/plan-milestone-all.md` | Add mode check (lazy-only) | MEDIUM |

## Open Questions

1. **Should mode be visible in STATE.md?**
   - CONTEXT.md says NO - keep STATE.md focused on progress
   - Mode lives only in .ralph-config
   - Resolved: Mode displayed via /gsd:progress and /gsd:lazy-mode, not stored in STATE.md

2. **What about existing projects without mode set?**
   - Current behavior: Commands work as before (no gating)
   - After this phase: Mode-specific commands require explicit mode
   - Migration path: Users run /gsd:lazy-mode when ready for lazy mode
   - Resolved: Per CONTEXT.md "require explicit choice before mode-specific commands work"

## Sources

### Primary (HIGH confidence)
- `bin/lib/budget.sh` - Existing config read/write patterns
- `commands/gsd/*.md` - All 25 command files reviewed
- `.planning/phases/09-mode-selection/09-CONTEXT.md` - User decisions
- `.planning/ROADMAP.md` - Phase requirements and success criteria
- `.planning/STATE.md` - Current project state and decisions

### Secondary (MEDIUM confidence)
- GSD codebase patterns from completed phases 1-8

### Tertiary (LOW confidence)
- None - all findings verified against codebase

## Metadata

**Confidence breakdown:**
- Existing Infrastructure: HIGH - Directly verified in codebase
- Command Inventory: HIGH - All commands enumerated and reviewed
- Implementation Patterns: HIGH - Based on existing codebase patterns
- Pitfalls: HIGH - Derived from CONTEXT.md decisions and codebase analysis

**Research date:** 2026-01-19
**Valid until:** N/A - internal codebase research, stable
