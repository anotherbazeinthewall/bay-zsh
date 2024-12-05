# Disable keystrokes while script is running 
stty -echo

# =============================================================================
# HOUSEKEEPING
# =============================================================================

# UNSET PREXISTING VENVS
if [[ -n "$VIRTUAL_ENV" ]] && [[ ! -d "$VIRTUAL_ENV" ]]; then
  unset VIRTUAL_ENV
fi

# Update terminal color settings 
export TERM="xterm-256color"
export ZSH_TMUX_FIXTERM=256
export COLORTERM="truecolor"

# =============================================================================
# ALIASES & CUSTOM FUNCTIONS
# =============================================================================

alias ls='ls -aG' # Show hidden files by default

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

# -----------------------------------------------------------------------------
# NVM (Node Version Manager)
# -----------------------------------------------------------------------------

### Set the NVM_DIR and PATH environment variables, then initialize nvm.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # Loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Loads nvm bash_completion

### Function to load the appropriate Node.js version based on .nvmrc if present
nvm_auto_use() {
    if [ -f ".nvmrc" ]; then
        local nvmrc_node_version
        nvmrc_node_version=$(<.nvmrc)  # Reads the version from .nvmrc
        if [ "$(nvm current)" != "v$nvmrc_node_version" ]; then
            nvm use "$nvmrc_node_version" >/dev/null 2>&1  # Suppresses "Now using node..."
        fi
        export virtual_environment="node:v$(node -v | tr -d 'v') "
    else
        nvm use default >/dev/null 2>&1  # Suppresses "Now using node..."
        export virtual_environment="node:v$(node -v | tr -d 'v') "
    fi
}

### Automatically call nvm_auto_use when entering a directory
autoload -U add-zsh-hook
add-zsh-hook chpwd nvm_auto_use  # Calls nvm_auto_use on directory change
nvm_auto_use  # Ensures function runs in current directory upon shell start

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
    # Initialize virtual_environment as empty for Python
    local python_env=""

    # Disable virtual env's custom prompt
    export VIRTUAL_ENV_DISABLE_PROMPT=1
    
    # Check if we're in a Python project with a specific environment setup
    if [ -f "pyproject.toml" ]; then
        if [ -f "poetry.lock" ]; then
            # Get Poetry env info and activate environment
            if [ -z "$POETRY_ACTIVE" ]; then
                # Get the poetry env path
                local poetry_venv
                poetry_venv=$(poetry env info --path 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$poetry_venv" ]; then
                    source "$poetry_venv/bin/activate" 2>/dev/null
                fi
            fi
            
            # Get version after activation
            local python_version
            python_version=$(python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null)
            if [ $? -eq 0 ]; then
                python_env="poetry(python:${python_version}) "
            else
                python_env="poetry(python:unknown) "
            fi
        elif [ -d "venv" ] || [ -d ".venv" ]; then
            # Use local venv if no Poetry, but venv or .venv directory is present
            source "${PWD}/$( [ -d "venv" ] && echo "venv" || echo ".venv")/bin/activate" >/dev/null 2>&1
            local python_version
            python_version=$(python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null)
            if [ $? -eq 0 ]; then
                python_env="python:${python_version} "
            else
                python_env="python:unknown "
            fi
        fi
    elif [ -d "venv" ] || [ -d ".venv" ]; then
        # If it's not a pyproject.toml project, activate venv directly
        source "${PWD}/$( [ -d "venv" ] && echo "venv" || echo ".venv")/bin/activate" >/dev/null 2>&1
        local python_version
        python_version=$(python -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null)
        if [ $? -eq 0 ]; then
            python_env="python:${python_version} "
        else
            python_env="python:unknown "
        fi
    else
        # If no specific environment, default to system Python
        pyenv global system >/dev/null 2>&1
    fi
    
    # Update the virtual_environment variable only if we have a Python environment
    if [ -n "$python_env" ]; then
        export virtual_environment="$python_env"
    fi
}

### Automatically call pyenv_auto_use when entering a directory
autoload -U add-zsh-hook
add-zsh-hook chpwd pyenv_auto_use  # Calls pyenv_auto_use on directory change
pyenv_auto_use  # Ensures function runs in current directory upon shell start

# -----------------------------------------------------------------------------
# ENVIRONMENT AUTOMATION
# ------pyenv_auto-----------------------------------------------------------------------

### Function to manage virtual environment activation and deactivation
manage_environment() {
    # Deactivate any active virtual environment first
    if [ -n "$VIRTUAL_ENV" ]; then
        deactivate 2>/dev/null  # Deactivates Python venv
    elif [ -n "$POETRY_ACTIVE" ]; then
        exit 2>/dev/null  # Exits Poetry subshell if active
    fi
    
    # Initialize virtual_environment variable
    export virtual_environment=""

    # Check for Node.js project and set Node version
    if [ -f "package.json" ]; then
        nvm_auto_use
    fi

    # Check for Python project and set Python environment
    if [ -f "pyproject.toml" ] || [ -d "venv" ] || [ -d ".venv" ]; then
        pyenv_auto_use
    fi
}

### Automatically call manage_environment when entering a new directory
autoload -U add-zsh-hook
add-zsh-hook chpwd manage_environment  # Calls manage_environment on directory change
manage_environment  # Ensures function runs in current directory upon shell start

# GIT CONFIGURATION 

## Git Prompt Config
ZSH_THEME_GIT_PROMPT_PREFIX="%F{116}git:(%F{green}"
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
PROMPT='%F{176}☼%f ${prompt_username} %F{209}%~%f %F{221}$virtual_environment$(git_prompt_info)%B%F{white}%#%f%b '

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