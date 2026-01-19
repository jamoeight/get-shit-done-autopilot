#!/bin/bash
# GSD Ralph - Exit Condition Detection
# Part of Phase 5: Exit Conditions
#
# Provides stuck detection, graceful interrupt handling, and exit status functions.
# Functions: check_stuck, reset_failure_tracking, handle_interrupt, check_interrupted,
#            enter_critical_section, exit_critical_section, exit_with_status
#
# Exit codes:
#   0 = COMPLETED (all tasks done)
#   1 = STUCK (same task failed consecutively)
#   2 = ABORTED (iteration cap reached)
#   3 = INTERRUPTED (user Ctrl+C)
#
# Usage:
#   source bin/lib/exit.sh
#   trap 'handle_interrupt' INT
#   check_stuck "05-01" && echo "Stuck!" || echo "Not stuck"

# =============================================================================
# Exit Code Constants
# =============================================================================

EXIT_COMPLETED=0
EXIT_STUCK=1
EXIT_ABORTED=2
EXIT_INTERRUPTED=3

# =============================================================================
# State Variables
# =============================================================================

# Failure tracking
CONSECUTIVE_FAILURES=0
LAST_FAILED_TASK=""
STUCK_THRESHOLD=3

# Interrupt handling
INTERRUPTED=false
IN_CRITICAL_SECTION=false

# =============================================================================
# Color Codes (respect NO_COLOR standard)
# =============================================================================

if [[ -n "${NO_COLOR:-}" ]]; then
    EXIT_RED=''
    EXIT_GREEN=''
    EXIT_YELLOW=''
    EXIT_CYAN=''
    EXIT_BOLD=''
    EXIT_RESET=''
else
    EXIT_RED='\e[31m'
    EXIT_GREEN='\e[32m'
    EXIT_YELLOW='\e[33m'
    EXIT_CYAN='\e[36m'
    EXIT_BOLD='\e[1m'
    EXIT_RESET='\e[0m'
fi

# =============================================================================
# Stuck Detection Functions
# =============================================================================

# check_stuck - Check if we're stuck on the same task
# Args: task_id (string, e.g., "05-01")
# Returns: 0 if stuck (threshold reached), 1 if not stuck
# Side effects: Updates CONSECUTIVE_FAILURES and LAST_FAILED_TASK
check_stuck() {
    local task_id="$1"

    if [[ -z "$task_id" ]]; then
        echo -e "${EXIT_RED}Error: check_stuck requires task_id${EXIT_RESET}" >&2
        return 1
    fi

    if [[ "$task_id" == "$LAST_FAILED_TASK" ]]; then
        # Same task failed again - increment counter
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    else
        # Different task - reset counter
        CONSECUTIVE_FAILURES=1
        LAST_FAILED_TASK="$task_id"
    fi

    # Check if threshold reached
    if [[ "$CONSECUTIVE_FAILURES" -ge "$STUCK_THRESHOLD" ]]; then
        return 0  # Stuck
    fi

    return 1  # Not stuck
}

# reset_failure_tracking - Reset stuck detection after success
# Called when a task succeeds to clear the failure counter
reset_failure_tracking() {
    CONSECUTIVE_FAILURES=0
    LAST_FAILED_TASK=""
}

# =============================================================================
# Interrupt Handling Functions
# =============================================================================

# handle_interrupt - SIGINT handler for graceful Ctrl+C
# If in critical section, defers interrupt; otherwise sets flag immediately
handle_interrupt() {
    if [[ "$IN_CRITICAL_SECTION" == "true" ]]; then
        # Defer handling - will be checked after critical section exits
        INTERRUPTED=true
        echo -e "\n${EXIT_YELLOW}Interrupt received - will exit after critical section completes${EXIT_RESET}" >&2
    else
        INTERRUPTED=true
        echo -e "\n${EXIT_YELLOW}Interrupt received - will exit at next safe point${EXIT_RESET}" >&2
    fi
}

# check_interrupted - Check if interrupt flag is set
# Returns: 0 if interrupted, 1 if not interrupted
check_interrupted() {
    if [[ "$INTERRUPTED" == "true" ]]; then
        return 0  # Interrupted
    fi
    return 1  # Not interrupted
}

# enter_critical_section - Mark start of critical section
# Critical sections (like git commits) should not be interrupted mid-operation
enter_critical_section() {
    IN_CRITICAL_SECTION=true
}

# exit_critical_section - Mark end of critical section
# Checks if interrupt was deferred and prints message if so
exit_critical_section() {
    IN_CRITICAL_SECTION=false

    # If interrupt was deferred, notify that we'll handle it now
    if [[ "$INTERRUPTED" == "true" ]]; then
        echo -e "${EXIT_YELLOW}Critical section complete - processing deferred interrupt${EXIT_RESET}" >&2
    fi
}

# =============================================================================
# Exit Status Functions
# =============================================================================

# exit_with_status - Log exit status and return appropriate exit code
# Args: status (COMPLETED/STUCK/ABORTED/INTERRUPTED), reason, last_task, iteration_count, duration
# Returns: Exit code (does NOT call exit - caller decides)
# Calls log_exit_status to update STATE.md, then prints terminal message
exit_with_status() {
    local status="$1"
    local reason="$2"
    local last_task="$3"
    local iteration_count="$4"
    local duration="$5"

    if [[ -z "$status" || -z "$reason" ]]; then
        echo -e "${EXIT_RED}Error: exit_with_status requires status and reason${EXIT_RESET}" >&2
        return 1
    fi

    # Log to STATE.md (function from state.sh)
    if type log_exit_status &>/dev/null; then
        log_exit_status "$status" "$reason" "$last_task" "$iteration_count" "$duration"
    fi

    # Print terminal message with appropriate color
    local color
    local exit_code

    case "$status" in
        COMPLETED)
            color="$EXIT_GREEN"
            exit_code=$EXIT_COMPLETED
            ;;
        STUCK)
            color="$EXIT_RED"
            exit_code=$EXIT_STUCK
            ;;
        ABORTED)
            color="$EXIT_YELLOW"
            exit_code=$EXIT_ABORTED
            ;;
        INTERRUPTED)
            color="$EXIT_YELLOW"
            exit_code=$EXIT_INTERRUPTED
            ;;
        *)
            color="$EXIT_RED"
            exit_code=1
            ;;
    esac

    echo ""
    echo -e "${EXIT_BOLD}${color}=== Ralph Exit: $status ===${EXIT_RESET}"
    echo -e "Reason: $reason"
    if [[ -n "$last_task" ]]; then
        echo -e "Last task: $last_task"
    fi
    if [[ -n "$iteration_count" ]]; then
        echo -e "Iterations: $iteration_count"
    fi
    if [[ -n "$duration" ]]; then
        # Format duration if it's a number
        if [[ "$duration" =~ ^[0-9]+$ ]]; then
            local hours=$((duration / 3600))
            local minutes=$(((duration % 3600) / 60))
            echo -e "Duration: ${hours}h ${minutes}m"
        else
            echo -e "Duration: $duration"
        fi
    fi
    echo ""

    return $exit_code
}
