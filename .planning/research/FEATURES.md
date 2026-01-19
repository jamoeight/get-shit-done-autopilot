# Feature Landscape: Autonomous AI Agent Development Loops

**Domain:** "Fire and forget" overnight autonomous coding execution
**Researched:** 2026-01-19
**Confidence:** HIGH (multiple authoritative sources, cross-verified with industry patterns)

---

## Table Stakes

Features users expect. Missing = autonomous loop fails or is unusable.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Retry Loop with Exit Condition** | Without it, failure = dead stop. Agents need multiple attempts. | Medium | Core of ralph pattern. Exit when tests pass + requirements met. |
| **Maximum Iteration Limit** | Prevents runaway costs. Users set token budget. | Low | Configurable cap (e.g., 100 iterations). Critical safety net. |
| **Fresh Context Per Iteration** | Context degradation kills quality after ~30 minutes. Clean slate each attempt. | Low | Ralph pattern fundamental. Each iteration = new agent instance. |
| **State Persistence via Files** | Fresh context means no memory. State files bridge iterations. | Low | Already exists in GSD (PLAN.md, STATE.md, SUMMARY.md). |
| **Git Commits as Checkpoints** | Progress must survive crashes. Git = persistent progress. | Low | Already exists. Each execution commits work. |
| **Test-Based Success Criteria** | Binary pass/fail. Objective. No hallucinated "done" claims. | Medium | Tests pass = exit. Tests fail = retry. No ambiguity. |
| **Stuck Loop Detection** | Prevents infinite "same failure" cycles. | Medium | Detect repeated failures on same task, force different approach or exit. |
| **Upfront Planning Generation** | User walks away. ALL plans must exist before execution starts. | Medium | `/gsd:plan-milestone-all` — generate every PLAN.md before ralph begins. |
| **Atomic Task Sizing** | Tasks must fit in one context window (~200k tokens). | Low | Already in GSD design. Ralph pattern requirement. |
| **Clear Progress Indicator** | User returns to understand what happened. | Low | STATE.md or progress log updated each iteration. |

### Why These Are Table Stakes

**Research Evidence:**

- [Faros AI](https://www.faros.ai/blog/best-ai-coding-agents-2026): "Even the best AI coding agents achieve only 60% overall accuracy... 1 in 5 tasks need human intervention."
- [Google ADK](https://google.github.io/adk-docs/plugins/reflect-and-retry/): "Reflect and Retry plugin intercepts tool failures, provides structured guidance for reflection and correction, retries up to configurable limit."
- [Ralph pattern](https://github.com/snarktank/ralph): "Each iteration spawns a new instance with clean context. Memory persists via git history, progress.txt, and prd.json."
- [Sparkco](https://sparkco.ai/blog/mastering-retry-logic-agents-a-deep-dive-into-2025-best-practices): "Adaptive retry strategies that blend exponential backoff with jitter... preventing the 'thundering herd' problem."
- [Tweag Agentic Coding Handbook](https://tweag.github.io/agentic-coding-handbook/WORKFLOW_TDD/): "Tests give us a reliable exit criteria. We are not relying on AI agent's whims, but we force it to iterate until previously failed tests pass."

---

## Differentiators

Features that separate good autonomous loops from great ones. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Intelligent Stuck Detection** | Instead of just "same failure 3x = stop," analyze WHY stuck and try alternative approach. | High | IBM STRATUS pattern: undo-and-retry with safe exploration paths. |
| **Checkpointing with Resume** | Process dies at 3am? Resume from last checkpoint, not start over. | High | LangGraph/Microsoft Agent Framework patterns. Beyond git commits. |
| **Learnings Propagation** | Each iteration discovers patterns. Future iterations benefit. | Medium | Ralph's AGENTS.md updates. "Discovered patterns, gotchas, conventions." |
| **Dual-Exit Gate** | Require BOTH completion indicators AND explicit exit signal. Prevents premature exit. | Medium | frankbria/ralph-claude-code pattern. Two conditions, not one. |
| **Cost Tracking** | Show token usage per iteration, cumulative cost. | Medium | Users want to know spend. Useful for budget refinement. |
| **Circuit Breaker Pattern** | After N consecutive failures, pause and wait. Don't keep burning tokens. | Medium | frankbria/ralph-claude-code: "Circuit breaker with advanced error detection." |
| **Parallel Phase Execution** | Independent phases run simultaneously. | High | Cursor runs "up to 8 agents in parallel." Faster completion. |
| **Sub-Agent Delegation** | Orchestrator spawns specialized sub-agents for research, testing, etc. | Medium | Already in GSD architecture. Claude Code Task tool. |
| **Progress Notifications** | Optional alerts on completion/failure. | Low | Out of scope per PROJECT.md, but differentiator for others. |
| **Rollback on Catastrophic Failure** | If everything breaks, restore last-known-good state. | High | Explicitly out of scope for GSD. Complex to implement correctly. |

### Why These Differentiate

**Research Evidence:**

- [IBM STRATUS (NeurIPS 2025)](https://research.ibm.com/blog/undo-agent-for-cloud): "Undo-and-retry mechanism... agent was able to safely explore new mitigation paths and seemed to perform better with each new attempt."
- [LangGraph 1.0](https://sparkco.ai/blog/mastering-langgraph-checkpointing-best-practices-for-2025): "Allows workflow to pause at a node, save entire execution state, and later resume from that checkpoint."
- [Microsoft Agent Framework](https://techcommunity.microsoft.com/blog/appsonazureblog/bulletproof-agents-with-the-durable-task-extension-for-microsoft-agent-framework/4467122): "Agent sessions are automatically checkpointed in durable storage... any instance can resume execution after interruptions."
- [Redmonk Developer Survey](https://redmonk.com/kholterhoff/2025/12/22/10-things-developers-want-from-their-agentic-ides-in-2025/): "The promise of 'fire and forget' has captured the developer imagination."

---

## Anti-Features

Features to explicitly NOT build. Either add complexity without proportional value, or actively harm the system.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Per-Agent Ralph Loops** | Coordination complexity explodes. Which agent is responsible? Race conditions. | Single loop at milestone level. One task at a time. Simpler. |
| **Real-Time Dashboard/UI** | User walks away. Dashboard unseen. Wasted effort. | Write to files. User reads on return. |
| **Token Cost Estimation** | Highly variable. Inaccurate estimates frustrate users. | Let user set max iterations. Simple mental model. |
| **Automatic Rollback** | "Forward-only" is simpler. Rollback requires understanding causality. | Ralph pattern: retry forward with fresh context. Don't undo. |
| **Human Intervention Points** | Defeats "fire and forget." If human needed, use Interactive mode. | Lazy mode = zero human. Interactive mode exists for checkpoints. |
| **Complex Scheduling** | "Run at 2am" adds cron-like complexity. | User starts when ready. Process runs to completion. |
| **Multi-Milestone Orchestration** | One milestone is enough scope. Chaining adds failure modes. | User manually starts next milestone when current completes. |
| **Model Auto-Selection** | Different models have different costs/capabilities. User should decide. | User configures model. System uses it consistently. |
| **Partial Success Commits** | "50% done" commits pollute history. | Atomic commits: feature works or doesn't. |
| **Aggressive Context Summarization** | Lossy. Critical details vanish. | Fresh context per iteration. Full state files. No summarization. |

### Why These Are Anti-Features

**Research Evidence:**

- [PROJECT.md context](C:\Users\Jameson\Downloads\get-everything-done\get-shit-done\.planning\PROJECT.md): "Per-agent ralph loops — adds coordination complexity, milestone-level loop is simpler."
- [PROJECT.md context](C:\Users\Jameson\Downloads\get-everything-done\get-shit-done\.planning\PROJECT.md): "Real-time notifications/alerts — user walks away, checks results later."
- [Ralph pattern](https://github.com/snarktank/ralph): "Each iteration is a fresh Amp instance with clean context." (Not partial context.)
- [Machine Learning Mastery](https://machinelearningmastery.com/7-agentic-ai-trends-to-watch-in-2026/): "Bounded autonomy architectures with clear operational limits, escalation paths to humans for high-stakes decisions" — but this is for production systems, not overnight dev execution.

---

## Feature Dependencies

```
                    +-----------------------+
                    | Upfront Planning Gen  |
                    | (plan-milestone-all)  |
                    +-----------+-----------+
                                |
                                v
                    +-----------------------+
                    | State Persistence     |
                    | (PLAN.md, STATE.md)   |
                    +-----------+-----------+
                                |
                                v
+-------------------+   +-------------------+   +-------------------+
| Retry Loop        |-->| Fresh Context     |-->| Git Commits       |
| (ralph pattern)   |   | Per Iteration     |   | (checkpoints)     |
+-------------------+   +-------------------+   +-------------------+
        |                       |
        v                       v
+-------------------+   +-------------------+
| Max Iteration     |   | Stuck Loop        |
| Limit             |   | Detection         |
+-------------------+   +-------------------+
        |                       |
        +----------+------------+
                   |
                   v
        +-------------------+
        | Test-Based Exit   |
        | Criteria          |
        +-------------------+
                   |
                   v
        +-------------------+
        | Progress Indicator|
        | (STATE.md update) |
        +-------------------+
```

**Dependency Explanation:**

1. **Upfront Planning** must complete before execution starts (generates all PLAN.md files)
2. **State Persistence** enables retry loop to know what's done/remaining
3. **Retry Loop** requires fresh context per iteration to avoid degradation
4. **Git Commits** checkpoint progress so crashes don't lose work
5. **Max Iteration Limit** and **Stuck Detection** are safety rails on the retry loop
6. **Test-Based Exit** is the termination condition for the retry loop
7. **Progress Indicator** is updated each iteration for user visibility

---

## MVP Recommendation

For MVP Lazy Mode, prioritize:

### Phase 1: Core Loop (Must Have)

1. **Upfront Planning Generation** — `/gsd:plan-milestone-all` command
2. **Retry Loop with Max Iterations** — `/gsd:ralph` configuration
3. **Test-Based Exit Criteria** — All tests pass = done
4. **Fresh Context Per Iteration** — Spawn new agent each time
5. **Progress Persistence** — STATE.md updated each iteration

### Phase 2: Safety Rails (Must Have)

6. **Stuck Loop Detection** — Detect repeated failures, exit gracefully
7. **Git Commits as Checkpoints** — Already exists, ensure used

### Defer to Post-MVP

- **Intelligent Stuck Detection** (High complexity): For v1, simple "3 failures on same task = exit" is sufficient
- **Checkpointing with Resume** (High complexity): Git commits provide basic crash recovery
- **Learnings Propagation** (Medium complexity): Nice-to-have, not essential for loop to function
- **Cost Tracking** (Medium complexity): User can check API dashboard
- **Parallel Phase Execution** (High complexity): Sequential is simpler, fast enough for overnight

---

## Complexity Assessment

| Feature | Complexity | Rationale |
|---------|------------|-----------|
| Retry Loop | Medium | Core logic, but well-documented pattern (ralph) |
| Max Iteration Limit | Low | Counter increment, simple comparison |
| Fresh Context | Low | Already how GSD spawns subagents |
| State Persistence | Low | Already exists in GSD |
| Git Commits | Low | Already exists in GSD |
| Test-Based Exit | Medium | Need to run tests, parse results, determine pass/fail |
| Stuck Detection | Medium | Track failure history, detect patterns |
| Upfront Planning | Medium | Modify existing planner to loop for all phases |
| Progress Indicator | Low | Write to file each iteration |
| Intelligent Stuck | High | Requires reasoning about failure causes |
| Checkpointing/Resume | High | Beyond git — serialize execution state |
| Learnings Propagation | Medium | Write to AGENTS.md or equivalent |
| Dual-Exit Gate | Medium | Two conditions, both must be true |
| Cost Tracking | Medium | Track API calls, estimate tokens |
| Circuit Breaker | Medium | Consecutive failure counter |
| Parallel Execution | High | Coordination, merging, conflict resolution |

---

## Success Metrics

How to know if the autonomous loop is working:

| Metric | Target | Why |
|--------|--------|-----|
| Milestone completion rate | >80% without intervention | User can walk away with confidence |
| Average iterations to complete | <10 for typical milestone | Shows efficiency, not just retry-spam |
| Stuck detection accuracy | >90% true positives | Exits when actually stuck, not prematurely |
| Test false-pass rate | <5% | Tests correctly validate completion |
| User satisfaction | "I slept, code was done" | The whole point |

---

## Sources

### High Confidence (Official Documentation, Context7)
- [Anthropic: Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Anthropic: Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)
- [Google ADK: Reflect and Retry](https://google.github.io/adk-docs/plugins/reflect-and-retry/)
- [Google ADK: Loop Agents](https://google.github.io/adk-docs/agents/workflow-agents/loop-agents/)
- [Microsoft Agent Framework: Checkpointing](https://learn.microsoft.com/en-us/agent-framework/tutorials/workflows/checkpointing-and-resuming)
- [OpenTelemetry: AI Agent Observability](https://opentelemetry.io/blog/2025/ai-agent-observability/)

### Medium Confidence (Verified with Multiple Sources)
- [Ralph Pattern (GitHub)](https://github.com/snarktank/ralph) — 4.4k stars, well-documented
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) — Circuit breaker implementation
- [Tweag Agentic Coding Handbook: TDD](https://tweag.github.io/agentic-coding-handbook/WORKFLOW_TDD/)
- [LangGraph Checkpointing Best Practices](https://sparkco.ai/blog/mastering-langgraph-checkpointing-best-practices-for-2025)
- [IBM STRATUS: Undo-and-Retry](https://research.ibm.com/blog/undo-agent-for-cloud) — NeurIPS 2025

### Low Confidence (Single Source, Unverified)
- [Faros AI: Agent Comparison](https://www.faros.ai/blog/best-ai-coding-agents-2026) — Blog post, cross-verify claims
- [Redmonk Developer Survey](https://redmonk.com/kholterhoff/2025/12/22/10-things-developers-want-from-their-agentic-ides-in-2025/) — Opinion piece

---

*Research completed: 2026-01-19*
