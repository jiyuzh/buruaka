#!/usr/bin/env bash

set -euo pipefail

# failure message
function __error_handing {
	local last_status_code=$1;
	local error_line_number=$2;
	echo 1>&2 "Error - exited with status $last_status_code at line $error_line_number";
	perl -slne 'if($.+5 >= $ln && $.-4 <= $ln){ $_="$. $_"; s/$ln/">" x length($ln)/eg; s/^\D+.*?$/\e[1;31m$&\e[0m/g;  print}' -- -ln=$error_line_number $0
}

trap '__error_handing $? $LINENO' ERR

# file locator
SCRIPT_DIR=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")

"$SCRIPT_DIR/install.sh" core kernbuild checkinstall dotnet micro ripgrep tmux bash_conf grub_conf ssh_conf