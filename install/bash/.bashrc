# Rewrite tools
____cdls_hist=()
____cdls_last=""
____cdls_hi=8 # high watermark (lines of output)
____cdls_lo=6 # low watermark (lines of output)

____cdls_print () {
	____cdls_txt=`ls -C -w $(tput cols) --color=always`
	____cdls_cnt=`echo "$____cdls_txt" | wc -l`

	if [ $____cdls_cnt -lt $____cdls_hi ]; then
		echo "$____cdls_txt"
	else
		____cdls_head=$(($____cdls_lo / 2))
		____cdls_tail=$(($____cdls_lo - $____cdls_head))
		____cdls_rem=$(($____cdls_cnt - $____cdls_lo))
		
		echo "$____cdls_txt" | head -n $____cdls_head
		echo "..."
		echo "$____cdls_txt" | tail -n $____cdls_tail
		echo "($____cdls_rem lines not shown)"
	fi
}

____cdls_forward () {
	____cdls_normpath=`realpath -es "$PWD" 2>/dev/null`
	cd "$1"
	if [ "$?" -eq "0" ] && [ ! -z "$____cdls_normpath" ] && [ "$____cdls_last" != "$____cdls_normpath" ]; then
		____cdls_hist=( "$____cdls_normpath" "${____cdls_hist[@]}" )
		____cdls_last="$____cdls_normpath"
	fi

	____cdls_print
}

____cdls_bachward () {
	____cdls_idx=0
	if [ "$#" -ge 1 ]; then
		____cdls_idx=$(($1 - 1))
	fi

	____cdls_normpath="${____cdls_hist[$____cdls_idx]}"

	if [ ! -z "$____cdls_normpath" ]; then
		cd "$____cdls_normpath"

		____cdls_idx=$(($____cdls_idx + 1))
		____cdls_hist=( "${____cdls_hist[@]:$____cdls_idx}" )
	else
		echo "No more history. Staying in current folder."
	fi

	____cdls_print
}

____cdls_history () {
	i=1
	for ____cdls_normpath in "${____cdls_hist[@]}"; do
		echo "	$i	$____cdls_normpath"
		i=$(($i + 1))
	done
}

____diff () {
	if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
		git dir-diff "$@"
	elif command -v delta &> /dev/null; then
		delta "$@"
	else
		diff "$@"
	fi
}

alias ls='ls --color=auto'
alias ll='ls -alhF'

alias g='____cdls_forward'
alias gg='____cdls_bachward'
alias ggg='____cdls_history'

alias vi='micro'
alias grep='rg'
alias cat='bat'
alias diff='____diff'

# Better history
HISTCONTROL='ignoredups'
HISTSIZE=100000
HISTFILESIZE=200000
HISTTIMEFORMAT='%F %T '

# PowerLine-like PS
____SEP=''
____git_branch () {
	____git=`git rev-parse --abbrev-ref HEAD 2> /dev/null`

	if [ "$____git" = "" ]; then
		____git='?'
	fi

	echo "$____git"
}

____SEPFG=256
____add_ps1 () {
	____txt="$1"
	____fg=$2
	____bg=$3
	
	if [ $____SEPFG -lt 256 ]; then
		# not first part, inhert sep
		PS1+='\['"$(tput setaf $____SEPFG)$(tput setab $____bg)"'\]$____SEP'
	fi

	if [ $____bg -ge 256 ] || [ $____fg -ge 256 ]; then
		# final part, cleanup
		PS1+='\['"$(tput sgr0)"'\]'
		
		____SEPFG=256
	else
		# middle part, output text
		PS1+='\['"$(tput setaf $____fg)$(tput setab $____bg)"'\]'" $____txt "

		____SEPFG=$____bg
	fi
}

PS1='\n'
____add_ps1 '$(date +%T)' 245 232
____add_ps1 '$(hostname)' 232 226
____add_ps1 '$USER' 231 196
____add_ps1 '$(pwd)' 231 200
____add_ps1 '$(____git_branch)' 232 118
____add_ps1 '' 257 257
PS1+='\n\$ '
PS2='> '

# Auto completion
[ -f /etc/bash_completion ] && ! shopt -oq posix && . /etc/bash_completion

# 24-bit color support
apply_24b=""
case "$COLORTERM" in
truecolor|24bit|24-bit)
	apply_24b=true
	;;
esac
if [ "$apply_24b" = "" ] && [ "$(tput colors)" = "16777216" ]; then
	apply_24b=true
fi
if [ "$apply_24b" = "true" ]; then
	export MICRO_TRUECOLOR=1
fi

# Path
export EDITOR=micro
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/ripgreprc"
export BAT_CONFIG_PATH="$HOME/.config/bat/config"

# Timezone
export TZ="America/Chicago"

# Modernize LESS
export LESS='--quiet --quit-if-one-screen --ignore-case --tabs=4 --mouse --wheel-lines=3 --RAW-CONTROL-CHARS'

# TMUX
if [[ -z "$TMUX" ]] && [[ -n "$SSH_CONNECTION" ]]; then
	tmux attach-session -t ssh-tmux-jz || tmux new-session -s ssh-tmux-jz
fi

# Postexec
____show_exception () {
	____ret="$?"
	if [ "$____ret" -ne "0" ]; then
		printf '\n'"$(tput setaf 9)(Return Code = $____ret)$(tput sgr0)"'\n'
	fi
}

____post_exec () {
	____show_exception
}

PROMPT_COMMAND="${PROMPT_COMMAND}"$'\n'"____post_exec;";

# Idempotence
if [[ -z "$BURUAKA_INIT_ONCE" ]]; then
	export BURUAKA_INIT_ONCE=1

	export PATH="$PATH:$____buruaka/bin"
fi
