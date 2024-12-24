# =============================================================================
# HOUSEKEEPING
# =============================================================================

export DEBUG_ZSH=false  # Set to false to disable debug output

debug() {
    if [ "$DEBUG_ZSH" = true ]; then
        echo "DEBUG: $1" >&2
    fi
}

debug "\e[2;3mInitiating ZSH Run Commands... \e[0m"

# Helper function to check if we're in VS Code
is_vscode() {
    [[ -n "$VSCODE_PID" ]] || [[ -n "$VSCODE_INJECTION" ]]
}

# Set sourcing flag if we're sourcing the file
if [[ "${(%):-%N}" == ".zshrc" ]]; then
    export SOURCING_ZSHRC="true"
fi

# UNSET PREXISTING VENVS
if [[ -n "$VIRTUAL_ENV" ]] && [[ ! -d "$VIRTUAL_ENV" ]]; then
    unset VIRTUAL_ENV
fi

# UNSET VIRTUAL_ENV_INFO
if [[ -n "$VIRTUAL_ENV_INFO" ]]; then
    unset VIRTUAL_ENV_INFO
fi

# Disable all forms of virtual env prompts
export VIRTUAL_ENV_DISABLE_PROMPT=1
unset VIRTUAL_ENV_NAME

# Update terminal color settings 
export TERM="xterm-256color"
export ZSH_TMUX_FIXTERM=256
export COLORTERM="truecolor"

# Disable pychache 
export PYTHONDONTWRITEBYTECODE=1
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# =============================================================================
# ALIASES & CUSTOM FUNCTIONS
# =============================================================================

alias ls='ls -aG' # Show hidden files by default
alias newpy='function _newpy() { poetry new $1 && cd $1 && poetry install && git init && touch .gitignore && echo "Project $1 created successfully!"; }; _newpy'

# =============================================================================
# PATH MANAGEMENT
# =============================================================================

export PATH="$HOME/.local/bin:$PATH"

## Clean up PATH
new_path=""
while IFS= read -r path_entry; do
    if [[ ":$new_path:" != *":$path_entry:"* ]]; then
        new_path="${new_path:+$new_path:}$path_entry"
    fi
done < <(echo "$PATH" | tr ':' '\n')
new_path="${new_path#:}"
export PATH="$new_path"

# =============================================================================
# ENVIRONMENT MANAGERS
# =============================================================================


# -----------------------------------------------------------------------------
# ENV HELPER FUNCTIONS
# -----------------------------------------------------------------------------

### Helper function to find files in parent directories
find_file_in_parents() {
    local file="$1"
    local dir="$PWD"
    
    while [ "$dir" != "/" ]; do
        if [ -e "$dir/$file" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(realpath "$dir"/..)"
    done
    
    # One final check at root directory
    if [ -e "/$file" ]; then
        echo "/"
        return 0
    fi
    
    return 1
}

# Gets Python version from a specific Python interpreter
get_python_version() {
    local python_path="${1:-python}"  # Default to 'python' if no path provided
    "$python_path" -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null
}

# Detect Python project type
detect_python_project() {
    local project_type=""
    local project_dir=""
    
    if project_dir=$(find_file_in_parents "poetry.lock"); then
        project_type="poetry"
    elif project_dir=$(find_file_in_parents "venv") || project_dir=$(find_file_in_parents ".venv"); then
        project_type="venv"
    fi
    
    if [[ -n "$project_type" ]]; then
        echo "$project_type:$project_dir"
    fi
}

# Get Poetry environment path
get_poetry_env_path() {
    local project_dir="$1"
    local poetry_env=""
    
    if command -v poetry >/dev/null 2>&1; then
        if ! poetry_env=$(POETRY_CACHE_DIR="$project_dir/.poetry-cache" poetry env info --path 2>/dev/null); then
            poetry_env=$(poetry env info --path 2>/dev/null)
        fi
    fi
    
    echo "$poetry_env"
}

# Get venv path
get_venv_path() {
    local project_dir="$1"
    local venv_path=""
    
    if [ -d "$project_dir/venv" ]; then
        venv_path="$project_dir/venv"
    elif [ -d "$project_dir/.venv" ]; then
        venv_path="$project_dir/.venv"
    fi
    
    echo "$venv_path"
}

# Format environment info
format_env_info() {
    local type="$1"
    local version="$2"
    
    case "$type" in
        "poetry"|"venv")
            echo "python(${version}) "
            ;;
        "node")
            echo "node(${version}) "
            ;;
    esac
}

# Virtual environment management helpers
get_venv_path() {
    local base_dir="$1"
    local venv_name="${2:-}" # Optional specific venv name to look for
    
    debug "Searching for venv in: $base_dir"
    
    # List of possible venv locations/names to check
    local venv_locations=(
        "$base_dir/venv"
        "$base_dir/.venv"
        "${venv_name:+"$base_dir/$venv_name"}" # Only include if venv_name is provided
    )
    
    # Check each possible location
    for venv_path in "${venv_locations[@]}"; do
        if [[ -n "$venv_path" && -d "$venv_path" && -f "$venv_path/bin/activate" ]]; then
            debug "Found valid venv at: $venv_path"
            echo "$venv_path"
            return 0
        fi
    done
    
    debug "No valid venv found in $base_dir"
    return 1
}

deactivate_venv() {
    local current_venv="$1"
    
    if [[ -n "$current_venv" ]]; then
        debug "Deactivating virtual environment: $current_venv"
        # Clear environment variables first
        export VIRTUAL_ENV_INFO=""
        unset VIRTUAL_ENV
        
        # Then deactivate the environment
        if [[ -f "$current_venv/bin/deactivate" ]]; then
            source "$current_venv/bin/deactivate" >/dev/null 2>&1
            debug "Virtual environment deactivated"
            return 0
        else
            debug "No deactivate script found"
            return 1
        fi
    fi
    return 1
}

activate_venv() {
    local venv_path="$1"
    
    if [[ -n "$venv_path" && -f "$venv_path/bin/activate" ]]; then
        debug "Activating virtual environment: $venv_path"
        source "$venv_path/bin/activate" >/dev/null 2>&1
        return 0
    fi
    return 1
}

# Project detection system
PROJECT_TYPE_POETRY="poetry"
PROJECT_TYPE_VENV="venv"
PROJECT_TYPE_NODE="node"

detect_project_type() {
    local dir="$1"
    local markers=(
        "poetry.lock:$PROJECT_TYPE_POETRY"
        "pyproject.toml:$PROJECT_TYPE_POETRY"
        "venv:$PROJECT_TYPE_VENV"
        ".venv:$PROJECT_TYPE_VENV"
        "package.json:$PROJECT_TYPE_NODE"
        ".nvmrc:$PROJECT_TYPE_NODE"
    )
    
    debug "Detecting project type in directory: $dir"
    
    for marker in "${markers[@]}"; do
        local file="${marker%%:*}"
        local type="${marker#*:}"
        
        if [[ -e "$dir/$file" ]]; then
            debug "Found $type project marker: $file"
            echo "$type"
            return 0
        fi
    done
    
    return 1
}

find_project_root() {
    local type="$1"
    local current_dir="$PWD"
    
    debug "Finding project root for type: $type"
    
    case "$type" in
        "$PROJECT_TYPE_POETRY")
            find_file_in_parents "poetry.lock" || find_file_in_parents "pyproject.toml"
            ;;
        "$PROJECT_TYPE_VENV")
            find_file_in_parents "venv" || find_file_in_parents ".venv"
            ;;
        "$PROJECT_TYPE_NODE")
            find_file_in_parents "package.json" || find_file_in_parents ".nvmrc"
            ;;
        *)
            debug "Unknown project type: $type"
            return 1
            ;;
    esac
}

get_project_info() {
    local dir="${1:-$PWD}"
    local project_types=()
    local project_info=""
    
    debug "Getting project info for directory: $dir"
    
    # Check for Python projects
    if project_dir=$(find_file_in_parents "poetry.lock") || \
       project_dir=$(find_file_in_parents "pyproject.toml"); then
        project_types+=("$PROJECT_TYPE_POETRY")
    elif project_dir=$(find_file_in_parents "venv") || \
         project_dir=$(find_file_in_parents ".venv"); then
        project_types+=("$PROJECT_TYPE_VENV")
    fi
    
    # Check for Node.js projects
    if project_dir=$(find_file_in_parents "package.json") || \
       project_dir=$(find_file_in_parents ".nvmrc"); then
        project_types+=("$PROJECT_TYPE_NODE")
    fi
    
    # Format project info
    for type in "${project_types[@]}"; do
        local root=$(find_project_root "$type")
        if [[ -n "$root" ]]; then
            [[ -n "$project_info" ]] && project_info+=";"
            project_info+="${type}:${root}"
        fi
    done
    
    if [[ -n "$project_info" ]]; then
        debug "Found project info: $project_info"
        echo "$project_info"
        return 0
    fi
    
    debug "No project found"
    return 1
}

# -----------------------------------------------------------------------------
# Python Environment
# -----------------------------------------------------------------------------

export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# Consolidate Python environment detection and activation
handle_python_environment() {
    local project_dir="$1"
    local env_info=""
    local python_path=""
    local env_type=""
    
    debug "Handling Python environment for directory: $project_dir"
    
    # Try Poetry first, then venv
    if [ -f "$project_dir/poetry.lock" ]; then
        env_type="poetry"
        local poetry_env=$(get_poetry_env_path "$project_dir")
        if [[ -n "$poetry_env" && -d "$poetry_env" ]]; then
            python_path="$poetry_env/bin/python"
        fi
    elif [ -d "$project_dir/venv" ] || [ -d "$project_dir/.venv" ]; then
        env_type="venv"
        local venv_path=$(get_venv_path "$project_dir")
        if [[ -n "$venv_path" ]]; then
            python_path="$venv_path/bin/python"
        fi
    fi
    
    if [[ -n "$python_path" ]]; then
        local python_version=$(get_python_version "$python_path")
        if [[ -n "$python_version" ]]; then
            env_info=$(format_env_info "$env_type" "$python_version")
            debug "Set python_env_info: $env_info"
            
            if ! is_vscode || [[ -z "$VIRTUAL_ENV" ]]; then
                case "$env_type" in
                    "poetry")
                        local poetry_env=$(get_poetry_env_path "$project_dir")
                        [[ -n "$poetry_env" ]] && activate_venv "$poetry_env"
                        ;;
                    "venv")
                        local venv_path=$(get_venv_path "$project_dir")
                        [[ -n "$venv_path" ]] && activate_venv "$venv_path"
                        ;;
                esac
            fi
        fi
    fi
    
    echo "$env_info"
}

# -----------------------------------------------------------------------------
# Node JS Environment Handling
# -----------------------------------------------------------------------------

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Handle Node.js environment
handle_node_environment() {
    local project_dir="$1"
    local env_info=""
    
    debug "Handling Node.js environment for directory: $project_dir"
    
    if [ -f "$project_dir/.nvmrc" ]; then
        local nvmrc_node_version
        nvmrc_node_version=$(<"$project_dir/.nvmrc")
        if [ "$(nvm current)" != "v$nvmrc_node_version" ]; then
            nvm use "$nvmrc_node_version" >/dev/null 2>&1
        fi
    else
        [ -f "$project_dir/package.json" ] && nvm use default >/dev/null 2>&1
    fi
    
    if [ -f "$project_dir/package.json" ] || [ -f "$project_dir/.nvmrc" ]; then
        local node_version=$(node -v | tr -d 'v')
        env_info=$(format_env_info "node" "$node_version")
        debug "Set node_env_info: $env_info"
    fi
    
    echo "$env_info"
}

# -----------------------------------------------------------------------------
# ENV AUTOMATION
# -----------------------------------------------------------------------------

manage_environment() {
    if [[ "$MANAGING_ENVIRONMENT" == "true" ]]; then
        return
    fi
    
    export MANAGING_ENVIRONMENT="true"
    
    local project_info=$(get_project_info)
    debug "Project info: $project_info"
    
    local env_info=""
    
    if [[ -z "$project_info" ]]; then
        debug "No project detected, cleaning up environments"
        if [[ -n "$VIRTUAL_ENV" ]]; then
            debug "Deactivating Python virtual environment"
            deactivate_venv "$VIRTUAL_ENV"
        fi
        if [[ -n "$VIRTUAL_ENV_INFO" && "$VIRTUAL_ENV_INFO" == *"node:"* ]]; then
            debug "Resetting Node version to default"
            nvm use default >/dev/null 2>&1
        fi
        export VIRTUAL_ENV_INFO=""
    else
        IFS=';' read -A project_entries <<< "$project_info"
        for entry in "${project_entries[@]}"; do
            local type="${entry%%:*}"
            local root="${entry#*:}"
            
            case "$type" in
                "$PROJECT_TYPE_POETRY"|"$PROJECT_TYPE_VENV")
                    local python_env_info=$(handle_python_environment "$root")
                    [[ -n "$python_env_info" ]] && env_info+="$python_env_info"
                    ;;
                "$PROJECT_TYPE_NODE")
                    local node_env_info=$(handle_node_environment "$root")
                    [[ -n "$node_env_info" ]] && env_info+="$node_env_info"
                    ;;
            esac
        done
    fi
    
    export VIRTUAL_ENV_INFO="$env_info"
    debug "Final VIRTUAL_ENV_INFO: $VIRTUAL_ENV_INFO"
    export MANAGING_ENVIRONMENT="false"
}

# Initial shell setup function
shell_init() {
    debug "Starting shell initialization"
    
    # Force MANAGING_ENVIRONMENT to false and run manage_environment
    export MANAGING_ENVIRONMENT="false"
    manage_environment
    
    # Clear the sourcing flag after initialization
    unset SOURCING_ZSHRC
    
    debug "Shell initialization complete"
}

# Set up hooks - use only chpwd
autoload -U add-zsh-hook
add-zsh-hook chpwd manage_environment


# =============================================================================
# GIT CONFIGURATION 
# =============================================================================

ZSH_THEME_GIT_PROMPT_PREFIX="%F{116}git(%F{green}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f "
ZSH_THEME_GIT_PROMPT_DIRTY="%F{116}) %F{78}*%f"
ZSH_THEME_GIT_PROMPT_CLEAN="%F{116})"

function git_prompt_info() {
    ref=$(git symbolic-ref HEAD 2> /dev/null) || return
    echo "$ZSH_THEME_GIT_PROMPT_PREFIX${ref#refs/heads/}$(parse_git_dirty)$ZSH_THEME_GIT_PROMPT_SUFFIX"
}

function parse_git_dirty() {
    local STATUS=''
    local FLAGS=('--porcelain')
    local CONFIG_HIDE_DIRTY=$(git config --get zsh.hide-dirty)
    if [[ "$CONFIG_HIDE_DIRTY" != "1" ]]; then
        if [[ $(git --version | awk '{print $3}' | cut -d. -f2) -gt 7 ]]; then
            FLAGS+='--ignore-submodules=dirty'
        fi
        if [[ "$DISABLE_UNTRACKED_FILES_DIRTY" == "true" ]]; then
            FLAGS+='--untracked-files=no'
        fi
        STATUS=$(command git status ${FLAGS} 2> /dev/null | tail -n1)
    fi
    if [[ -n $STATUS ]]; then
        echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
    else
        echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
    fi
}

# =============================================================================
# PROMPT ENHANCEMENTS 
# =============================================================================

setopt PROMPT_SUBST

function set_prompt_username() {
    prompt_username="%F{78}%n%f"
}

# Add color formatting to VIRTUAL_ENV_INFO for the prompt
function format_env_info_prompt() {
    local env_info="$1"
    if [[ -n "$env_info" ]]; then
        # Replace python/node with colored versions
        env_info="${env_info//python(/%F{221}python(%F{211}}"
        env_info="${env_info//node(/%F{221}node(%F{211}}"
        # Add closing parenthesis color
        env_info="${env_info//)/%F{221})%f}"
        echo "$env_info"
    fi
}

# Add the precmd hook for username
add-zsh-hook precmd set_prompt_username

PROMPT='%F{176}☼%f ${prompt_username} %F{209}%~%f ${VIRTUAL_ENV_INFO:+"$(format_env_info_prompt "$VIRTUAL_ENV_INFO")"}$(git_prompt_info)%B%F{white}%#%f%b '

# =============================================================================
# COMPLETION SYSTEM & KEYBINDINGS
# =============================================================================

if [ ! -d ~/.zsh/zsh-autosuggestions ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
fi

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#forward-char}")
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#vi-forward-char}")

autosuggest_partial_charwise() {
    if [[ -n $LBUFFER && -n $RBUFFER ]]; then
        BUFFER=$LBUFFER${RBUFFER[1]}${RBUFFER[2,-1]}
        CURSOR=$((CURSOR + 1))
    fi
}
zle -N autosuggest_partial_charwise

bindkey '^[[C' autosuggest_partial_charwise
bindkey '^I' autosuggest-accept
bindkey '^E' forward-word

ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"

autoload -Uz compinit && compinit

# =============================================================================
# FINAL INITIALIZATION
# =============================================================================

# Perform initial shell setup
shell_init

debug "\e[1;3;32mSuccessfully loaded ZSH Run Commands!\e[0m"