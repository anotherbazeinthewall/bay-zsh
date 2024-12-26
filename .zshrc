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

# # UNSET PREXISTING ENVS
# if [[ -n "$VIRTUAL_ENV" ]] && [[ ! -d "$VIRTUAL_ENV" ]]; then
#     unset VIRTUAL_ENV
# fi

# # UNSET VIRTUAL_ENV_INFO
# if [[ -n "$VIRTUAL_ENV_INFO" ]]; then
#     unset VIRTUAL_ENV_INFO
# fi

# # Disable all forms of virtual env prompts
# export VIRTUAL_ENV_DISABLE_PROMPT=1
# unset VIRTUAL_ENV_NAME

# Update terminal color settings 
export TERM="xterm-256color"
export ZSH_TMUX_FIXTERM=256
export COLORTERM="truecolor"

# Disable pychache 
export PYTHONDONTWRITEBYTECODE=1
# eval "$(pyenv init --path)"
# eval "$(pyenv init -)"

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
# ENVIRONMENT MANAGEMENT
# =============================================================================

# Helper function to find files in parent directories
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
    
    return 1
}

# Gets Python version from a specific Python interpreter
get_python_version() {
    local python_path="${1:-python}"
    "$python_path" -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null
}

# Format environment info for prompt
format_env_info() {
    local type="$1"
    local version="$2"
    echo "${type}(${version}) "
}

# Virtual environment management
get_venv_path() {
    local base_dir="$1"
    
    if [ -d "$base_dir/venv" ]; then
        echo "$base_dir/venv"
    elif [ -d "$base_dir/.venv" ]; then
        echo "$base_dir/.venv"
    fi
}

deactivate_venv() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate >/dev/null 2>&1
        export VIRTUAL_ENV_INFO=""
        unset VIRTUAL_ENV
    fi
}

activate_venv() {
    local venv_path="$1"
    
    if [[ -n "$venv_path" && -f "$venv_path/bin/activate" ]]; then
        source "$venv_path/bin/activate" >/dev/null 2>&1
        local python_version=$(get_python_version "$venv_path/bin/python")
        export VIRTUAL_ENV_INFO="$(format_env_info "python" "$python_version")"
    fi
}

# Handle Python environment
handle_python_environment() {
    local project_dir="$1"
    local venv_path=$(get_venv_path "$project_dir")
    
    # If we found a venv and we're not in VS Code (or VS Code hasn't set VIRTUAL_ENV)
    if [[ -n "$venv_path" ]]; then
        if ! is_vscode || [[ -z "$VIRTUAL_ENV" ]]; then
            activate_venv "$venv_path"
        fi
    else
        # No venv found, deactivate if one is active
        deactivate_venv
    fi
}

# Handle Node.js environment
handle_node_environment() {
    local project_dir="$1"
    
    # Reset node info by default
    local node_info=""
    
    if [ -f "$project_dir/.nvmrc" ]; then
        nvm use >/dev/null 2>&1
    elif [ -f "$project_dir/package.json" ]; then
        nvm use default >/dev/null 2>&1
    fi
    
    # Only show Node info if we're in a Node project
    if [ -f "$project_dir/package.json" ] || [ -f "$project_dir/.nvmrc" ]; then
        local node_version=$(node -v | tr -d 'v')
        node_info=$(format_env_info "node" "$node_version")
    fi
    
    echo "$node_info"
}

# Main environment management function
manage_environment() {
    # Prevent recursive calls
    [[ "$MANAGING_ENVIRONMENT" == "true" ]] && return
    export MANAGING_ENVIRONMENT="true"
    
    # Find project roots
    local python_root=$(find_file_in_parents "venv" || find_file_in_parents ".venv")
    local node_root=$(find_file_in_parents "package.json" || find_file_in_parents ".nvmrc")
    
    # Handle Python environment
    if [[ -n "$python_root" ]]; then
        handle_python_environment "$python_root"
    else
        deactivate_venv
    fi
    
    # Handle Node environment and get Node info for prompt
    local node_info=""
    if [[ -n "$node_root" ]]; then
        node_info=$(handle_node_environment "$node_root")
    fi
    
    # Update VIRTUAL_ENV_INFO to include Node info if present
    if [[ -n "$node_info" ]]; then
        export VIRTUAL_ENV_INFO="${VIRTUAL_ENV_INFO}${node_info}"
    fi
    
    export MANAGING_ENVIRONMENT="false"
}

# Set up directory change hook
autoload -U add-zsh-hook
add-zsh-hook chpwd manage_environment

# Initial environment setup
manage_environment

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
        # Split the string into parts and color them
        if [[ "$env_info" =~ "(python|node)\((.*)\) " ]]; then
            local env_type="${match[1]}"
            local version="${match[2]}"
            echo "%F{221}${env_type}(%F{211}${version}%F{221})%f "
        else
            echo "$env_info"
        fi
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