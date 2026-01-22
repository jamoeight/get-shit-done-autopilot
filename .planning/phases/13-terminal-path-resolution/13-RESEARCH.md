# Phase 13: Terminal Path Resolution Fix - Research

**Researched:** 2026-01-21
**Domain:** Windows terminal spawning, bash variant path resolution, cross-platform compatibility
**Confidence:** HIGH

## Summary

Phase 13 addresses a critical bug where autopilot fails on Windows when the user's Windows Terminal default profile isn't Git Bash. The root cause is that `wt.exe` spawns the user's configured default profile (which may be Git Bash, WSL, Cygwin, or PowerShell), but the current code assumes Git Bash path format (`/c/Users/...`).

The solution involves two complementary changes:
1. **Terminal launcher hardening (Node.js):** Check Git Bash existence at multiple locations before wt.exe launch, with graceful fallback to cmd.exe
2. **Runtime path resolution (bash):** Detect the bash environment at runtime and convert paths using native tools (`cygpath`, `wslpath`)

The project already has extensive research in `.planning/research/` documenting failed approaches, pitfalls, and recommended patterns. This phase consolidates that research into actionable implementation guidance.

**Primary recommendation:** Implement Git Bash existence check with multi-path fallback in terminal-launcher.js, then add runtime path detection to ralph.sh for universal compatibility.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Node.js `fs` | Built-in | File existence checks | Native, no dependencies |
| Node.js `child_process` | Built-in | Terminal spawning | Already used in terminal-launcher.js |
| `cygpath` | Ships with Git Bash | Path conversion | Authoritative tool for MSYS2/Git Bash |
| `wslpath` | Ships with WSL | Path conversion | Microsoft's official WSL path converter |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `command-exists` | Current | Terminal detection | Already a project dependency |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual path detection | `is-wsl` npm package | Adds dependency; detection logic is simple enough to inline |
| Profile JSON parsing | Windows Terminal `-p` flag | Profile names vary by user; unreliable |

**Installation:**
No new dependencies required. All tools are either built-in to Node.js or ship with the target bash environments.

## Architecture Patterns

### Recommended Project Structure
```
bin/lib/terminal-launcher.js
    |
    +-- findGitBash()           # NEW: Multi-location search
    +-- toGitBashPath()         # Existing (keep for cmd.exe, powershell)
    +-- launchWindowsTerminal() # Modify: use findGitBash(), add fallback
    +-- launchCmd()             # Unchanged
    +-- ...other launchers      # Unchanged

bin/ralph.sh
    |
    +-- detect_bash_env()       # NEW: Runtime environment detection
    +-- resolve_path()          # NEW: Universal path conversion
    +-- ... existing code
```

### Pattern 1: Multi-Location Git Bash Detection
**What:** Check multiple common Git Bash installation paths before attempting launch
**When to use:** Before spawning wt.exe with explicit Git Bash path

```javascript
// Source: Project research + standard installation patterns
const GIT_BASH_CANDIDATES = [
  'C:\\Program Files\\Git\\bin\\bash.exe',           // Standard 64-bit
  'C:\\Program Files (x86)\\Git\\bin\\bash.exe',     // Standard 32-bit
  'C:\\Git\\bin\\bash.exe',                          // Custom root install
  process.env.USERPROFILE + '\\scoop\\apps\\git\\current\\bin\\bash.exe', // Scoop user
  'C:\\ProgramData\\scoop\\apps\\git\\current\\bin\\bash.exe'  // Scoop global
];

function findGitBash() {
  for (const candidate of GIT_BASH_CANDIDATES) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return null;
}
```

### Pattern 2: Runtime Bash Environment Detection
**What:** Detect which bash variant is running using environment variables
**When to use:** At ralph.sh startup, before any path operations

```bash
# Source: Official MSYS2, WSL documentation
detect_bash_env() {
  if [ -n "$WSL_DISTRO_NAME" ]; then
    echo "wsl"
  elif [ -n "$MSYSTEM" ]; then
    echo "msys"  # Git Bash, MSYS2
  elif [[ "$OSTYPE" == cygwin* ]]; then
    echo "cygwin"
  else
    echo "unknown"
  fi
}
```

### Pattern 3: Native Tool Path Conversion
**What:** Use cygpath/wslpath for path conversion instead of regex
**When to use:** Always prefer native tools when available

```bash
# Source: MSYS2/Cygwin documentation
resolve_path() {
  local win_path="$1"

  # Try native tools first (authoritative)
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$win_path" 2>/dev/null && return 0
  fi
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -u "$win_path" 2>/dev/null && return 0
  fi

  # Fallback: manual conversion
  # ...pattern matching code
}
```

### Pattern 4: Fallback Chain
**What:** Try multiple approaches until one works
**When to use:** For maximum compatibility across environments

```bash
# Try each format until directory exists
resolve_and_cd() {
  local target="$1"

  # Already valid path?
  [ -d "$target" ] && cd "$target" && return 0

  # Try converter tools
  if command -v cygpath >/dev/null 2>&1; then
    cd "$(cygpath -u "$target")" 2>/dev/null && return 0
  fi
  if command -v wslpath >/dev/null 2>&1; then
    cd "$(wslpath -u "$target")" 2>/dev/null && return 0
  fi

  # Pattern-based fallback for C:\path format
  if [[ "$target" =~ ^([A-Za-z]):[/\\] ]]; then
    local drive="${BASH_REMATCH[1],,}"  # lowercase
    local rest="${target:3}"
    rest="${rest//\\//}"  # backslash to forward slash

    for prefix in "/mnt/$drive" "/$drive" "/cygdrive/$drive"; do
      [ -d "${prefix}/${rest}" ] && cd "${prefix}/${rest}" && return 0
    done
  fi

  return 1
}
```

### Anti-Patterns to Avoid
- **Assuming a specific bash variant:** Don't hardcode `/c/Users/...` without detection
- **Using regex before native tools:** `cygpath`/`wslpath` handle edge cases better
- **Synchronous pre-spawn detection:** The bash that responds to detection may differ from what wt.exe spawns
- **Unquoted paths:** Always quote paths to handle spaces and special characters

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Path format conversion | Custom regex | `cygpath -u`, `wslpath -u` | Native tools handle edge cases (UNC, long paths, special chars) |
| Bash environment detection | Parse shell output | Check `$OSTYPE`, `$MSYSTEM`, `$WSL_DISTRO_NAME` | Built-in variables are authoritative and instant |
| File existence check | Custom stat wrapper | `fs.existsSync()` | Node.js built-in, well-tested |
| Terminal availability | PATH scanning | `command-exists` package | Already a project dependency, cross-platform |

**Key insight:** Each bash variant (Git Bash, WSL, Cygwin) provides its own path conversion tool that knows the correct format. Don't guess - use the native tool.

## Common Pitfalls

### Pitfall 1: wt.exe Default Profile Assumption
**What goes wrong:** Code assumes `wt.exe` will spawn Git Bash, but user's default profile might be WSL, PowerShell, or cmd
**Why it happens:** Windows Terminal uses configured default profile, not necessarily bash
**How to avoid:** Either force explicit Git Bash binary, or handle path resolution at runtime in the bash script
**Warning signs:** Error shows `/bin/bash` (WSL) instead of `/usr/bin/bash` (Git Bash)

### Pitfall 2: Git Bash Not at Standard Path
**What goes wrong:** Hardcoded `C:\Program Files\Git\bin\bash.exe` fails for users with non-standard installs
**Why it happens:** Scoop, Chocolatey, manual installs use different paths
**How to avoid:** Check multiple candidate paths; fall back to cmd.exe if none found
**Warning signs:** `ENOENT` or "bash.exe not found" errors

### Pitfall 3: Unquoted Paths with Spaces
**What goes wrong:** `/c/Program Files/...` splits into multiple arguments
**Why it happens:** Shell word splitting on unquoted strings
**How to avoid:** Always wrap paths in double quotes: `cd "${path}"`
**Warning signs:** "command not found" errors mentioning partial path

### Pitfall 4: cygpath vs wslpath Confusion
**What goes wrong:** Using cygpath in WSL or wslpath in Git Bash
**Why it happens:** Wrong assumption about which bash is running
**How to avoid:** Check which tool exists with `command -v cygpath`/`command -v wslpath`
**Warning signs:** "command not found: cygpath" or incorrect path format

### Pitfall 5: Backslash Escaping in Node.js Strings
**What goes wrong:** Windows paths with backslashes get mangled
**Why it happens:** JavaScript string escape sequences consume backslashes
**How to avoid:** Escape backslashes (`\\`) or use forward slashes (Windows accepts both)
**Warning signs:** Paths missing drive letters or segments

### Pitfall 6: Pre-spawn Detection Race Condition
**What goes wrong:** Detect one bash type but wt.exe spawns different one
**Why it happens:** `bash -c "echo $OSTYPE"` tests PATH bash, not wt.exe's default profile
**How to avoid:** Do detection AT RUNTIME inside the spawned script, not before spawn
**Warning signs:** Detection says "msys" but error shows WSL paths

## Code Examples

Verified patterns from official sources and project experience:

### Git Bash Multi-Location Search (Node.js)
```javascript
// Source: Standard installation paths, package manager conventions
const fs = require('fs');
const path = require('path');

const GIT_BASH_CANDIDATES = [
  'C:\\Program Files\\Git\\bin\\bash.exe',
  'C:\\Program Files (x86)\\Git\\bin\\bash.exe',
  'C:\\Git\\bin\\bash.exe',
  path.join(process.env.USERPROFILE || '', 'scoop', 'apps', 'git', 'current', 'bin', 'bash.exe'),
  'C:\\ProgramData\\scoop\\apps\\git\\current\\bin\\bash.exe'
];

function findGitBash() {
  for (const candidate of GIT_BASH_CANDIDATES) {
    try {
      if (fs.existsSync(candidate)) {
        return candidate;
      }
    } catch (e) {
      continue;
    }
  }
  return null;
}
```

### Runtime Environment Detection (Bash)
```bash
# Source: MSYS2 documentation, WSL documentation
detect_bash_env() {
  # WSL sets this variable
  if [ -n "$WSL_DISTRO_NAME" ]; then
    echo "wsl"
    return
  fi

  # MSYS2/Git Bash sets MSYSTEM (MINGW64, MINGW32, MSYS, UCRT64, CLANG64)
  if [ -n "$MSYSTEM" ]; then
    echo "msys"
    return
  fi

  # Cygwin has distinct OSTYPE
  if [[ "$OSTYPE" == cygwin* ]]; then
    echo "cygwin"
    return
  fi

  echo "unknown"
}
```

### Universal Path Resolution (Bash)
```bash
# Source: MSYS2 docs, Cygwin cygpath manual, WSL docs
resolve_win_path() {
  local win_path="$1"

  # Try cygpath (available in Git Bash, MSYS2, Cygwin)
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$win_path" 2>/dev/null && return 0
  fi

  # Try wslpath (available in WSL)
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -u "$win_path" 2>/dev/null && return 0
  fi

  # Manual fallback: C:\foo -> /c/foo or /mnt/c/foo
  if [[ "$win_path" =~ ^([A-Za-z]):[/\\](.*)$ ]]; then
    local drive="${BASH_REMATCH[1],,}"
    local rest="${BASH_REMATCH[2]//\\//}"

    # Try WSL format first (more common now)
    if [ -d "/mnt/$drive" ]; then
      echo "/mnt/$drive/$rest"
      return 0
    fi

    # Then Git Bash format
    if [ -d "/$drive" ]; then
      echo "/$drive/$rest"
      return 0
    fi

    # Then Cygwin format
    if [ -d "/cygdrive/$drive" ]; then
      echo "/cygdrive/$drive/$rest"
      return 0
    fi
  fi

  # Return as-is if nothing worked
  echo "$win_path"
}
```

### Modified wt.exe Launcher with Fallback (Node.js)
```javascript
// Source: Project architecture research
function launchWindowsTerminal(scriptPath, windowTitle = 'GSD') {
  const gitBashPath = findGitBash();

  if (!gitBashPath) {
    // Signal to findTerminal() to try next terminal (cmd.exe)
    return null;
  }

  const cwd = process.cwd();
  const bashScript = toGitBashPath(scriptPath);
  const bashCwd = toGitBashPath(cwd);

  return spawn('wt.exe', [
    '--title', windowTitle,
    gitBashPath, '--login', '-c', `cd "${bashCwd}" && bash "${bashScript}"`
  ], {
    detached: true,
    stdio: 'ignore',
    cwd: cwd,
    shell: false
  });
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded Git Bash path | Multi-location search + fallback | v1.2 (this phase) | Works for Scoop, Chocolatey, custom installs |
| Pre-spawn bash detection | Runtime detection in script | v1.2 (this phase) | Handles wt.exe profile variations |
| Single path format | Native tool conversion + fallback chain | v1.2 (this phase) | Universal compatibility |

**Deprecated/outdated:**
- `fs.exists()` (callback-based) - Use `fs.existsSync()` for startup checks
- Assuming wt.exe spawns Git Bash - User's default profile varies

## Open Questions

Things that couldn't be fully resolved:

1. **KB5050021 wt.exe Bug**
   - What we know: Some Windows updates cause wt.exe to fail silently when spawned programmatically
   - What's unclear: Exact Windows versions affected, whether Microsoft has patched it
   - Recommendation: Implement graceful fallback to cmd.exe; don't rely solely on wt.exe

2. **UNC/Network Path Support**
   - What we know: Network paths (`\\server\share`) have limited support across bash variants
   - What's unclear: Full compatibility matrix for network paths
   - Recommendation: Warn and fail early for UNC paths with clear error message

3. **ARM64 Windows Support**
   - What we know: Git for Windows has ARM64 builds
   - What's unclear: Installation paths on ARM64 Windows
   - Recommendation: Add ARM64 path candidates if issue reports surface

## Sources

### Primary (HIGH confidence)
- [MSYS2 Filesystem Paths](https://www.msys2.org/docs/filesystem-paths/) - Path format documentation
- [Cygwin cygpath Manual](https://cygwin.com/cygwin-ug-net/cygpath.html) - cygpath usage
- [Windows Terminal CLI Arguments](https://learn.microsoft.com/en-us/windows/terminal/command-line-arguments) - wt.exe flags
- [Node.js fs Documentation](https://nodejs.org/api/fs.html) - fs.existsSync usage
- [Node.js child_process Documentation](https://nodejs.org/api/child_process.html) - spawn usage

### Secondary (MEDIUM confidence)
- [Windows Terminal GitHub Issue #1394](https://github.com/microsoft/terminal/issues/1394) - Git Bash profile detection
- [Git for Windows Installation](https://git-scm.com/download/win) - Standard paths
- [Chocolatey Default Install Reasoning](https://docs.chocolatey.org/en-us/default-chocolatey-install-reasoning/) - Package manager paths

### Project Experience (HIGH confidence)
- `.planning/research/PITFALLS-terminal-path.md` - 13 documented pitfalls
- `.planning/research/v1.2-terminal-path/FEATURES.md` - Pattern comparisons
- `.planning/milestones/v1.2-terminal-path-fix/STACK-RESEARCH.md` - Tool evaluation
- `.planning/research/v1.2-TERMINAL-PATH-ARCHITECTURE.md` - Architecture options
- Commits `307cb70`, `8502138`, `82ae4c1`, `538155e`, `28739db` - Failed attempt history

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using built-in Node.js and native bash tools
- Architecture: HIGH - Validated through project research and failure analysis
- Pitfalls: HIGH - Documented from actual project failures

**Research date:** 2026-01-21
**Valid until:** Path handling fundamentals are stable; check for wt.exe updates
