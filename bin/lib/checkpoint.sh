#!/bin/bash
# GSD Ralph - Git Checkpointing
# Part of Phase 4: Git Checkpointing
#
# Provides:
#   validate_git_state       - Pre-flight validation at startup
#   create_checkpoint_commit - Commit after successful iteration

# Color codes (same as display.sh for consistency)
# Respect NO_COLOR standard (https://no-color.org/)
if [[ -n "${NO_COLOR:-}" ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    RESET=''
else
    RED='\e[31m'
    GREEN='\e[32m'
    YELLOW='\e[33m'
    RESET='\e[0m'
fi

# validate_git_state - Pre-flight validation at startup
# Ensures clean git state before entering main loop
# Returns: 0 on success, 1 if git state is not acceptable
validate_git_state() {
    # Check if in git repo
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        # Not in a git repo
        if [[ -t 0 ]]; then
            # Interactive mode - offer to initialize
            echo -e "${YELLOW}Not in a git repository${RESET}"
            read -p "Initialize git repository? [y/N]: " response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                git init
                echo -e "${GREEN}Git repository initialized${RESET}"
            else
                echo -e "${RED}Error: Cannot proceed without a git repository${RESET}"
                return 1
            fi
        else
            # Non-interactive mode - error
            echo -e "${RED}Error: Not in a git repository${RESET}"
            return 1
        fi
    fi

    # Check for uncommitted changes
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        echo -e "${RED}Error: Working tree has uncommitted changes${RESET}"
        echo "Please commit or stash your changes before running Ralph:"
        git status --short
        return 1
    fi

    # Check for detached HEAD (warning only)
    if ! git symbolic-ref -q HEAD > /dev/null 2>&1; then
        echo -e "${YELLOW}Warning: HEAD is detached (commits will still work)${RESET}"
    fi

    return 0
}

# create_checkpoint_commit - Commit after successful iteration
# Args: task_id, summary
# Returns: 0 on success, 1 on failure (FATAL)
create_checkpoint_commit() {
    local task_id="$1"
    local summary="$2"

    # Stage STATE.md
    git add .planning/STATE.md 2>/dev/null

    # Check if anything is staged
    if git diff --cached --quiet 2>/dev/null; then
        echo -e "${YELLOW}No changes to commit after task $task_id${RESET}"
        return 0
    fi

    # Build commit message
    local commit_msg
    commit_msg="Ralph checkpoint: ${task_id} complete

${summary}"

    # Create commit
    if ! git commit -m "$commit_msg" > /dev/null 2>&1; then
        echo -e "${RED}Error: Failed to create checkpoint commit${RESET}"
        return 1
    fi

    # Print confirmation
    local short_sha
    short_sha=$(git rev-parse --short HEAD)
    echo -e "${GREEN}Checkpoint: $short_sha ($task_id)${RESET}"

    return 0
}
