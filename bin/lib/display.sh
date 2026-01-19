#!/bin/bash
# GSD Ralph - Progress Display
# Part of Phase 1: Safety Foundation
#
# Provides terminal progress display for the ralph loop.
# Functions: format_duration, show_progress, show_status

# Color codes for terminal output
# Using \e format for compatibility with both Unix and Windows Git Bash
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
BOLD='\e[1m'
RESET='\e[0m'

# format_duration - Convert seconds to "Nh NNm" format
# Args: seconds
# Output: Formatted duration string (e.g., "1h 05m", "0h 30m")
format_duration() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    printf "%dh %02dm" "$hours" "$minutes"
}

# show_progress - Display iteration status
# Args: iteration, max_iterations, current_task, next_task (optional)
# Requires: START_TIME (global, epoch seconds when loop started)
#           TIMEOUT_HOURS (global, from budget config)
show_progress() {
    local iteration="$1"
    local max_iterations="$2"
    local current_task="$3"
    local next_task="${4:-}"

    # Calculate elapsed time
    local now
    now=$(date +%s)
    local elapsed=$((now - START_TIME))
    local elapsed_fmt
    elapsed_fmt=$(format_duration "$elapsed")

    # Calculate remaining time (based on timeout, not iterations)
    local timeout_seconds=$((TIMEOUT_HOURS * 3600))
    local remaining=$((timeout_seconds - elapsed))
    if [ "$remaining" -lt 0 ]; then
        remaining=0
    fi
    local remaining_fmt
    remaining_fmt=$(format_duration "$remaining")

    # Display progress line
    echo -e "${BOLD}${CYAN}Iteration $iteration/$max_iterations${RESET} | ${elapsed_fmt} elapsed | ${remaining_fmt} remaining"

    # Show completed task
    echo -e "  ${GREEN}Completed:${RESET} $current_task"

    # Show next task if provided
    if [ -n "$next_task" ]; then
        echo -e "  ${YELLOW}Starting:${RESET} $next_task"
    fi

    echo ""
}

# show_status - Show single-line status update
# Args: message, type (info/success/error/warning)
show_status() {
    local message="$1"
    local type="${2:-info}"

    local color
    case "$type" in
        success)
            color="$GREEN"
            ;;
        error)
            color="$RED"
            ;;
        warning)
            color="$YELLOW"
            ;;
        info|*)
            color="$CYAN"
            ;;
    esac

    echo -e "${color}${message}${RESET}"
}
