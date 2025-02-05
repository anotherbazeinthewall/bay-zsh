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
    [[ "$TERM_PROGRAM" == "vscode" ]] || [[ -n "$VSCODE_PID" ]] || [[ -n "$VSCODE_INJECTION" ]]
}

# Set sourcing flag if we're sourcing the file
if [[ "${(%):-%N}" == ".zshrc" ]]; then
    export SOURCING_ZSHRC="true"
fi

# UNSET PREXISTING ENVS
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

# PIPENV
export PIPENV_VENV_IN_PROJECT=1
export PIPENV_VERBOSITY=-1

# =============================================================================
# ALIASES & CUSTOM FUNCTIONS
# =============================================================================

debug "\e[2;3mConfiguring aliases and custom functions... \e[0m"

alias ls='ls -aG' # Show hidden files by default
alias newpy='function _newpy() { poetry new $1 && cd $1 && poetry install && git init && touch .gitignore && echo "Project $1 created successfully!"; }; _newpy'
alias snap='(tree && find . -type f -exec sh -c "echo -e \"\n=== File: {} ===\n\"; cat {}" \;) | tee >(pbcopy)'

# =============================================================================
# PATH MANAGEMENT
# =============================================================================
debug "\e[2;3mConfiguring path management... \e[0m"

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
debug "\e[2;3mConfiguring environment management...\e[0m"

# Initialize NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

# Helper function to find files in parent directories
find_file_in_parents() {
    local file="$1"
    local dir="$PWD"
    
    while [[ "$dir" != "/" ]]; do
        [[ -e "$dir/$file" ]] && echo "$dir" && return 0
        dir=${dir:h}
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
        debug "Deactivating venv: $VIRTUAL_ENV"
        type deactivate >/dev/null 2>&1 && deactivate
        unset VIRTUAL_ENV VIRTUAL_ENV_INFO
    fi
}

activate_venv() {
    local venv_path="$1"
    if [[ -n "$venv_path" && -f "$venv_path/bin/activate" ]]; then
        debug "Activating venv: $venv_path"
        source "$venv_path/bin/activate"
        if [[ $? -eq 0 ]]; then
            local python_version=$(get_python_version "$venv_path/bin/python")
            export VIRTUAL_ENV_INFO="$(format_env_info "python" "$python_version")"
            debug "Activation successful: $VIRTUAL_ENV_INFO"
        else
            debug "Activation failed"
        fi
    fi
}

# Handle Python environment
handle_python_environment() {
    local project_dir="$1"
    local venv_path=$(get_venv_path "$project_dir")
    
    debug "handle_python_environment: project_dir=$project_dir venv_path=$venv_path"
    
    # Early return if no venv found
    [[ -z "$venv_path" ]] && return
    
    # VS Code with active venv - just update info
    if is_vscode && [[ -n "$VIRTUAL_ENV" ]]; then
        local python_version=$(get_python_version "$VIRTUAL_ENV/bin/python")
        export VIRTUAL_ENV_INFO="$(format_env_info "python" "$python_version")"
        return
    fi
    
    # Activate venv if not in VS Code or VS Code without active venv
    if ! is_vscode || [[ -z "$VIRTUAL_ENV" ]]; then
        activate_venv "$venv_path"
    fi
}

# Handle Node.js environment
handle_node_environment() {
    local project_dir="$1"
    local node_info=""
    
    # Only handle Node environment if we have node_modules or .nvmrc
    if [ -d "$project_dir/node_modules" ] || [ -f "$project_dir/.nvmrc" ]; then
        if [ -f "$project_dir/.nvmrc" ]; then
            nvm use >/dev/null 2>&1
        else
            nvm use default >/dev/null 2>&1
        fi
        
        if command -v node >/dev/null 2>&1; then
            local node_version=$(node -v | tr -d 'v')
            node_info=$(format_env_info "node" "$node_version")
        fi
    else
        # If we're not in a Node project, clear the node info
        node_info=""
    fi
    
    echo "$node_info"
}

# Main environment management function
manage_environment() {
    typeset -g ENVIRONMENT_MANAGEMENT_COUNT=${ENVIRONMENT_MANAGEMENT_COUNT:-0}
    ((ENVIRONMENT_MANAGEMENT_COUNT > 1)) && return
    
    ((ENVIRONMENT_MANAGEMENT_COUNT++))
    debug "Environment management level: $ENVIRONMENT_MANAGEMENT_COUNT"
    
    # Find project roots
    local python_root=$(find_file_in_parents "venv" || find_file_in_parents ".venv")
    local node_root=$(find_file_in_parents "node_modules" || find_file_in_parents ".nvmrc")
    
    # Handle environments
    [[ -n "$python_root" ]] && handle_python_environment "$python_root" || deactivate_venv
    
    # Handle Node environment
    local node_info=""
    [[ -n "$node_root" ]] && node_info=$(handle_node_environment "$node_root")
    
    # Update environment info
    if [[ -n "$node_info" ]]; then
        export VIRTUAL_ENV_INFO="${VIRTUAL_ENV_INFO}${node_info}"
    elif [[ -z "$python_root" ]]; then
        export VIRTUAL_ENV_INFO=""
    fi
    
    ((ENVIRONMENT_MANAGEMENT_COUNT--))
    ((ENVIRONMENT_MANAGEMENT_COUNT == 0)) && unset ENVIRONMENT_MANAGEMENT_COUNT
}

# Set up directory change hook
autoload -U add-zsh-hook
add-zsh-hook chpwd manage_environment

# Initial environment setup
manage_environment

# =============================================================================
# GIT CONFIGURATION
# =============================================================================
debug "\e[2;3mConfiguring Git prompt...\e[0m"

ZSH_THEME_GIT_PROMPT_PREFIX="%F{116}git("
ZSH_THEME_GIT_PROMPT_SUFFIX="%f "
ZSH_THEME_GIT_PROMPT_DIRTY="%F{116}) %F{78}*%f"
ZSH_THEME_GIT_PROMPT_CLEAN="%F{116})"

function git_prompt_info() {
    local branch_or_hash
    local is_detached=false

    # Try to get branch name first
    if branch_or_hash=$(git symbolic-ref HEAD 2> /dev/null); then
        # Remove refs/heads/ prefix and use green color for branch
        branch_or_hash="%F{green}${branch_or_hash#refs/heads/}"
    else
        # If in detached HEAD, get commit hash and use purple color
        branch_or_hash=$(git rev-parse --short HEAD 2> /dev/null) || return
        is_detached=true
        branch_or_hash="%F{magenta}${branch_or_hash}"
    fi

    echo "$ZSH_THEME_GIT_PROMPT_PREFIX${branch_or_hash}$(parse_git_dirty)$ZSH_THEME_GIT_PROMPT_SUFFIX"
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

debug "\e[2;3mConfiguring prompt enhancements...\e[0m"

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
debug "\e[2;3mConfiguring completion system and keybindings...\e[0m"

# Initialize zsh-autosuggestions
[[ ! -d ~/.zsh/zsh-autosuggestions ]] && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# Initialize storage variable
typeset -g _saved_postdisplay=""

# Delimiter functions
local DELIMITERS=('/' ':' ' ')

function forward_to_delimiter() {
    [[ -z $POSTDISPLAY ]] && return

    local suggestion=$POSTDISPLAY
    local offset=0

    # Check if starts with delimiter
    [[ $suggestion[1] =~ [/:\ ] ]] && {
        suggestion=${suggestion:1}
        offset=1
    }

    # Find closest delimiter
    local min_pos=$((${#suggestion} + 1))
    for delim in $DELIMITERS; do
        local pos=${suggestion[(i)$delim]}
        [[ $pos -le ${#suggestion} ]] && ((pos < min_pos)) && min_pos=$pos
    done

    # Move cursor and trigger proper highlighting
    if [[ $min_pos -le ${#suggestion} ]]; then
        CURSOR=$((CURSOR + min_pos + offset))
        _zsh_autosuggest_highlight_reset
        _zsh_autosuggest_highlight_apply
    else
        CURSOR=$((CURSOR + ${#POSTDISPLAY}))
        _zsh_autosuggest_highlight_reset
    fi

    # Ensure proper color state
    region_highlight=()
    region_highlight+=("0 ${#BUFFER} default") # White for BUFFER
    (( ${#POSTDISPLAY} > 0 )) && region_highlight+=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=242") # Gray for POSTDISPLAY
    zle -R
}

function backward_to_delimiter() {
    [[ $CURSOR -eq 0 ]] && return

    # Initialize or preserve suggestion
    [[ -z "$_saved_postdisplay" ]] && _saved_postdisplay="$POSTDISPLAY"

    local last_pos=0
    local text_before="$LBUFFER"

    # Find last delimiter
    for ((i = CURSOR - 1; i > 0; i--)); do
        [[ "${text_before[$i]}" =~ [/:\ ] ]] && {
            last_pos=$i
            break
        }
    done

    if ((last_pos > 0)); then
        _saved_postdisplay="${LBUFFER:$last_pos:$((CURSOR-last_pos))}$_saved_postdisplay"
        POSTDISPLAY="$_saved_postdisplay"
        BUFFER="${LBUFFER[1,$last_pos]}"
        CURSOR=$last_pos
    else
        BUFFER="" POSTDISPLAY="" _saved_postdisplay="" CURSOR=0
    fi

    # Ensure proper color state
    region_highlight=()
    region_highlight+=("0 ${#BUFFER} default") # White for BUFFER
    (( ${#POSTDISPLAY} > 0 )) && region_highlight+=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=242") # Gray for POSTDISPLAY
    zle -R
}

function reset_saved_suggestion() { 
    _saved_postdisplay=""
}

# Initialize widgets
for widget in forward_to_delimiter backward_to_delimiter \
            reset_saved_suggestion; do
    zle -N $widget
done

# Configure zsh-autosuggestions widgets
typeset -ga ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=(
    forward_to_delimiter
    $ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS
)

ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(reset_saved_suggestion)
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#forward-char}")
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#vi-forward-char}")
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# Key bindings
bindkey '^I'   autosuggest-accept           # Tab
bindkey '^E'   forward_to_delimiter         # Cmd+Right (Ctrl+E)
bindkey '^A'   backward_to_delimiter        # Cmd+Left (Ctrl+A)

# Enable completion system
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
autoload -Uz compinit && compinit

# =============================================================================
# FINAL INITIALIZATION
# =============================================================================

debug "\e[1;3;32mSuccessfully loaded ZSH Run Commands!\e[0m"