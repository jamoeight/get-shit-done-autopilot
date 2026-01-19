# Project Research Summary

**Project:** GSD Lazy Mode
**Domain:** Autonomous AI agent development loops (fire-and-forget overnight execution)
**Researched:** 2026-01-19
**Confidence:** HIGH

## Executive Summary

GSD Lazy Mode is an autonomous coding execution system that enables users to "fire and forget" overnight work. The research strongly converges on a single proven pattern: the **Ralph pattern** — a dumb outer bash loop that spawns fresh Claude Code instances, with state persisting via markdown files and git commits. This pattern avoids the complexity traps of multi-agent orchestration while leveraging GSD's existing infrastructure (PLAN.md, STATE.md, SUMMARY.md, git commits) for 90% of the needed state management.

The recommended approach is to build a bash script loop (`ralph.sh`) that invokes `claude -p --dangerously-skip-permissions --output-format json` repeatedly until all phases complete. Each iteration spawns a fresh Claude instance with clean context, reads state from files, executes one plan, commits progress, and either continues or exits based on verifiable completion criteria (tests pass, SUMMARY.md files exist). This approach is proven in production by ralph (4.4k stars), continuous-claude, and frankbria/ralph-claude-code.

The critical risks are infinite loop token burn ($47K case study), context drift across iterations, and silent failure continuation. All three require explicit mitigations: hard iteration caps, cost budgets, explicit progress tracking, fail-fast verification, and git as the canonical source of truth. The research uniformly recommends building safety infrastructure before enabling any autonomous execution — budget controls and verification gates are non-negotiable prerequisites.

## Key Findings

### Recommended Stack

The stack is deliberately minimal, following GSD's zero-dependency philosophy. The outer loop is a bash script (cross-platform via Git Bash on Windows), invoking Claude Code CLI in headless mode. State persistence uses the existing GSD markdown + git pattern. No new NPM dependencies are required.

**Core technologies:**
- **Bash script (ralph.sh)**: Outer loop driver — proven pattern, simple, zero dependencies
- **Claude Code CLI (`claude -p`)**: Headless invocation — official non-interactive mode with JSON output
- **`--dangerously-skip-permissions`**: Required for unattended operation — bypasses all permission prompts
- **`--output-format json`**: Structured output — enables completion detection and cost tracking
- **`--max-turns N`**: Per-iteration budget — prevents runaway within single Claude invocation
- **Git + Markdown**: State persistence — existing GSD pattern, no new infrastructure needed

### Expected Features

**Must have (table stakes):**
- Retry loop with configurable max iterations — prevents infinite token burn
- Fresh context per iteration — avoids context degradation (quality drops at 50%+ context usage)
- State persistence via files — bridges iterations since fresh context has no memory
- Git commits as checkpoints — progress survives crashes
- Test-based success criteria — objective pass/fail, no hallucinated "done" claims
- Upfront planning generation (`/gsd:plan-milestone-all`) — all PLAN.md files exist before autonomous execution
- Stuck loop detection — prevents repeated failures on same task

**Should have (competitive):**
- Circuit breaker pattern — pause after N consecutive failures instead of continuing to burn tokens
- Cost tracking — accumulate and report token spend, abort if threshold exceeded
- Dual-exit gate — require BOTH completion indicators AND explicit exit signal to prevent premature exit
- Learnings propagation — each iteration discovers patterns, future iterations benefit (AGENTS.md)

**Defer (v2+):**
- Intelligent stuck detection (analyze WHY stuck, try alternative approaches) — high complexity
- Checkpointing with resume beyond git — requires complex execution state serialization
- Parallel phase execution — coordination complexity, sequential is fast enough for overnight
- Real-time notifications — user walks away, defeats fire-and-forget philosophy

### Architecture Approach

The architecture is a two-loop system. The **outer loop** (bash) is intentionally "dumb" — it handles iteration control, task selection, Claude spawning, result verification, and exit conditions. The **inner loop** (Claude instance) does the actual work — perceive state, reason about approach, act via tools, verify results. Research uniformly warns against clever multi-agent orchestration; simple loops consistently outperform complex coordination.

**Major components:**
1. **Outer Loop (`ralph.sh`)** — iteration control, spawning fresh Claude instances, parsing completion signals, enforcing budget caps
2. **State Files (STATE.md, ROADMAP.md, PLAN.md)** — persist progress between iterations, read by both loops
3. **Inner Loop (Claude instance)** — task execution, tool usage, verification, emits structured completion signal
4. **Git** — permanent record of work, enables resumption, canonical source of truth

**Data flow:**
```
ROADMAP.md (what) --> STATE.md (where) --> Outer Loop (control)
                                               |
                                               v
PLAN.md (how) <-- Task Selection <-- Fresh Claude instance
                                               |
                                               v
SUMMARY.md (results) <-- Execution + Verify --> Git Commit (persist)
```

### Critical Pitfalls

1. **Infinite Loop Token Burn** — Two agents or retry loops run undetected for hours/days. $47K failure case study. **Prevent with:** hard iteration cap (e.g., 50), token budget cap (e.g., $50), time budget cap, circuit breaker detecting repetitive patterns.

2. **Context Drift Across Iterations** — Each fresh instance interprets state differently, causing contradictions or undoing progress. **Prevent with:** explicit progress tracking (STATE.md), git as ground truth, atomic tasks, re-anchoring prompts that verify understanding.

3. **Silent Failure Continuation** — Something breaks but loop continues, building hours of work on broken foundation. **Prevent with:** fail-fast design, verification gates, test-first validation, structured error returns.

4. **Premature Task Completion** — Agent declares "complete" when only partial. **Prevent with:** verifiable completion criteria in PLAN.md, task receipts (test results), skeptical verification.

5. **State Inconsistency** — State files out of sync with git state. **Prevent with:** git as canonical state, atomic updates (state + commit together), state verification on each iteration start.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Foundation (State Extensions + Budget Infrastructure)

**Rationale:** Everything else depends on state tracking and budget controls. Research unanimously requires safety infrastructure before any autonomous execution. The $47K failure case study makes this non-negotiable.

**Delivers:** Extended STATE.md with iteration tracking, CONFIG.json for budget limits, hard caps infrastructure

**Addresses features:**
- Max iteration limit
- State persistence extensions
- Progress tracking

**Avoids pitfalls:**
- Infinite loop token burn (Pitfall 1)
- State inconsistency (Pitfall 7)

### Phase 2: Outer Loop Core

**Rationale:** Core control structure needed before planning or execution integration. Can be tested with mock tasks before connecting to real Claude invocations.

**Delivers:** `ralph.sh` script that can iterate, read state, select tasks, spawn Claude, parse output, update state

**Uses stack elements:**
- Bash script driver
- Claude CLI `-p` mode
- `--output-format json`
- Git commit flow

**Implements architecture:** Outer loop component

### Phase 3: Exit Conditions + Verification

**Rationale:** Without exit conditions, loop runs forever. Without verification, silent failures compound. Must be built before enabling unattended execution.

**Delivers:** Completion detection (SUMMARY.md presence, test pass, exit signal), fail-fast error handling, circuit breaker

**Addresses features:**
- Test-based exit criteria
- Stuck loop detection
- Circuit breaker pattern

**Avoids pitfalls:**
- Silent failure continuation (Pitfall 3)
- Premature task completion (Pitfall 5)

### Phase 4: Upfront Planning Command

**Rationale:** Lazy mode requires all plans to exist before execution starts. User walks away, so planning cannot be interactive during execution.

**Delivers:** `/gsd:plan-milestone-all` command that generates all PLAN.md files for all phases interactively before autonomous execution begins

**Addresses features:**
- Upfront planning generation (table stakes)

**Avoids pitfalls:**
- Task decomposition failures (Pitfall 6) — user provides context during planning, not execution

### Phase 5: Integration + User Commands

**Rationale:** Final integration layer, requires all components to exist. Creates user-facing commands.

**Delivers:** `/gsd:run-milestone` command, `/gsd:ralph` configuration, end-to-end workflow

**Implements architecture:** Full lazy mode workflow

### Phase Ordering Rationale

- **Foundation first** — Budget controls and state tracking are prerequisites cited by every source. No autonomous execution without safety rails.
- **Outer loop second** — Core iteration machinery can be developed and tested independently with mock Claude responses.
- **Exit/verification third** — Prevents infinite loops and silent failures, required before any real autonomous runs.
- **Planning fourth** — Can use existing plan-phase infrastructure, extends rather than builds from scratch.
- **Integration last** — Wires everything together, requires all components functional.

This ordering ensures we never enable autonomous execution without the safety infrastructure to control it.

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 3 (Exit Conditions):** Completion signal parsing and test integration may need iteration based on real Claude output formats
- **Phase 4 (Planning Command):** May need research on optimal interaction pattern for multi-phase context gathering

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Foundation):** Well-documented state management, simple config
- **Phase 2 (Outer Loop):** Ralph pattern extensively documented, direct adaptation
- **Phase 5 (Integration):** Extends existing GSD command patterns

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against official Claude Code CLI docs, proven in production (ralph 4.4k stars) |
| Features | HIGH | Multiple authoritative sources (Anthropic, Google ADK, Microsoft), cross-verified patterns |
| Architecture | HIGH | Strong source convergence on Ralph pattern, anti-pattern warnings consistent |
| Pitfalls | HIGH | Academic papers (arXiv), production case studies ($47K failure), framework documentation |

**Overall confidence:** HIGH

### Gaps to Address

- **Windows testing:** Bash script assumed to work via Git Bash — needs explicit Windows testing during Phase 2
- **Completion signal format:** Exact format of `<ralph>COMPLETE</ralph>` vs. structured markdown TBD during Phase 3
- **Cost tracking granularity:** Whether to track per-iteration or cumulative only — minor, can decide during implementation
- **jq dependency:** JSON parsing with jq recommended but optional — fallback strategy if jq unavailable TBD

## Sources

### Primary (HIGH confidence)
- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference) — flags, modes, output formats
- [Run Claude Code Programmatically](https://code.claude.com/docs/en/headless) — headless mode details
- [Anthropic: Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) — agent loop patterns
- [Ralph (snarktank/ralph)](https://github.com/snarktank/ralph) — canonical implementation, 4.4k stars

### Secondary (MEDIUM confidence)
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) — Claude Code adaptation, circuit breaker
- [Braintrust: Canonical Agent Architecture](https://www.braintrust.dev/blog/agent-while-loop) — while loop pattern
- [Cursor: Scaling Long-Running Autonomous Coding](https://cursor.com/blog/scaling-agents) — context management
- [Simon Willison: Designing Agentic Loops](https://simonwillison.net/2025/Sep/30/designing-agentic-loops/) — practitioner patterns

### Tertiary (LOW confidence — needs validation)
- [AI Agents Horror Stories: $47K Failure](https://techstartups.com/2025/11/14/ai-agents-horror-stories-how-a-47000-failure-exposed-the-hype-and-hidden-risks-of-multi-agent-systems/) — cited for risk context, claims not independently verified

---
*Research completed: 2026-01-19*
*Ready for roadmap: yes*
