# Phase 4: Git Checkpointing - Research

**Researched:** 2026-01-19
**Domain:** Git automation, bash scripting, cross-platform compatibility
**Confidence:** HIGH

## Summary

This phase implements git checkpointing for the Ralph outer loop. Each successful iteration creates an atomic commit that captures progress. The system must detect dirty working trees at startup, validate STATE.md against commit history, and abort cleanly if git operations fail.

The existing `mark_checkpoint` function in `failfast.sh` only records HEAD for rollback purposes - it does NOT create commits. This phase needs to ADD commit creation on success, while preserving the rollback mechanism for failures.

**Primary recommendation:** Create a new `create_checkpoint_commit` function in a dedicated `checkpoint.sh` library that handles staging, commit creation, and validation. Integrate it into `handle_iteration_success` in ralph.sh.

## Standard Stack

The established tools for this domain:

### Core
| Tool | Purpose | Why Standard |
|------|---------|--------------|
| `git status --porcelain` | Check dirty working tree | Stable output across Git versions, scriptable |
| `git add -A` | Stage all changes | Includes Claude's staged + STATE.md |
| `git commit -m` | Create checkpoint | Standard, works with hooks |
| `git log --grep` | Search commit history | Reliable pattern matching |
| `git rev-parse` | Repository detection | Built-in, cross-platform |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `git diff --cached --quiet` | Check for staged changes | Before commit to avoid empty |
| `git symbolic-ref -q HEAD` | Check detached HEAD | Warn but continue |
| `git init` | Initialize repository | If not in git repo |

### Not Using
| Alternative | Why Not |
|-------------|---------|
| `git commit --allow-empty` | Context decision: skip if no changes |
| `git stash` | Too complex, not needed |
| `git worktree` | Overkill for this use case |

**Installation:** No additional dependencies - uses built-in git commands.

## Architecture Patterns

### Recommended Project Structure
```
bin/
  lib/
    checkpoint.sh      # NEW: Git checkpointing functions
    failfast.sh        # EXISTING: Rollback mechanism (keep as-is)
    state.sh           # EXISTING: STATE.md updates
  ralph.sh             # EXISTING: Main loop integration
```

### Pattern 1: Pre-flight Check at Startup
**What:** Validate git state before entering main loop
**When to use:** At ralph.sh startup, before first iteration
**Example:**
```bash
# Source: Git documentation + existing codebase patterns
validate_git_state() {
    # Check if in git repo
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Offer to init
        echo -e "${YELLOW}Not in a git repository.${RESET}"
        read -p "Initialize git repository? [y/N]: " init_choice
        if [[ "$init_choice" =~ ^[Yy]$ ]]; then
            git init
        else
            echo -e "${RED}Cannot checkpoint without git. Aborting.${RESET}"
            return 1
        fi
    fi

    # Check for uncommitted changes (dirty working tree)
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        echo -e "${RED}Error: Uncommitted changes detected.${RESET}"
        echo -e "${RED}Please commit or stash changes before running ralph.${RESET}"
        git status --short
        return 1
    fi

    # Check detached HEAD (warn but continue)
    if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Detached HEAD state. Commits will still work.${RESET}"
    fi

    return 0
}
```

### Pattern 2: Checkpoint Commit After Success
**What:** Create atomic commit with structured message after successful iteration
**When to use:** After `handle_iteration_success` updates STATE.md
**Example:**
```bash
# Source: Git documentation + CONTEXT.md decisions
create_checkpoint_commit() {
    local task_id="$1"
    local summary="$2"

    # Stage what Claude staged + always stage STATE.md
    git add .planning/STATE.md

    # Check if there are any staged changes
    if git diff --cached --quiet 2>/dev/null; then
        echo -e "${YELLOW}Warning: No changes to commit after task $task_id${RESET}"
        return 0  # Not an error per CONTEXT.md
    fi

    # Create commit with structured message
    local commit_msg="Ralph checkpoint: ${task_id} complete

${summary}"

    if ! git commit -m "$commit_msg" 2>/dev/null; then
        echo -e "${RED}Error: Git commit failed${RESET}"
        return 1  # Fatal per CONTEXT.md
    fi

    local short_sha=$(git rev-parse --short HEAD)
    echo -e "${GREEN}Checkpoint:${RESET} $short_sha ($task_id)"

    return 0
}
```

### Pattern 3: Recovery from Git History
**What:** Extract last completed task from checkpoint commits
**When to use:** At startup to validate STATE.md, or if STATE.md is corrupted/missing
**Example:**
```bash
# Source: Git documentation
get_last_checkpoint_task() {
    # Search for most recent Ralph checkpoint commit
    local last_checkpoint
    last_checkpoint=$(git log --oneline --grep="Ralph checkpoint:" -1 2>/dev/null)

    if [[ -z "$last_checkpoint" ]]; then
        echo ""  # No checkpoints found
        return 0
    fi

    # Extract task ID from message "Ralph checkpoint: XX-XX complete"
    local task_id
    task_id=$(echo "$last_checkpoint" | grep -oE '[0-9]{2}-[0-9]{2}' | head -1)

    echo "$task_id"
    return 0
}
```

### Pattern 4: STATE.md vs Git History Validation
**What:** Compare STATE.md position with git checkpoint history
**When to use:** At startup, silently pass or warn on conflict
**Example:**
```bash
# Source: CONTEXT.md decisions
validate_state_against_history() {
    local state_task=$(parse_next_task)
    local git_task=$(get_last_checkpoint_task)

    # If no git history, nothing to validate
    if [[ -z "$git_task" ]]; then
        return 0
    fi

    # STATE.md says we should be working on X
    # Git history says we last completed Y
    # If X comes before or equals Y, something is wrong

    # (Implementation would compare task positions)
    # If conflict detected:
    echo -e "${YELLOW}Warning: STATE.md and git history conflict${RESET}"
    echo -e "STATE.md next task: $state_task"
    echo -e "Git last completed: $git_task"
    read -p "Trust [s]tate or [g]it history? " choice
    # Handle choice...
}
```

### Anti-Patterns to Avoid
- **Committing on failure:** Never commit partial work. Only successful iterations get commits.
- **Empty commits:** Don't use `--allow-empty`. Skip commit and log warning if nothing changed.
- **Modifying git config:** Never touch user's git configuration. Use their settings as-is.
- **Force operations:** Never use `--force`, `--hard reset`, or other destructive commands outside of explicit rollback.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dirty tree detection | Custom file diffing | `git status --porcelain` | Handles all edge cases |
| Repo detection | Check for .git folder | `git rev-parse --is-inside-work-tree` | Works with worktrees, bare repos |
| Commit message search | String parsing logs | `git log --grep` | Regex support, performance |
| Empty commit check | Count staged files | `git diff --cached --quiet` | Exit code based, reliable |

**Key insight:** Git's plumbing commands (`rev-parse`, `diff-index`, `status --porcelain`) are designed for scripting. Use them instead of parsing porcelain output.

## Common Pitfalls

### Pitfall 1: Pre-commit Hooks Blocking Automation
**What goes wrong:** User has pre-commit hooks that fail or require input
**Why it happens:** Hooks run on every commit, may have linting or tests
**How to avoid:** Abort on hook failure, don't bypass with `--no-verify`
**Warning signs:** Commit command exits non-zero unexpectedly

### Pitfall 2: Windows Line Ending Issues in Commit Messages
**What goes wrong:** CRLF in commit messages causes parsing issues
**Why it happens:** Git Bash on Windows, mixed line endings
**How to avoid:** Use simple single-line format, avoid heredocs for messages
**Warning signs:** `grep` patterns failing on Windows

### Pitfall 3: Race Condition Between STATE.md Update and Commit
**What goes wrong:** Crash between state update and commit loses sync
**Why it happens:** Two separate operations
**How to avoid:** Stage STATE.md immediately before commit, treat as atomic unit
**Warning signs:** STATE.md says task complete but no matching commit

### Pitfall 4: Interactive Terminal Prompts in Non-Interactive Mode
**What goes wrong:** Script hangs waiting for input
**Why it happens:** Recovery prompts when running non-interactively
**How to avoid:** Check `[[ -t 0 ]]` before prompting, use defaults in non-interactive
**Warning signs:** Ralph hangs with no output

### Pitfall 5: Git Commit Fails Silently with Exit Code 1
**What goes wrong:** Commit appears to work but didn't actually create commit
**Why it happens:** Nothing to commit, hooks failed, other errors
**How to avoid:** Always check exit code, verify HEAD changed
**Warning signs:** `git log` shows no new commit after "successful" operation

## Code Examples

Verified patterns from official sources and existing codebase:

### Check if in Git Repository
```bash
# Source: Git documentation, verified cross-platform
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not in a git repository"
    exit 1
fi
```

### Check for Uncommitted Changes (Dirty Tree)
```bash
# Source: Git documentation - porcelain is stable across versions
if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
    echo "Working tree is dirty"
    exit 1
fi
```

### Check for Staged Changes Before Commit
```bash
# Source: Git documentation - exit code 0 = clean, 1 = dirty
if git diff --cached --quiet 2>/dev/null; then
    echo "Nothing staged to commit"
else
    git commit -m "message"
fi
```

### Search Commit Messages by Pattern
```bash
# Source: Git documentation
last_checkpoint=$(git log --oneline --grep="Ralph checkpoint:" -1)
task_id=$(echo "$last_checkpoint" | grep -oE '[0-9]{2}-[0-9]{2}' | head -1)
```

### Check Detached HEAD State
```bash
# Source: Git documentation - symbolic-ref fails in detached state
if git symbolic-ref -q HEAD >/dev/null 2>&1; then
    echo "On a branch"
else
    echo "Detached HEAD"
fi
```

### Create Commit with Multi-line Message
```bash
# Source: Git documentation - use -m multiple times for paragraphs
git commit -m "Subject line" -m "Body paragraph"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `git diff --quiet HEAD` | `git status --porcelain` | Git 1.7+ | More reliable dirty detection |
| Parse `git status` output | Use `--porcelain` flag | Always | Stable across versions |
| `git diff-files` | `git status --porcelain` | Modern Git | Includes untracked files |

**Deprecated/outdated:**
- `git status -s` alone: Less reliable than `--porcelain` for scripting

## Open Questions

Things that couldn't be fully resolved:

1. **Pre-commit hook timeout**
   - What we know: Hooks can run indefinitely
   - What's unclear: Should we set a timeout on commit?
   - Recommendation: No timeout initially, document that hooks run normally

2. **Concurrent ralph instances**
   - What we know: Git handles concurrent access poorly
   - What's unclear: Should we lock to prevent concurrent runs?
   - Recommendation: Defer to Phase 6 (Circuit Breaker) if needed

## Sources

### Primary (HIGH confidence)
- Git Documentation: `git-status`, `git-rev-parse`, `git-log`, `git-commit`
- Existing codebase: `failfast.sh`, `ralph.sh`, `state.sh`, `parse.sh`
- CONTEXT.md: User decisions for this phase

### Secondary (MEDIUM confidence)
- [remarkablemark - Check git dirty](https://remarkablemark.org/blog/2017/10/12/check-git-dirty/) - Dirty tree detection patterns
- [Graphite - Git log grep](https://graphite.com/guides/git-log-grep) - Searching commit messages
- [CloudBees - Git Detached HEAD](https://www.cloudbees.com/blog/git-detached-head) - Detached HEAD handling
- [Atomic Commits Guide](https://medium.com/@sandrodz/a-developers-guide-to-atomic-git-commits-c7b873b39223) - Atomic commit principles

### Tertiary (LOW confidence)
- General WebSearch results on git automation patterns - Used for validation only

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using only built-in git commands with documented behavior
- Architecture: HIGH - Follows existing codebase patterns (lib/, function conventions)
- Pitfalls: MEDIUM - Based on common patterns and web research, not exhaustive testing

**Research date:** 2026-01-19
**Valid until:** 2026-02-19 (30 days - git commands are stable)

## Integration Notes

### Existing Code to Modify

1. **ralph.sh** - Add startup validation, call checkpoint after success
   - Line ~207: After `mark_checkpoint` call, add `validate_git_state` at startup
   - Line ~276: After success handling, call `create_checkpoint_commit`

2. **New file: checkpoint.sh** - All git checkpointing functions
   - `validate_git_state` - Pre-flight checks
   - `create_checkpoint_commit` - Atomic commit creation
   - `get_last_checkpoint_task` - Recovery from history
   - `validate_state_against_history` - Startup validation

3. **failfast.sh** - Keep as-is for rollback
   - `mark_checkpoint` stays for rollback purposes
   - `rollback_to_checkpoint` unchanged

### Commit Message Format

Per CONTEXT.md decisions:
```
Ralph checkpoint: XX-XX complete

Brief summary of what was accomplished
```

Example:
```
Ralph checkpoint: 04-01 complete

Added atomic commit integration to outer loop
```

### Files to Stage

Per CONTEXT.md:
- Whatever Claude staged during iteration (already in index)
- Always add `.planning/STATE.md` (may not be staged by Claude)

```bash
git add .planning/STATE.md
git commit -m "message"
```

### Error Handling

Per CONTEXT.md - commit failure is FATAL:
```bash
if ! git commit -m "$msg"; then
    echo -e "${RED}Git commit failed. Cannot checkpoint = cannot continue safely.${RESET}"
    exit 1
fi
```
