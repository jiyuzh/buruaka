#!/usr/bin/env bash

# Check if currently running as the root user, if not, quit invoker script with error.
# Parameters:
# 	None
# Interaction:
# 	The error message, if any.
# Return:
# 	None
function assert_root {
	if [ "$EUID" -ne 0 ]; then
		echo "Please run as root"
		exit 1
	fi
}

# Prompt the user with a yes-no confirmation.
# Parameters:
# 	$1: Name of parameter to receive output.
# 	$2: The prompt message.
# Interaction:
# 	The prompt message.
# Return:
# 	None
# Example: do_confirm shouldDelete "Delete the file?"
function do_confirm {
	while :; do
		read -p "$2 (y/n) " yn
		case $yn in
		[Yy]* )
			eval "$1=1"
			break
			;;
		[Nn]* )
			eval "$1=0"
			break
			;;
		* )
			echo "Please answer yes or no."
			;;
		esac
	done
}

# Recursively remove a file or folder with common cases considered.
# Parameters:
# 	$1: Target file or folder.
# 	$2: [Optional] Should the target or its parent folder prevents the copy operation,
# 	    optionally remove them after optional interactive confirmation.
# 	    0: Do not perform removal. Equivalent to no-op.
# 	    1: [Default] Perform removal with confirmation.
# 	    2: Perform removal without confirmation.
# 	$3: [Optional] Select whether the operations should be run with sudo.
# 	    0: [Default] Run as-is.
# 	    1: Run with sudo.
# Note:
# 	Do not support wildcards.
# Interaction:
# 	The remove operation trace.
# 	Confirmation prompt if demanded.
# Return:
# 	None
# Usage: remove_path [dest_path] [[is_force]] [[is_sudo]]
# Example: remove_path ~/test 1 0
function remove_path {
	local target="$1"

	local isForce="1"
	if [ "$#" -ge 2 ]; then
		isForce="$2"
	fi

	local isSudo="0"
	if [ "$#" -ge 3 ]; then
		isSudo="$3"
	fi

	local shouldDelete="0"

	if [ "$isForce" -eq 0 ]; then
		return
	fi

	if sudo test ! -e "$target"; then
		return
	fi

	if [ "$isForce" -eq 1 ] && sudo test -e "$target"; then
		do_confirm shouldDelete "remove/overwrite: '$target'?"
		if [ "$shouldDelete" -eq 0 ]; then
			return
		fi
	fi

	if [ "$isForce" -ge 1 ] && [ "$isForce" -le 2 ]; then
		if [ "$isSudo" -eq 1 ]; then
			sudo rm -rfv "$target"
		else
			rm -rfv "$target"
		fi
	fi
}

# Copy a file or folder. Create parent folders when necessary.
# Parameters:
# 	$1: Source file or folder.
# 	$2: Destination file or folder. Must be the exact target.
# 	$3: [Optional] Should the target or its parent folder prevents the copy operation,
# 	    optionally remove them after optional interactive confirmation.
# 	    0: [Default] Do not perform overwrite.
# 	    1: Perform overwrite with confirmation.
# 	    2: Perform overwrite without confirmation.
# 	$4: [Optional] Select whether the operations should be run with sudo.
# 	    0: [Default] Run as-is.
# 	    1: Run with sudo.
# Interaction:
# 	The copy operation trace.
# 	Confirmation prompt if demanded.
# Return:
# 	None
# Usage: copy_path [source_path] [dest_path] [[is_force]] [[is_sudo]]
# Example: copy_path ./.xonshrc ~/.xonshrc 0 0
function copy_path {
	local source="$1"
	local target="$2"

	local isForce="0"
	if [ "$#" -ge 3 ]; then
		isForce="$3"
	fi

	local isSudo="0"
	if [ "$#" -ge 4 ]; then
		isSudo="$4"
	fi

	local dir=$(dirname "$target")

	# parent does not exists or is not a directory
	if sudo test ! -d "$dir"; then
		# create the parent
		if [ "$isSudo" -eq 1 ]; then
			sudo mkdir -pv "$dir"
		else
			mkdir -pv "$dir"
		fi
	fi

	local arg="-n"
	if [ "$isForce" -eq 0 ]; then
		arg="-n"
	elif [ "$isForce" -eq 1 ]; then
		arg="-if"
	elif [ "$isForce" -eq 2 ]; then
		arg="-f"
	fi

	if [ "$isSudo" -eq 1 ]; then
		sudo cp -rvT "$arg" "$source" "$target"
	else
		cp -rvT "$arg" "$source" "$target"
	fi
}

# Move a file or folder. Create parent folders when necessary.
# Parameters:
# 	$1: Source file or folder.
# 	$2: Destination file or folder. Must be the exact target.
# 	$3: [Optional] Should the target or its parent folder prevents the move operation,
# 	    optionally remove them after optional interactive confirmation.
# 	    0: [Default] Do not perform overwrite.
# 	    1: Perform overwrite with confirmation.
# 	    2: Perform overwrite without confirmation.
# 	$4: [Optional] Select whether the operations should be run with sudo.
# 	    0: [Default] Run as-is.
# 	    1: Run with sudo.
# Interaction:
# 	The move operation trace.
# 	Confirmation prompt if demanded.
# Return:
# 	None
# Usage: move_path [source_path] [dest_path] [[is_force]] [[is_sudo]]
# Example: move_path ./.xonshrc ~/.xonshrc 0 0
function move_path {
	local source="$1"
	local target="$2"

	local isForce="0"
	if [ "$#" -ge 3 ]; then
		isForce="$3"
	fi

	local isSudo="0"
	if [ "$#" -ge 4 ]; then
		isSudo="$4"
	fi

	local dir=$(dirname "$target")

	# parent does not exists or is not a directory
	if sudo test ! -d "$dir"; then
		# create the parent
		if [ "$isSudo" -eq 1 ]; then
			sudo mkdir -pv "$dir"
		else
			mkdir -pv "$dir"
		fi
	fi

	local arg="-n"
	if [ "$isForce" -eq 0 ]; then
		arg="-n"
	elif [ "$isForce" -eq 1 ]; then
		arg="-i"
	elif [ "$isForce" -eq 2 ]; then
		arg="-f"
	fi

	if [ "$isSudo" -eq 1 ]; then
		sudo mv -vT "$arg" "$source" "$target"
	else
		mv -vT "$arg" "$source" "$target"
	fi
}