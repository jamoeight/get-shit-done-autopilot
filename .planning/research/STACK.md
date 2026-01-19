# Technology Stack: GSD Lazy Mode

**Project:** GSD Lazy Mode - Autonomous milestone execution
**Researched:** 2026-01-19
**Confidence:** HIGH (verified against official Claude Code documentation)

## Executive Summary

GSD Lazy Mode requires a loop mechanism that spawns fresh Claude Code instances, executes plans, validates results, and retries until complete. The recommended approach is a **bash script loop** (ralph pattern) invoking `claude -p` with `--dangerously-skip-permissions`, following patterns proven in production by ralph, continuous-claude, and similar autonomous agent systems.

**Key insight:** The existing GSD architecture (markdown commands, Task tool for subagents, git for state) already provides 90% of needed infrastructure. Lazy mode adds an outer bash loop to drive iterations.

---

## Recommended Stack

### Loop Driver: Bash Script

| Component | Choice | Why |
|-----------|--------|-----|
| Loop mechanism | Bash script | Simple, proven in ralph/continuous-claude, no dependencies, cross-platform via Git Bash/WSL |
| Claude invocation | `claude -p` (print/headless mode) | Official non-interactive mode, supports piped prompts, returns structured output |
| Permission handling | `--dangerously-skip-permissions` | Required for unattended operation - bypasses all permission prompts |
| Output parsing | `--output-format json` | Structured responses enable completion detection, error handling |
| Budget control | `--max-turns N` | Prevents runaway iterations within single Claude invocation |

**Confidence:** HIGH - Verified against [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference)

### State Persistence: Git + Markdown (Existing)

| Component | Choice | Why |
|-----------|--------|-----|
| Iteration state | `.planning/lazy/ITERATION.md` | Tracks current iteration, completed phases, failures |
| Phase completion | `*-SUMMARY.md` files | Existing pattern - presence indicates completion |
| Progress tracking | Git commits | Existing pattern - each task commits, history shows progress |
| Session context | Markdown files | Existing pattern - fresh Claude reads `.planning/` for context |

**Confidence:** HIGH - Leverages existing GSD infrastructure, no new dependencies

### Completion Detection: Semantic + File-based

| Component | Choice | Why |
|-----------|--------|-----|
| Primary signal | Exit phrase in output | `<ralph>COMPLETE</ralph>` or similar - Claude outputs when done |
| Secondary signal | All SUMMARY.md present | File-based verification - all planned phases have summaries |
| Tertiary signal | Tests pass | Optional - run test suite as final validation |

**Confidence:** HIGH - ralph pattern proven, GSD SUMMARY.md pattern already works

### Safety Mechanisms

| Component | Choice | Why |
|-----------|--------|-----|
| Iteration limit | `--max-iterations N` (bash) | Prevents infinite loops, user configures token budget |
| Per-iteration limit | `--max-turns` (Claude flag) | Caps tool calls per Claude invocation |
| Circuit breaker | Consecutive failure count | Stop after N iterations with no file changes |
| Cost tracking | `--output-format json` → parse `total_cost_usd` | Accumulate costs, abort if threshold exceeded |

**Confidence:** HIGH - Patterns from ralph-claude-code, verified against CLI docs

---

## Detailed Component Specifications

### 1. Ralph Loop Script (`lazy-ralph.sh` or `lazy-ralph.js`)

**Purpose:** Outer loop that spawns fresh Claude instances until milestone complete

**Bash implementation (recommended):**
```bash
#!/bin/bash
# lazy-ralph.sh - GSD Lazy Mode driver
set -e

MAX_ITERATIONS=${1:-10}
PROMPT_FILE=".planning/lazy/PROMPT.md"
ITERATION_FILE=".planning/lazy/ITERATION.md"

for i in $(seq 1 $MAX_ITERATIONS); do
    echo "=== Iteration $i of $MAX_ITERATIONS ==="

    # Spawn fresh Claude with headless mode
    OUTPUT=$(claude -p \
        --dangerously-skip-permissions \
        --output-format json \
        --max-turns 50 \
        "$(cat $PROMPT_FILE)" 2>&1) || true

    # Parse result
    RESULT=$(echo "$OUTPUT" | jq -r '.result // empty')

    # Check for completion signal
    if echo "$RESULT" | grep -q "<ralph>COMPLETE</ralph>"; then
        echo "Milestone complete at iteration $i"
        exit 0
    fi

    # Update iteration state
    echo "Iteration $i: $(date)" >> "$ITERATION_FILE"

    sleep 2
done

echo "Max iterations reached without completion"
exit 1
```

**Why bash over Node.js:**
- Zero dependencies (GSD philosophy)
- Simpler to maintain
- Cross-platform via Git Bash (Windows) or native (Mac/Linux)
- ralph pattern is proven in production

**Confidence:** HIGH - Direct adaptation of ralph.sh pattern

### 2. Iteration Prompt Template

**Purpose:** Prompt given to each fresh Claude instance

**Location:** `.planning/lazy/PROMPT.md`

```markdown
You are executing GSD Lazy Mode - autonomous milestone completion.

## Current State
Read: @.planning/STATE.md
Read: @.planning/ROADMAP.md

## Your Task
1. Find the next incomplete phase (no SUMMARY.md exists)
2. If phase needs planning: run /gsd:plan-phase
3. If phase has plans: run /gsd:execute-phase
4. After execution: verify phase goal met
5. If ALL phases complete with passing verification: output <ralph>COMPLETE</ralph>
6. If work remains: stop (next iteration will continue)

## Rules
- One phase per iteration (fresh context each time)
- Commit after each meaningful change
- Update STATE.md before stopping
- If blocked: document blocker in STATE.md, stop

## Completion Signal
When ALL phases verified complete, output exactly:
<ralph>COMPLETE</ralph>
```

**Confidence:** HIGH - Follows GSD patterns, ralph completion signal

### 3. Claude Code Invocation Flags

| Flag | Value | Purpose |
|------|-------|---------|
| `-p` | (prompt as argument) | Headless/print mode - non-interactive |
| `--dangerously-skip-permissions` | - | Bypass all permission prompts |
| `--output-format` | `json` | Structured output for parsing |
| `--max-turns` | `50` (configurable) | Limit tool calls per iteration |
| `--allowedTools` | (optional) | Restrict to safe tools if needed |

**Alternative for session continuity:**
```bash
# First iteration - create session
claude -p --output-format json "..." > /tmp/session.json
SESSION_ID=$(jq -r '.session_id' /tmp/session.json)

# Subsequent iterations - continue session
claude -p --resume "$SESSION_ID" --output-format json "..."
```

**Note:** `--resume` continues existing session context. For ralph pattern, fresh context (no resume) is preferred to avoid context degradation.

**Confidence:** HIGH - Verified against [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference)

### 4. State Files Structure

```
.planning/
  lazy/
    PROMPT.md           # Iteration prompt template
    ITERATION.md        # Iteration log (timestamps, outcomes)
    CONFIG.json         # Lazy mode configuration
  STATE.md              # (existing) Current position
  ROADMAP.md            # (existing) Phase structure
  phases/
    01-foundation/
      01-01-PLAN.md     # (existing) Executable plan
      01-01-SUMMARY.md  # (existing) Completion marker
```

**CONFIG.json schema:**
```json
{
  "max_iterations": 10,
  "max_turns_per_iteration": 50,
  "max_budget_usd": 50.00,
  "circuit_breaker_threshold": 3,
  "completion_signal": "<ralph>COMPLETE</ralph>"
}
```

**Confidence:** HIGH - Extends existing GSD patterns

---

## Alternatives Considered

### Loop Driver Alternatives

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Bash script** | Simple, zero deps, proven (ralph) | Windows needs Git Bash | **RECOMMENDED** |
| Node.js script | Cross-platform, matches GSD stack | Adds complexity, overkill | Consider for v2 |
| Claude Agent SDK | Full programmatic control | Heavy dependency, learning curve | Overkill for MVP |
| GitHub Actions | CI/CD integration, scheduled | Requires GitHub, external dependency | Post-MVP option |

### Claude Invocation Alternatives

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **`claude -p`** | Official, documented, simple | Limited to CLI features | **RECOMMENDED** |
| Agent SDK | Full API access, programmatic | NPM dependency, more code | Overkill for MVP |
| Direct API | Maximum control | Must reimplement tools | Wrong abstraction |

### State Persistence Alternatives

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Git + Markdown** | Existing GSD pattern, simple | No real-time state | **RECOMMENDED** |
| SQLite | Queryable, ACID | New dependency, overkill | No |
| JSON files | Simpler parsing | Less readable | No |
| External service | Real-time, collaborative | Dependency, complexity | No |

---

## What NOT to Use

### Do NOT use the Claude Agent SDK for MVP

**Why:**
- Adds `@anthropic-ai/claude-agent-sdk` NPM dependency (violates zero-deps philosophy)
- Requires TypeScript/JavaScript wrapper around existing bash-friendly workflow
- Overkill - GSD doesn't need programmatic subagent definitions, hooks, or custom tools
- CLI `-p` mode provides everything needed for ralph loop

**When to reconsider:** If lazy mode needs dynamic subagent spawning, custom MCP tools, or hooks that modify tool behavior at runtime.

**Confidence:** HIGH

### Do NOT use session continuity (`--resume`)

**Why:**
- Ralph pattern explicitly uses fresh context per iteration
- Session continuity accumulates context, causing degradation
- Fresh instances read state from files, not context window
- Context compaction exists but adds complexity

**When to reconsider:** If iteration handoffs lose critical context not captured in state files.

**Confidence:** HIGH - Core ralph pattern insight

### Do NOT build a Node.js orchestrator for MVP

**Why:**
- Bash script is simpler and proven
- GSD already has sufficient state management in markdown
- Adding Node.js loop layer duplicates bash capabilities
- Increases maintenance burden

**When to reconsider:** If lazy mode needs features bash can't provide (WebSocket notifications, complex JSON parsing, concurrent iteration tracking).

**Confidence:** MEDIUM - Could argue either way, but simplicity wins for MVP

### Do NOT use real-time notifications

**Why:**
- User explicitly "walks away" - lazy mode philosophy
- Adds external dependencies (email, SMS, Slack APIs)
- Complicates error handling
- User checks results when ready

**When to reconsider:** For long-running overnight jobs where early failure detection saves money.

**Confidence:** HIGH - Explicitly out of scope per PROJECT.md

---

## Installation / Setup

### Prerequisites
```bash
# Claude Code CLI (already installed if using GSD)
claude --version  # Verify installed

# jq for JSON parsing (optional but recommended)
# Mac
brew install jq

# Windows (via Chocolatey)
choco install jq

# Or use Node.js JSON parsing if jq unavailable
```

### No New NPM Dependencies

Lazy mode adds:
- Shell scripts (`.sh` files)
- Markdown templates
- JSON configuration

Zero new NPM dependencies required.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Claude API rate limits | MEDIUM | HIGH | Add delay between iterations, respect 429 responses |
| Context degradation across iterations | LOW | MEDIUM | Fresh context per iteration (ralph pattern) |
| Infinite loop / runaway costs | MEDIUM | HIGH | Max iterations limit, budget cap in config |
| Windows bash compatibility | LOW | MEDIUM | Use Git Bash, test on Windows |
| Permission prompt blocks headless | LOW | HIGH | `--dangerously-skip-permissions` required |
| State corruption mid-iteration | LOW | MEDIUM | Atomic git commits, iteration log |

---

## Sources

### Official Documentation (HIGH confidence)
- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference) - Flags, modes, output formats
- [Run Claude Code Programmatically](https://code.claude.com/docs/en/headless) - Headless mode details
- [Claude Agent SDK Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) - SDK API (considered but not recommended)

### Production Implementations (MEDIUM-HIGH confidence)
- [snarktank/ralph](https://github.com/snarktank/ralph) - Original ralph pattern, 4.4k stars
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) - Claude Code adaptation
- [AnandChowdhary/continuous-claude](https://github.com/AnandChowdhary/continuous-claude) - CI/CD integration pattern

### Best Practices (MEDIUM confidence)
- [Anthropic Engineering: Building Agents with Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)
- [Anthropic Engineering: Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)

---

## Roadmap Implications

### Phase Structure Recommendation

Based on this stack research:

1. **Phase 1: Loop Infrastructure** - Bash script, config, state files
   - Low risk, well-understood patterns
   - Unlikely to need deeper research

2. **Phase 2: Planning Integration** - `/gsd:plan-milestone-all` command
   - Extends existing GSD patterns
   - Moderate complexity

3. **Phase 3: Execution Integration** - `/gsd:run-milestone` command
   - Connects loop to existing execute-phase
   - Moderate complexity

4. **Phase 4: Safety & Monitoring** - Circuit breaker, cost tracking
   - Important for overnight runs
   - Can iterate based on real usage

### Research Flags

| Phase | Research Needed? | Reason |
|-------|-----------------|--------|
| Loop Infrastructure | LOW | Patterns well-documented |
| Planning Integration | LOW | Extends existing GSD |
| Execution Integration | MEDIUM | May need iteration on handoff |
| Safety & Monitoring | LOW | Standard patterns |

---

*Stack research complete. Ready for roadmap creation.*
