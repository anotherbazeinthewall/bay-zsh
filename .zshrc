export DEBUG_ZSH=false  # Set to false to disable debug output

debug() {
    if [ "$DEBUG_ZSH" = true ]; then
        echo "DEBUG: $1" >&2
    fi
}

# =============================================================================
# HOUSEKEEPING
# =============================================================================

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

# -----------------------------------------------------------------------------
# NVM (Node Version Manager)
# -----------------------------------------------------------------------------

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

nvm_auto_use() {
    local project_dir=""
    local node_env_info=""
    
    if project_dir=$(find_file_in_parents "package.json") || project_dir=$(find_file_in_parents ".nvmrc"); then
        if [ -f "$project_dir/.nvmrc" ]; then
            local nvmrc_node_version
            nvmrc_node_version=$(<"$project_dir/.nvmrc")
            if [ "$(nvm current)" != "v$nvmrc_node_version" ]; then
                nvm use "$nvmrc_node_version" >/dev/null 2>&1
            fi
        else
            nvm use default >/dev/null 2>&1
        fi
        node_env_info="node:v$(node -v | tr -d 'v') "
    fi
    echo "$node_env_info"
}

# -----------------------------------------------------------------------------
# PYENV (Python Environment Manager)
# -----------------------------------------------------------------------------

export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

pyenv_activate() {
    local project_dir=""
    
    if project_dir=$(find_file_in_parents "peotry.lock"); then
        if [ -f "$project_dir/poetry.lock" ]; then
            local poetry_env
            if poetry_env=$(POETRY_CACHE_DIR="$project_dir/.poetry-cache" timeout 2s poetry env info --path 2>/dev/null); then
                if [[ -n "$poetry_env" && -d "$poetry_env" ]]; then
                    debug "Activating Poetry environment at: $poetry_env"
                    source "$poetry_env/bin/activate" >/dev/null 2>&1
                    return
                fi
            fi
        fi
    elif project_dir=$(find_file_in_parents "venv") || project_dir=$(find_file_in_parents ".venv"); then
        debug "Activating venv"
        local venv_path
        if [ -d "$project_dir/venv" ]; then
            venv_path="$project_dir/venv"
        else
            venv_path="$project_dir/.venv"
        fi

        if [ -f "$venv_path/bin/activate" ]; then
            debug "Activating venv at: $venv_path"
            source "$venv_path/bin/activate" >/dev/null 2>&1
            return
        fi
    fi
}

pyenv_auto_use() {
    debug "Starting pyenv_auto_use"
    local python_env_info=""
    local project_dir=""
    
    if project_dir=$(find_file_in_parents "pyproject.toml"); then
        debug "Found Poetry project at: $project_dir"
        if command -v poetry >/dev/null 2>&1; then
            if [ -f "$project_dir/poetry.lock" ]; then
                local poetry_env
                debug "Getting Poetry environment path"
                if poetry_env=$(POETRY_CACHE_DIR="$project_dir/.poetry-cache" timeout 2s poetry env info --path 2>/dev/null); then
                    debug "Poetry environment path: $poetry_env"
                    if [[ -n "$poetry_env" && -d "$poetry_env" ]]; then
                        local python_version
                        python_version=$($poetry_env/bin/python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null)
                        debug "Python version: $python_version"
                        python_env_info="poetry(python:${python_version}) "
                    fi
                fi
            fi
        fi
    elif project_dir=$(find_file_in_parents "venv") || project_dir=$(find_file_in_parents ".venv"); then
        debug "Found venv at: $project_dir"
        local venv_path
        if [ -d "$project_dir/venv" ]; then
            venv_path="$project_dir/venv"
        else
            venv_path="$project_dir/.venv"
        fi

        if [ -f "$venv_path/bin/activate" ]; then
            local python_version
            python_version=$($venv_path/bin/python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null)
            debug "Python version: $python_version"
            python_env_info="python:${python_version} "
        fi
    fi

    echo "$python_env_info"
}

# -----------------------------------------------------------------------------
# ENVIRONMENT AUTOMATION
# -----------------------------------------------------------------------------

# Modify the manage_environment function:
manage_environment() {
    # Skip if we're sourcing .zshrc
    if [[ "$SOURCING_ZSHRC" == "true" ]]; then
        return
    fi
    
    # Use local variable for managing state
    if [[ "$MANAGING_ENVIRONMENT" == "true" ]]; then
        return
    fi
    
    export MANAGING_ENVIRONMENT="true"
    
    # Check if we're in a Python project directory
    local in_python_project=false
    if find_file_in_parents "pyproject.toml" >/dev/null 2>&1 || \
       find_file_in_parents "venv" >/dev/null 2>&1 || \
       find_file_in_parents ".venv" >/dev/null 2>&1; then
        in_python_project=true
    fi
    
    # Special handling for VS Code
    if is_vscode && [[ -n "$VIRTUAL_ENV" ]]; then
        if $in_python_project; then
            debug "VS Code environment detected, preserving existing environment"
            local python_version=$(python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null)
            if [[ -n "$python_version" ]]; then
                if [[ "$VIRTUAL_ENV" == *"poetry"* ]]; then
                    export VIRTUAL_ENV_INFO="poetry(python:${python_version}) "
                else
                    export VIRTUAL_ENV_INFO="python:${python_version} "
                fi
            fi
        else
            debug "Left Python project directory, deactivating environment"
            # Store the current VIRTUAL_ENV path
            local current_venv="$VIRTUAL_ENV"
            # Clear environment variables first
            export VIRTUAL_ENV_INFO=""
            unset VIRTUAL_ENV
            # Then deactivate the environment
            if [[ -f "$current_venv/bin/deactivate" ]]; then
                source "$current_venv/bin/deactivate" >/dev/null 2>&1
            fi
        fi
    else
        # Regular environment handling
        if [[ -n "$VIRTUAL_ENV" ]]; then
            debug "Deactivating existing virtual environment"
            local current_venv="$VIRTUAL_ENV"
            unset VIRTUAL_ENV
            if [[ -f "$current_venv/bin/deactivate" ]]; then
                source "$current_venv/bin/deactivate" >/dev/null 2>&1
            fi
        fi
        
        # Python environment handling
        debug "Handling Python environment"
        local python_env_info=$(pyenv_auto_use)
        debug "Python env info: $python_env_info"

        # Node.js environment handling
        debug "Handling Node environment"
        local node_env_info=$(nvm_auto_use)
        debug "Node env info: $node_env_info"
        
        # Combine environment information
        export VIRTUAL_ENV_INFO=""
        if [[ -n "$python_env_info" ]]; then
            debug "Adding Python info to prompt"
            export VIRTUAL_ENV_INFO="$python_env_info"
        fi
        if [[ -n "$node_env_info" ]]; then
            debug "Adding Node info to prompt"
            export VIRTUAL_ENV_INFO="$VIRTUAL_ENV_INFO$node_env_info"
        fi
        
        debug "Final VIRTUAL_ENV_INFO: $VIRTUAL_ENV_INFO"
        
        # Now activate the environment if needed
        if [[ -n "$python_env_info" && -z "$VIRTUAL_ENV" ]]; then
            pyenv_activate
        fi
    fi
    
    export MANAGING_ENVIRONMENT="false"
}

# Initial shell setup function
shell_init() {
    debug "Starting shell initialization"
    
    # Initialize environment without activation
    export MANAGING_ENVIRONMENT="false"
    manage_environment
    
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

PROMPT='%F{176}☼%f ${prompt_username} %F{209}%~%f ${VIRTUAL_ENV_INFO:+"%F{221}$VIRTUAL_ENV_INFO"}$(git_prompt_info)%B%F{white}%#%f%b '

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