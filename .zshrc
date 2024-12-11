# =============================================================================
# HOUSEKEEPING
# =============================================================================

# Disable keystrokes while script is running 
stty -echo

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

## Then, read the existing PATH, split it into individual entries, and iterate through each entry. If the entry is not already present in the new_path variable, append it to the end of new_path. Finally, update the new_path variable with the cleaned-up PATH.
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
    local file_to_find="$1"
    local current_dir="$PWD"
    local previous_dir=""

    while [[ "$current_dir" != "/" && "$current_dir" != "$previous_dir" ]]; do
        if [[ -e "$current_dir/$file_to_find" ]]; then
            echo "$current_dir"
            return 0
        fi
        previous_dir="$current_dir"
        current_dir="$(dirname "$current_dir")"
    done

    return 1  # File not found
}

# -----------------------------------------------------------------------------
# NVM (Node Version Manager)
# -----------------------------------------------------------------------------

### Set the NVM_DIR and PATH environment variables, then initialize nvm.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # Loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Loads nvm bash_completion

### Function to load the appropriate Node.js version based on .nvmrc if present
nvm_auto_use() {
    local project_dir=""
    
    # Search for package.json or .nvmrc in parent directories
    if project_dir=$(find_file_in_parents "package.json") || project_dir=$(find_file_in_parents ".nvmrc"); then
        if [ -f "$project_dir/.nvmrc" ]; then
            local nvmrc_node_version
            nvmrc_node_version=$(<"$project_dir/.nvmrc")  # Reads the version from .nvmrc
            if [ "$(nvm current)" != "v$nvmrc_node_version" ]; then
                nvm use "$nvmrc_node_version" >/dev/null 2>&1
            fi
        else
            nvm use default >/dev/null 2>&1
        fi
        export VIRTUAL_ENV_INFO="node:v$(node -v | tr -d 'v') "
    else
        export VIRTUAL_ENV_INFO=""
    fi
}

# -----------------------------------------------------------------------------
# PYENV (Python Environment Manager)
# -----------------------------------------------------------------------------

# Set the PYENV_ROOT and PATH environment variables, then initialize pyenv.
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

### Function to automatically activate Python environment based on project type
pyenv_auto_use() {
    # Deactivate any currently active virtual environment
    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate >/dev/null 2>&1 || true
        unset VIRTUAL_ENV
    fi
    export VIRTUAL_ENV_INFO=""

    local project_dir=""
    local python_env=""

    # Check for Poetry-managed projects first
    if project_dir=$(find_file_in_parents "pyproject.toml") || project_dir=$(find_file_in_parents "poetry.lock"); then
        if command -v poetry >/dev/null 2>&1; then
            local poetry_env
            poetry_env=$(poetry env info --path 2>/dev/null)
            if [[ -n "$poetry_env" && -d "$poetry_env" ]]; then
                source "$poetry_env/bin/activate" >/dev/null 2>&1
                local python_version
                python_version=$(python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null)
                python_env="poetry(%F{212}python:${python_version}%F{221}) "
            else
                python_env=""  # No virtual environment exists; clear info
            fi
        fi

    # Check for non-Poetry venv directories
    elif project_dir=$(find_file_in_parents "venv") || project_dir=$(find_file_in_parents ".venv"); then
        local venv_dir
        venv_dir="$project_dir/$( [ -d "$project_dir/venv" ] && echo "venv" || echo ".venv")"
        if [ -f "$venv_dir/bin/activate" ]; then
            source "$venv_dir/bin/activate" >/dev/null 2>&1
            local python_version
            python_version=$(python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null)
            python_env="python:${python_version} "
        fi
    fi

    export VIRTUAL_ENV_INFO="$python_env"
}

# -----------------------------------------------------------------------------
# ENVIRONMENT AUTOMATION
# -----------------------------------------------------------------------------

### Function to manage virtual environment activation and deactivation
manage_environment() {
    # Initialize environment info
    export VIRTUAL_ENV_INFO=""

    # Deactivate previously active environments
    if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate >/dev/null 2>&1 || true
        unset VIRTUAL_ENV
    fi

    # Python environment handling
    pyenv_auto_use

    # Node.js (NVM) environment handling (optional)
    local node_info=""
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
        node_info="node:v$(node -v | tr -d 'v') "
    fi

    # Combine environment information
    export VIRTUAL_ENV_INFO="${VIRTUAL_ENV_INFO}${node_info}"
}

# Automatically call `manage_environment` when entering a new directory
autoload -U add-zsh-hook
add-zsh-hook chpwd manage_environment
manage_environment  # Ensure it runs on shell start

# GIT CONFIGURATION 

## Git Prompt Config
ZSH_THEME_GIT_PROMPT_PREFIX="%F{116}git(%F{green}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f "
ZSH_THEME_GIT_PROMPT_DIRTY="%F{116}) %F{78}*%f"
ZSH_THEME_GIT_PROMPT_CLEAN="%F{116})"

### Function to Display Git Info in the Prompt
function git_prompt_info() {
  ref=$(git symbolic-ref HEAD 2> /dev/null) || return
  echo "$ZSH_THEME_GIT_PROMPT_PREFIX${ref#refs/heads/}$(parse_git_dirty)$ZSH_THEME_GIT_PROMPT_SUFFIX"
}

### Function to Check if the Git Repo is Dirty
function parse_git_dirty() {
  local STATUS=''
  local FLAGS
  FLAGS=('--porcelain')
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

## Enable prompt substitution
setopt PROMPT_SUBST

### Function that sets up the username in the prompt
function set_prompt_username() {
    prompt_username="%F{78}%n%f"
}

### Add Functions to the precmd Functions Array
precmd_functions+=(set_prompt_username)

# Finally Construct the Prompt
PROMPT='%F{176}☼%f ${prompt_username} %F{209}%~%f %F{221}$VIRTUAL_ENV_INFO$(git_prompt_info)%B%F{white}%#%f%b '

# =============================================================================
# COMPLETION SYSTEM & KEYBINDINGS
# =============================================================================

## Check if zsh autosuggestions is NOT installed. If not, then install it:
if [ ! -d ~/.zsh/zsh-autosuggestions ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
fi

## Turn on zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

## Remove Forward-Char From Autosuggest Accept Widgets
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#forward-char}")
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#vi-forward-char}")

## Define custom widget to accept one character of suggestion
autosuggest_partial_charwise() {
    if [[ -n $LBUFFER && -n $RBUFFER ]]; then
        BUFFER=$LBUFFER${RBUFFER[1]}${RBUFFER[2,-1]}
        CURSOR=$((CURSOR + 1))
    fi
}
zle -N autosuggest_partial_charwise

## Autosuggest Keybindings
bindkey '^[[C' autosuggest_partial_charwise # Bind the Right Arrow key to accept suggestion
bindkey '^I' autosuggest-accept # Bind the Tab key to accept suggestion
bindkey '^E' forward-word # Bind 

## Autosuggest Options
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"

## Finally Load and Initialize the Autosuggest Completion System
autoload -Uz compinit && compinit

# =============================================================================
# FINAL INITIALIZATION
# =============================================================================

# Enable keystrokes now that the script is done 
stty echo
clear