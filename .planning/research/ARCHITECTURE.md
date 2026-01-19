# Architecture Patterns for Autonomous Agent Loops

**Domain:** Autonomous AI agent development loops (lazy mode)
**Researched:** 2026-01-19
**Confidence:** HIGH (multiple authoritative sources, existing pattern implementations)

## Recommended Architecture

The research strongly converges on a single pattern that works: **a dumb outer loop that spawns fresh agent instances, with state persisting via files and git**.

### The Ralph Pattern (Canonical)

```
┌─────────────────────────────────────────────────────────────────────┐
│  OUTER LOOP (bash/shell)                                            │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  while (incomplete_tasks exist AND iterations < max):       │    │
│  │    1. Read state files (progress, plan, config)             │    │
│  │    2. Select next task                                      │    │
│  │    3. Spawn fresh Claude instance with prompt               │    │
│  │    4. Wait for completion or timeout                        │    │
│  │    5. Check results (tests pass? files exist?)              │    │
│  │    6. Update state files                                    │    │
│  │    7. Git commit if work completed                          │    │
│  │    8. Increment iteration counter                           │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  INNER LOOP (Claude instance)                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  while (!task_complete):                                    │    │
│  │    1. Perceive (read files, understand state)               │    │
│  │    2. Reason (plan approach)                                │    │
│  │    3. Act (use tools)                                       │    │
│  │    4. Verify (check results)                                │    │
│  │    5. Iterate or signal completion                          │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

**Key insight from research:** The outer loop is intentionally "dumb" - it should not try to be clever about orchestration. Complex multi-agent coordination consistently underperforms simple loops with file-based state. ([Source: chrismdp.com](https://www.chrismdp.com/your-agent-orchestrator-is-too-clever/))

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **Outer Loop** | Iteration control, task selection, spawning, exit conditions | State files (read/write), Claude CLI (spawn), Git (commit) |
| **State Files** | Persist progress, decisions, learnings between iterations | Written by inner loop, read by both |
| **Inner Loop (Claude)** | Task execution, tool usage, verification, completion signal | State files (read/write), codebase (modify), tests (run) |
| **Git** | Permanent record of work, enables resumption | Written by both loops |

### Data Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  ROADMAP.md  │────▶│  STATE.md    │────▶│  Outer Loop  │
│  (what)      │     │  (where)     │     │  (control)   │
└──────────────┘     └──────────────┘     └──────────────┘
                                                │
                                                ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  PLAN.md     │◀────│  Task        │◀────│  Fresh       │
│  (how)       │     │  Selection   │     │  Claude      │
└──────────────┘     └──────────────┘     └──────────────┘
                                                │
                                                ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  SUMMARY.md  │◀────│  Execution   │────▶│  Git Commit  │
│  (results)   │     │  + Verify    │     │  (persist)   │
└──────────────┘     └──────────────┘     └──────────────┘
```

## Patterns to Follow

### Pattern 1: Fresh Instance Per Iteration

**What:** Each iteration of the outer loop spawns a completely fresh Claude instance with clean context.

**Why this works:**
- Prevents context degradation (quality drops significantly above 50% context usage)
- Each instance starts with full capacity
- Errors don't compound across iterations
- State persistence is explicit, not implicit

**How GSD should implement:**
```bash
# Outer loop spawns fresh Claude Code CLI each iteration
while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  claude --print -p "$(cat prompt_template.md)" \
    --allowedTools Read,Write,Edit,Bash,Grep,Glob
  # Check results, update state, continue or exit
done
```

**Source:** [Anthropic - Building Effective Agents](https://www.anthropic.com/research/building-effective-agents), [Ralph pattern](https://github.com/snarktank/ralph)

### Pattern 2: File-Based State Persistence

**What:** All state that needs to survive between iterations is written to files on disk.

**Why this works:**
- Git provides durability and history
- Files are human-readable and debuggable
- No complex serialization needed
- Agent reads state fresh each iteration

**State file categories:**

| File | Purpose | Read By | Written By |
|------|---------|---------|------------|
| `STATE.md` | Current position, progress | Both loops | Inner loop |
| `ROADMAP.md` | What phases/plans exist | Both loops | Planning phase |
| `PLAN.md` | Current task details | Inner loop | Planning phase |
| `SUMMARY.md` | Completed work record | Both loops | Inner loop |
| `config.json` | Runtime settings | Both loops | User/setup |

**Source:** [Ralph architecture](https://github.com/snarktank/ralph), [Ralph Playbook](https://github.com/ClaytonFarr/ralph-playbook)

### Pattern 3: Token-Based Completion Signal

**What:** Agent signals task completion by emitting a specific token/format that the outer loop detects.

**How Ralph does it:**
```markdown
<promise>COMPLETE</promise>
```

**How GSD should adapt:**
```markdown
## PLAN COMPLETE

**Plan:** 01-03
**Tasks:** 4/4
**Status:** all_passed
```

The outer loop parses Claude's output looking for this structured completion signal.

**Source:** [Ralph TUI documentation](https://github.com/snarktank/ralph)

### Pattern 4: Test-Based Verification Loop

**What:** Each iteration's success is verified by automated tests, not by the agent's self-assessment.

**Why this works:**
- Objective success criteria (tests pass or fail)
- Prevents false completion signals
- Enables retry on actual failure
- Provides ground truth feedback

**Implementation:**
```bash
# After Claude completes, verify independently
npm test
if [ $? -eq 0 ]; then
  mark_task_complete
  git commit -am "feat: completed task X"
else
  mark_task_failed
  # Next iteration will retry or move on
fi
```

**Source:** [Anthropic](https://www.anthropic.com/research/building-effective-agents), [Simon Willison](https://simonwillison.net/2025/Sep/30/designing-agentic-loops/)

### Pattern 5: Iteration Budget Control

**What:** Set a maximum number of iterations to prevent runaway costs.

**Why needed:**
- Each Claude invocation costs tokens
- Infinite loops are expensive
- Forces tasks to be appropriately scoped

**Recommended defaults:**
- Per-plan max: 3-5 iterations
- Per-phase max: 10-15 iterations
- Per-milestone max: 50-100 iterations

**Source:** [Ralph default of 10 iterations](https://github.com/snarktank/ralph)

## Anti-Patterns to Avoid

### Anti-Pattern 1: Clever Multi-Agent Orchestration

**What:** Building sophisticated coordination between multiple parallel agents with shared state and complex handoffs.

**Why bad:**
- Coordination overhead exceeds benefits
- State synchronization failures cause conflicts
- Debugging becomes intractable
- Simple loops consistently outperform ([Source](https://www.chrismdp.com/your-agent-orchestrator-is-too-clever/))

**Instead:** Sequential outer loop with one active agent at a time. Parallel execution only within a single Claude instance (wave-based plans).

### Anti-Pattern 2: Resuming Instead of Restarting

**What:** Trying to pause and resume a Claude instance mid-execution.

**Why bad:**
- Serialization is unreliable
- State can be corrupted
- Context may be lost
- GSD already found this: "Resume relies on Claude Code's internal serialization which breaks with parallel tool calls"

**Instead:** Always spawn fresh instances. Pass explicit state via files. Use checkpoint returns with full state for continuation.

### Anti-Pattern 3: Agent Self-Assessment for Completion

**What:** Trusting the agent to determine if its own work is correct.

**Why bad:**
- Agents can be confidently wrong
- No external validation
- Errors compound without detection

**Instead:** Verify with tests, type checks, existence checks - objective criteria the outer loop can evaluate independently.

### Anti-Pattern 4: In-Memory State Between Iterations

**What:** Keeping state in variables or memory structures that don't persist to disk.

**Why bad:**
- Lost on crash
- Not visible for debugging
- Can't resume after interruption
- Claude instances are ephemeral

**Instead:** Write everything to files. Git commit after changes. Read fresh each iteration.

## Integration with Existing GSD

### Current Architecture (Interactive Mode)

```
User → /gsd:command → Orchestrator → Task(subagent) → Results → User
                         │
                         └── Human at each phase transition
```

### Proposed Architecture (Lazy Mode)

```
User → /gsd:plan-milestone-all → All PLAN.md files created
User → /gsd:run-milestone → Outer Loop starts
                              │
                              ├── Iteration 1: Execute Plan 01-01
                              │     └── Fresh Claude → SUMMARY.md → git commit
                              ├── Iteration 2: Execute Plan 01-02
                              │     └── Fresh Claude → SUMMARY.md → git commit
                              ├── Iteration N: Verification
                              │     └── Fresh Claude → VERIFICATION.md
                              ├── (gap closure if needed)
                              │
                              └── Exit: All tests pass + all must_haves verified

User ← Results ready
```

### Component Mapping

| GSD Concept | Lazy Mode Role |
|-------------|----------------|
| `STATE.md` | Primary state file read/written each iteration |
| `ROADMAP.md` | Source of what needs to be done |
| `PLAN.md` files | Pre-generated during planning session |
| `SUMMARY.md` files | Completion markers + learnings |
| `VERIFICATION.md` | Exit condition verification |
| `gsd-executor` agent | Inner loop execution (already exists) |
| NEW: `ralph.sh` | Outer loop controller |

### What Needs to Be Built

1. **Outer loop script** (`ralph.sh` or equivalent)
   - Bash script that iterates
   - Reads STATE.md for position
   - Selects next incomplete PLAN.md
   - Spawns Claude Code CLI
   - Parses completion signal
   - Updates state files
   - Commits progress
   - Checks exit conditions

2. **Plan-all workflow** (`plan-milestone-all.md`)
   - Generates ALL PLAN.md files for ALL phases upfront
   - User provides context for each phase interactively
   - Creates executable plans before any execution starts

3. **State extensions** (STATE.md updates)
   - Track ralph iteration count
   - Track max iterations
   - Track last iteration outcome
   - Track milestone-level progress

4. **Exit condition checker**
   - All PLAN.md files have SUMMARY.md
   - All VERIFICATION.md files show passed
   - All tests pass
   - Or max iterations reached

## Control Flow: Outer Loop Detailed

```
START
  │
  ▼
┌─────────────────────────────────────────┐
│ Read STATE.md                           │
│ - Get current phase/plan position       │
│ - Get iteration count                   │
│ - Get max iterations                    │
└─────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────┐
│ Check exit conditions                   │
│ - iterations >= max? → EXIT (budget)    │
│ - all plans complete? → VERIFY          │
│ - verification passed? → EXIT (success) │
└─────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────┐
│ Select next task                        │
│ - Find first incomplete PLAN.md         │
│ - Or find failed VERIFICATION.md        │
│ - Or find gap closure PLAN.md           │
└─────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────┐
│ Spawn fresh Claude                      │
│ - Build prompt with task context        │
│ - Include state files                   │
│ - Include PLAN.md                       │
│ - Set timeout                           │
└─────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────┐
│ Wait for completion                     │
│ - Parse output for completion signal    │
│ - Detect timeout                        │
│ - Detect error                          │
└─────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────┐
│ Validate results                        │
│ - SUMMARY.md exists?                    │
│ - Tests pass?                           │
│ - No regressions?                       │
└─────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────┐
│ Update state                            │
│ - Increment iteration count             │
│ - Update position if task complete      │
│ - Record outcome                        │
│ - Git commit state changes              │
└─────────────────────────────────────────┘
  │
  ▼
  └──────────────────────────────────────────────────────── LOOP
```

## Suggested Build Order

Based on component dependencies:

### Phase 1: Foundation (State Extensions)

Build first because everything else depends on it:

1. Extend STATE.md template for ralph tracking
2. Add iteration count, max iterations, last outcome fields
3. Add milestone-level progress tracking
4. Test: Can read/write ralph state fields

**Rationale:** All other components need to read and write state.

### Phase 2: Outer Loop Core

Build the basic loop that can iterate:

1. Create `ralph.sh` script (or Node.js equivalent)
2. Implement: read state, select task, spawn claude, parse output
3. Implement: update state, increment counter, check max
4. Test: Can iterate through mock tasks

**Rationale:** Core control structure. Can be tested with simple echo commands before real Claude.

### Phase 3: Exit Conditions

Build the verification and exit logic:

1. Implement: check all SUMMARY.md exist
2. Implement: run test suite, check results
3. Implement: check VERIFICATION.md status
4. Integrate with outer loop
5. Test: Loop exits on success, budget, and failure conditions

**Rationale:** Without exit conditions, loop runs forever.

### Phase 4: Plan-All Command

Build the upfront planning command:

1. Create `/gsd:plan-milestone-all` command
2. Implement: iterate through all phases
3. Implement: gather context per phase
4. Implement: generate all PLAN.md files
5. Test: Creates complete plan set for milestone

**Rationale:** Required for lazy mode workflow, but can be built after loop basics work.

### Phase 5: Integration

Wire everything together:

1. Create `/gsd:run-milestone` command
2. Invoke outer loop
3. Handle interrupt/resume
4. Create `/gsd:ralph` configuration command
5. End-to-end testing

**Rationale:** Integration layer, needs all components to exist first.

## Scalability Considerations

| Concern | At 10 plans | At 50 plans | At 200 plans |
|---------|-------------|-------------|--------------|
| Iteration budget | 30-50 | 150-250 | 600-1000 |
| State file size | Trivial | Manageable | May need pruning |
| Git history | Linear | Linear | Consider squash |
| Total cost | ~$2-5 | ~$10-25 | ~$40-100 |
| Wall time | 30m-2h | 2-8h | 8-24h |

## Sources

- [Anthropic: Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) - HIGH confidence, authoritative
- [Ralph (snarktank/ralph)](https://github.com/snarktank/ralph) - HIGH confidence, canonical implementation
- [Braintrust: Canonical Agent Architecture](https://www.braintrust.dev/blog/agent-while-loop) - HIGH confidence, clear pattern
- [Chris M.D.P.: Your Agent Orchestrator Is Too Clever](https://www.chrismdp.com/your-agent-orchestrator-is-too-clever/) - MEDIUM confidence, practitioner experience
- [Simon Willison: Designing Agentic Loops](https://simonwillison.net/2025/Sep/30/designing-agentic-loops/) - MEDIUM confidence, practitioner experience
- [Ralph CC Loop](https://github.com/thecgaigroup/ralph-cc-loop) - HIGH confidence, Claude Code adaptation
- [LangGraph Architecture](https://latenode.com/blog/langgraph-ai-framework-2025-complete-architecture-guide-multi-agent-orchestration-analysis) - MEDIUM confidence, enterprise patterns

---

*Architecture research: 2026-01-19*
