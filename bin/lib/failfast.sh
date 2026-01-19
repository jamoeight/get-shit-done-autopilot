#!/bin/bash
# GSD Ralph - Fail-Fast Error Handling
# Part of Phase 1: Safety Foundation
#
# Provides:
#   run_with_retry    - Retry command up to 3 times
#   run_claude_task   - Execute Claude CLI with error handling
#   mark_checkpoint   - Record git HEAD as rollback point
#   rollback_to_checkpoint - Reset to last checkpoint
#   check_limits      - Verify iteration/timeout within budget
#   handle_task_failure - Process task failure with rollback
#   handle_limit_reached - Process budget exhaustion with rollback

# Color codes (same as display.sh for consistency)
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BOLD='\e[1m'
RESET='\e[0m'

# Retry configuration
MAX_RETRIES=3

# Checkpoint state
CHECKPOINT_COMMIT=""

# Limit state
LIMIT_REASON=""

# run_with_retry - Execute command with retry logic
# Args: command (string), task_name (string)
# Returns: 0 on success, 1 after all retries exhausted
run_with_retry() {
    local cmd="$1"
    local task_name="$2"
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        echo -e "  ${YELLOW}Attempt $attempt/$MAX_RETRIES for:${RESET} $task_name"

        # Execute command and capture exit code
        eval "$cmd"
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            echo -e "  ${GREEN}Success${RESET}"
            return 0
        fi

        echo -e "  ${RED}Failed (exit code: $exit_code)${RESET}"
        attempt=$((attempt + 1))

        if [ $attempt -le $MAX_RETRIES ]; then
            echo -e "  ${YELLOW}Retrying in 5 seconds...${RESET}"
            sleep 5
        fi
    done

    # All retries exhausted
    echo -e "  ${RED}${BOLD}Task failed after $MAX_RETRIES attempts${RESET}"
    return 1
}

# run_claude_task - Wrapper specifically for Claude CLI
# Args: prompt (string), output_file (optional, defaults to temp file)
# Returns: Claude's exit code
run_claude_task() {
    local prompt="$1"
    local output_file="${2:-}"
    local using_temp=0

    # Create temp file if no output file specified
    if [ -z "$output_file" ]; then
        output_file=$(mktemp)
        using_temp=1
    fi

    # Run Claude CLI
    claude -p "$prompt" --output-format json > "$output_file" 2>&1
    local exit_code=$?

    # Clean up temp file on success
    if [ $using_temp -eq 1 ] && [ $exit_code -eq 0 ]; then
        rm -f "$output_file"
    fi

    return $exit_code
}
