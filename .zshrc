# =============================================================================
# HOUSEKEEPING
# =============================================================================

export DEBUG_ZSH=false  # Set to 'true' if you want debug messages

debug() {
    if [ "$DEBUG_ZSH" = true ]; then
        echo "DEBUG: $1" >&2
    fi
}

debug "\e[2;3mInitiating ZSH Run Commands...\e[0m"

# Helper function to detect VS Code
is_vscode() {
    [[ "$TERM_PROGRAM" == "vscode" ]] || [[ -n "$VSCODE_PID" ]] || [[ -n "$VSCODE_INJECTION" ]]
}

# If sourcing this file directly...
if [[ "${(%):-%N}" == ".zshrc" ]]; then
    export SOURCING_ZSHRC="true"
fi

# Clear out stale/invalid VIRTUAL_ENV
if [[ -n "$VIRTUAL_ENV" ]] && [[ ! -d "$VIRTUAL_ENV" ]]; then
    unset VIRTUAL_ENV
fi

# No custom prompt from Python venv
export VIRTUAL_ENV_DISABLE_PROMPT=1
unset VIRTUAL_ENV_INFO

# Basic color settings
export TERM="xterm-256color"
export ZSH_TMUX_FIXTERM=256
export COLORTERM="truecolor"

# Don’t write .pyc files
export PYTHONDONTWRITEBYTECODE=1

# Pyenv: keep it here for “self containment”
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# PIPENV
export PIPENV_VENV_IN_PROJECT=1
export PIPENV_VERBOSITY=-1

# =============================================================================
# ALIASES & CUSTOM FUNCTIONS
# =============================================================================

debug "\e[2;3mConfiguring aliases and custom functions...\e[0m"

alias ls='gls -lah --color=always | grep -E --color=never "^d.*" && gls -lah --color=always | grep -E --color=never -v "^d" | grep -v "^total"'

snap() {
    local dir=${1:-.}
    if [[ $# -gt 0 ]]; then
        shift
    fi
    local exclude_args=""
    for pattern in "$@"; do
        exclude_args="$exclude_args -not -path \"*/$pattern*\""
    done

    (
        cd "$dir" && \
        echo "=== Current Path: $(pwd) ===" && \
        echo && \
        echo "=== Directory Structure ===" && \
        find . -type d -not -path "*/\.*" | sort | \
        awk '{
            gsub(/[^\/]+\//, "  ", $0);
            gsub(/\.\//, "", $0);
            if (length($0) > 0) print "- " $0;
        }' && \
        echo && \
        echo "=== Files ===" && \
        find . -type f -not -path "*/\.*" | sort | \
        awk '{
            gsub(/\.\//, "", $0);
            print "- " $0;
        }' && \
        echo && \
        eval "find . -type f -not -path \"*/\.*\" $exclude_args -exec sh -c 'printf \"\n\n=== File: {} ===\n\n\"; cat {}' \;"
    ) | tee >(pbcopy)
}

# =============================================================================
# PATH MANAGEMENT
# =============================================================================

debug "\e[2;3mConfiguring path management...\e[0m"

export PATH="$HOME/.local/bin:$PATH"

# Deduplicate PATH
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

debug "\e[2;3mSetting up environment management...\e[0m"

# Lazy-load nvm
lazy_load_nvm() {
    if [[ -z "$LAZY_NVM_LOADED" ]]; then
        debug "Lazy-loading nvm..."
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        export LAZY_NVM_LOADED=1
    fi
}

# Set up NVM_DIR but don't source yet
export NVM_DIR="$HOME/.nvm"

# Helper to find file upwards
find_file_in_parents() {
    local file="$1"
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        [[ -e "$dir/$file" ]] && echo "$dir" && return 0
        dir=${dir:h}
    done
    return 1
}

# Get python version from interpreter
get_python_version() {
    local python_path="${1:-python}"
    "$python_path" -c "import sys; print('.'.join(map(str, sys.version_info[:3])))" 2>/dev/null
}

format_env_info() {
    local type="$1"
    local version="$2"
    echo "${type}(${version}) "
}

# Deactivate existing venv
deactivate_venv() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        debug "Deactivating venv: $VIRTUAL_ENV"
        type deactivate >/dev/null 2>&1 && deactivate
    fi
    unset VIRTUAL_ENV
    unset VIRTUAL_ENV_INFO
}

# Activate a new venv
activate_venv() {
    local venv_path="$1"
    if [[ -n "$venv_path" && -f "$venv_path/bin/activate" ]]; then
        debug "Activating venv: $venv_path"
        source "$venv_path/bin/activate"
        if [[ $? -eq 0 ]]; then
            local python_version
            python_version="$(get_python_version "$venv_path/bin/python")"
            export VIRTUAL_ENV_INFO="$(format_env_info "python" "$python_version")"
            debug "Activation successful: $VIRTUAL_ENV_INFO"
        else
            debug "Activation failed"
        fi
    fi
}

get_venv_path() {
    local base_dir="$1"
    if [[ -d "$base_dir/venv" ]]; then
        echo "$base_dir/venv"
    elif [[ -d "$base_dir/.venv" ]]; then
        echo "$base_dir/.venv"
    fi
}

# Updated handle_python_environment to check the actual interpreter
handle_python_environment() {
    local project_dir="$1"
    local venv_path
    venv_path="$(get_venv_path "$project_dir")"
    
    debug "handle_python_environment: project_dir=$project_dir venv_path=$venv_path"

    # Reset VIRTUAL_ENV_INFO so we don't show stale data.
    export VIRTUAL_ENV_INFO=""

    if [[ -n "$venv_path" ]]; then
        # Check if the venv is already active and matches the expected interpreter
        if [[ "$VIRTUAL_ENV" == "$venv_path" && "$(which python)" == "$venv_path/bin/python" ]]; then
            # Already using the correct venv
            local python_version
            python_version="$(get_python_version "$venv_path/bin/python")"
            export VIRTUAL_ENV_INFO="$(format_env_info "python" "$python_version")"
        else
            # Otherwise, activate the venv
            activate_venv "$venv_path"
        fi
    else
        # No local venv found => deactivate any existing one
        deactivate_venv
    fi
}

handle_node_environment() {
    local project_dir="$1"
    local node_info=""
    
    if [[ -d "$project_dir/node_modules" ]] || [[ -f "$project_dir/.nvmrc" ]]; then
        # Actually load nvm
        lazy_load_nvm
        
        if [[ -f "$project_dir/.nvmrc" ]]; then
            nvm use >/dev/null 2>&1
        else
            nvm use default >/dev/null 2>&1
        fi
        
        if command -v node >/dev/null 2>&1; then
            local node_version
            node_version="$(node -v | tr -d 'v')"
            node_info="$(format_env_info "node" "$node_version")"
        fi
    else
        node_info=""
    fi
    echo "$node_info"
}

manage_environment() {
    typeset -g ENVIRONMENT_MANAGEMENT_COUNT=${ENVIRONMENT_MANAGEMENT_COUNT:-0}
    (( ENVIRONMENT_MANAGEMENT_COUNT > 1 )) && return
    
    (( ENVIRONMENT_MANAGEMENT_COUNT++ ))
    debug "Environment management level: $ENVIRONMENT_MANAGEMENT_COUNT"
    
    # Locate Python project root
    local python_root
    python_root="$(find_file_in_parents "venv" || find_file_in_parents ".venv")"
    
    if [[ -n "$python_root" ]]; then
        handle_python_environment "$python_root"
    else
        # If there's an active venv but no .venv found in parents => deactivate
        if [[ -n "$VIRTUAL_ENV" ]]; then
            deactivate_venv
        fi
    fi
    
    # Node environment
    local node_root
    node_root="$(find_file_in_parents "node_modules" || find_file_in_parents ".nvmrc")"
    local node_info=""
    if [[ -n "$node_root" ]]; then
        node_info="$(handle_node_environment "$node_root")"
    fi
    
    # Merge environment info if applicable
    if [[ -n "$node_info" || -n "$python_root" ]]; then
        export VIRTUAL_ENV_INFO="${VIRTUAL_ENV_INFO:-}${node_info}"
    else
        export VIRTUAL_ENV_INFO=""
    fi
    
    (( ENVIRONMENT_MANAGEMENT_COUNT-- ))
    (( ENVIRONMENT_MANAGEMENT_COUNT == 0 )) && unset ENVIRONMENT_MANAGEMENT_COUNT
}

autoload -U add-zsh-hook
# For directory changes
add-zsh-hook chpwd manage_environment

# Force environment management right before the first prompt
# so it sees the actual $PWD on a *newly opened shell*
add-zsh-hook precmd manage_environment

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

    if branch_or_hash=$(git symbolic-ref HEAD 2> /dev/null); then
        branch_or_hash="%F{green}${branch_or_hash#refs/heads/}"
    else
        branch_or_hash=$(git rev-parse --short HEAD 2> /dev/null) || return
        is_detached=true
        branch_or_hash="%F{magenta}${branch_or_hash}"
    fi

    echo "$ZSH_THEME_GIT_PROMPT_PREFIX${branch_or_hash}$(parse_git_dirty)$ZSH_THEME_GIT_PROMPT_SUFFIX"
}

function parse_git_dirty() {
    local STATUS=''
    local FLAGS=('--porcelain')
    local CONFIG_HIDE_DIRTY
    CONFIG_HIDE_DIRTY="$(git config --get zsh.hide-dirty)"
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

debug "\e[2;3mConfiguring prompt...\e[0m"

setopt PROMPT_SUBST

function set_prompt_username() {
    prompt_username="%F{78}%n%f"
}

# Colorize environment info
function format_env_info_prompt() {
    local env_info="$1"
    if [[ -n "$env_info" ]]; then
        if [[ "$env_info" =~ "(python|node)\((.*)\) " ]]; then
            local env_type="${match[1]}"
            local version="${match[2]}"
            echo "%F{221}${env_type}(%F{211}${version}%F{221})%f "
        else
            echo "$env_info"
        fi
    fi
}

add-zsh-hook precmd set_prompt_username

PROMPT='%F{176}☼%f ${prompt_username} %F{209}%~%f ${VIRTUAL_ENV_INFO:+"$(format_env_info_prompt "$VIRTUAL_ENV_INFO")"}$(git_prompt_info)%B%F{white}%#%f%b '

# =============================================================================
# COMPLETION SYSTEM & KEYBINDINGS
# =============================================================================

debug "\e[2;3mConfiguring completion & keybindings...\e[0m"

# Clone zsh-autosuggestions only if missing
if [[ ! -d "$HOME/.zsh/zsh-autosuggestions" ]]; then
    debug "zsh-autosuggestions not found, cloning..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/zsh-autosuggestions" || \
        echo "WARNING: Failed to clone zsh-autosuggestions."
fi

# Source it if available
if [[ -f "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
else
    debug "zsh-autosuggestions directory found, but zsh-autosuggestions.zsh doesn't exist."
fi

typeset -g _saved_postdisplay=""

local DELIMITERS=('/' ':' ' ')

function forward_to_delimiter() {
    [[ -z $POSTDISPLAY ]] && return
    local suggestion=$POSTDISPLAY
    local offset=0
    [[ $suggestion[1] =~ [/:\ ] ]] && {
        suggestion=${suggestion:1}
        offset=1
    }
    local min_pos=$((${#suggestion} + 1))
    for delim in $DELIMITERS; do
        local pos=${suggestion[(i)$delim]}
        (( pos <= ${#suggestion} && pos < min_pos )) && min_pos=$pos
    done
    if (( min_pos <= ${#suggestion} )); then
        CURSOR=$((CURSOR + min_pos + offset))
        _zsh_autosuggest_highlight_reset
        _zsh_autosuggest_highlight_apply
    else
        CURSOR=$((CURSOR + ${#POSTDISPLAY}))
        _zsh_autosuggest_highlight_reset
    fi
    region_highlight=()
    region_highlight+=("0 ${#BUFFER} default")
    (( ${#POSTDISPLAY} > 0 )) && region_highlight+=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=242")
    zle -R
}

function backward_to_delimiter() {
    [[ $CURSOR -eq 0 ]] && return
    [[ -z "$_saved_postdisplay" ]] && _saved_postdisplay="$POSTDISPLAY"

    local last_pos=0
    local text_before="$LBUFFER"
    for ((i = CURSOR - 1; i > 0; i--)); do
        if [[ "${text_before[$i]}" =~ [/:\ ] ]]; then
            last_pos=$i
            break
        fi
    done

    if (( last_pos > 0 )); then
        _saved_postdisplay="${LBUFFER:$last_pos:$((CURSOR - last_pos))}$_saved_postdisplay"
        POSTDISPLAY="$_saved_postdisplay"
        BUFFER="${LBUFFER[1,$last_pos]}"
        CURSOR=$last_pos
    else
        BUFFER="" POSTDISPLAY="" _saved_postdisplay="" CURSOR=0
    fi

    region_highlight=()
    region_highlight+=("0 ${#BUFFER} default")
    (( ${#POSTDISPLAY} > 0 )) && region_highlight+=("${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) fg=242")
    zle -R
}

function reset_saved_suggestion() {
    _saved_postdisplay=""
}

for widget in forward_to_delimiter backward_to_delimiter reset_saved_suggestion; do
    zle -N $widget
done

typeset -ga ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=(
    forward_to_delimiter
    $ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS
)
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(reset_saved_suggestion)
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#forward-char}")
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=("${(@)ZSH_AUTOSUGGEST_ACCEPT_WIDGETS:#vi-forward-char}")
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

bindkey '^I'   autosuggest-accept
bindkey '^E'   forward_to_delimiter
bindkey '^A'   backward_to_delimiter

# Enable ZSH completion
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
autoload -Uz compinit && compinit

# =============================================================================
# FINAL INITIALIZATION
# =============================================================================

debug "\e[1;3;32mSuccessfully loaded ZSH Run Commands!\e[0m"
