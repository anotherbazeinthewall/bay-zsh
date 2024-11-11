# HOUSEKEEPING

## Prevent any keystrokes until zshrc is loaded
stty -echo

## UNSET PREXISTING VENVS
if [[ -n "$VIRTUAL_ENV" ]] && [[ ! -d "$VIRTUAL_ENV" ]]; then
  unset VIRTUAL_ENV
fi

## Update terminal color settings 
export TERM="xterm-256color"
export ZSH_TMUX_FIXTERM=256
export COLORTERM="truecolor"

## ALIASES
alias ls='ls -aG'
alias pip=pip3
alias python=python3

# PATH CONFIGURATION 

## Add specific PATH entries to the beginning of the existing PATH, ensuring that the specified directories are searched first when executing commands. 
export PATH="$HOME/Library/Frameworks/Python.framework/Versions/3.12/bin:$PATH" # Python 3.12
export PATH="$HOME/.nvm/versions/node/v22.2.0/bin:$PATH" # Default Node.js version managed by NVM
export PATH="/Users/Baze/.local/bin:$PATH"

## Then, read the existing PATH, split it into individual entries, and iterate through each entry. If the entry is not already present in the new_path variable, append it to the end of new_path. Finally, update the new_path variable with the cleaned-up PATH.
new_path=""
while IFS= read -r path_entry; do
    if [[ ":$new_path:" != *":$path_entry:"* ]]; then
        new_path="${new_path:+$new_path:}$path_entry"
    fi
done < <(echo "$PATH" | tr ':' '\n')
new_path="${new_path#:}"
export PATH="$new_path"

# VIRTUAL ENVIRONMENT CONFIGURATION 

## NVM CONFIG

### Set the NVM_DIR environment variable to the path of the NVM directory, checks if the nvm.sh script exists and sources it to load NVM, and also checks if the bash_completion script exists and sources it to enable bash completion for NVM commands.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 

### Automatically use the Node version defined in .nvmrc, or default to the global version if .nvmrc is absent when sourcing zshrc
autoload -U add-zsh-hook

### Define and execute function to check and use Node version on shell startup
nvm_auto_switch() {
  if [ -f .nvmrc ]; then
    nvm use > /dev/null 2>&1
  else
    nvm use default > /dev/null 2>&1
  fi
}
nvm_auto_switch

### Define custom custom cd function for automatic switching when changing directories
cd() {
  builtin cd "$@" || return
  nvm_auto_switch
}

## POETRY ENV AUTOMATION (adapted from https://github.com/darvid/zsh-poetry)

###  Activate poetry environment if pyproject.toml is present and deactivate if we leave the project
ZSH_POETRY_AUTO_ACTIVATE=${ZSH_POETRY_AUTO_ACTIVATE:-1}
ZSH_POETRY_AUTO_DEACTIVATE=${ZSH_POETRY_AUTO_DEACTIVATE:-1}

autoload -U add-zsh-hook

_zp_current_project=

_zp_check_poetry_venv() {
  local venv
  if [[ -z $VIRTUAL_ENV ]] && [[ -n "${_zp_current_project}" ]]; then
    _zp_current_project=
  fi
  if [[ -f pyproject.toml ]] \
      && [[ "${PWD}" != "${_zp_current_project}" ]]; then
    if [[ -n $_zp_current_project ]]; then
      deactivate
    fi

    # if pyproject doesn't use poetry fail silently
    if [[ "$(poetry env list &> /dev/null; echo $?)" != "0" ]]; then
        return 1
    fi

    venv="$(command poetry env list --full-path | grep Activated | sed "s/ .*//" \
        | head -1)"
    if [[ -d "$venv" ]] && [[ "$venv" != "$VIRTUAL_ENV" ]]; then
      source "$venv"/bin/activate || return $?
      _zp_current_project="${PWD}"
      return 0
    fi
  elif [[ -n $VIRTUAL_ENV ]] \
      && [[ -n $ZSH_POETRY_AUTO_DEACTIVATE ]] \
      && [[ "${PWD}" != "${_zp_current_project}" ]] \
      && [[ "${PWD}" != "${_zp_current_project}"/* ]]; then
    deactivate
    _zp_current_project=
    return $?
  fi
  return 1
}

[[ -f pyproject.toml ]] && _zp_current_project="${PWD}"

add-zsh-hook chpwd _zp_check_poetry_venv

poetry-shell() {
  _zp_check_poetry_venv
}

## Define the MIT license text as a variable
MIT_LICENSE_TEXT="MIT License

Copyright (c) $(date +%Y) $(git config user.name)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the \"Software\"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."

## Define the poetry function
poetry() {
    if [[ "$1" == "init" && $# -eq 1 ]]; then
        # Run the poetry init command with MIT license and non-interactive mode
        command poetry init --license MIT --no-interaction -vvv

        # Create README.md
        echo "# $(basename "$PWD")" > README.md

        # Write the MIT license text to the LICENSE file
        echo "$MIT_LICENSE_TEXT" > LICENSE

        # Install dependencies without installing the project itself
        poetry install --no-root

        echo -e "\e[38;2;0;255;255mSuccessfully initiated [$(basename "$PWD")] Poetry project with MIT license and README\e[0m 😎👍"
        echo -e "\e[38;2;105;105;105mActivating environment...\e[0m"

        # Move to the project root directory
        cd .
    else
        command poetry "$@"
    fi
}

[[ -n $ZSH_POETRY_AUTO_ACTIVATE ]] && _zp_check_poetry_venv

### Disable Poetry's default prompt prefix
export POETRY_VIRTUALENVS_IN_PROJECT=false
export VIRTUAL_ENV_DISABLE_PROMPT=1

### Set default to install envs in project
export POETRY_VIRTUALENVS_IN_PROJECT=true

### Function to display virtual environment info (Node.js, Python venv, Pipenv)
function virtual_env_info() {
  local env_info=""

  # Function to search for pyproject.toml or package.json in parent directories
  find_project_root() {
    local search_file="$1"
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
      if [[ -f "$dir/$search_file" ]]; then
        return 0
      fi
      dir=$(dirname "$dir")
    done
    return 1
  }

  # Check if we're in a Node.js project
  if find_project_root "package.json"; then
    env_info+="%F{221}npm(node:$(node -v))%f "
  fi

  # If a Python virtual environment is activated, verify it's actually valid
  if [[ -n "$VIRTUAL_ENV" ]]; then
    # Check if the virtual environment directory actually exists
    if [[ ! -d "$VIRTUAL_ENV" ]]; then
      unset VIRTUAL_ENV
      return
    fi

    # Check if the virtual environment's Python interpreter exists
    if [[ ! -x "$VIRTUAL_ENV/bin/python" ]]; then
      unset VIRTUAL_ENV
      return
    fi

    python_version=$(python --version 2>&1 | cut -d ' ' -f 2)

    if find_project_root "pyproject.toml"; then
      env_info+="%F{221}poetry(python:${python_version})%f "
    else
      env_info+="%F{221}python:${python_version}%f "
    fi
  fi

  echo $env_info
}

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

# PROMPT CONFIG

## Enable prompt substitution
setopt PROMPT_SUBST

### Function that sets up the username in the prompt
function set_prompt_username() {
    prompt_username="%F{78}%n%f"
}

# ### Add Functions to the precmd Functions Array
# precmd_functions+=(set_prompt_username)

### Finally Construct the Prompt
PROMPT='%F{176}☼%f ${prompt_username} %F{209}%~%f $(virtual_env_info)$(git_prompt_info)%B%F{white}%#%f%b '

# AUTOSUGGEST CONFIG

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