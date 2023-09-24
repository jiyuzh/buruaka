#!/usr/bin/env bash

#
# Preemble
#

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

#
# Installer
#

# import library
source "$SCRIPT_DIR/lib/common.sh"

# system check
echo "Environment Harmonization Script by Jiyuan Zhang"
echo

DISTRO_VERSION=`lsb_release -a 2>&1 | perl -ne 'print "$1" if /\bUbuntu (20|22)\.04/'`
if [ -z "$DISTRO_VERSION" ]; then
	echo "This script requires Ubuntu 20.04 or 22.04 to run"
	exit 1
fi

# TODO: do_confirm _discard "Perform install?"
# TODO: mode selection: evaluation setup or self setup

#
# Installer
#

# Parameters:
# 	$1: Package name.
# 	$2: File name.
# 	$3: Target path,
function install_file {
	copy_path "$SCRIPT_DIR/install/$1/$2" "$3" 1 1
}

function install_core {
	sudo apt-get update
	sudo apt-get install -y apt-transport-https
	sudo apt-get update
	sudo apt-get install -y bash curl git man perl sudo wget screen vim nano software-properties-common
	sudo apt-get install -y python3 python3-dev python3-pip
}

function install_kernbuild {
	sudo apt-get update
	sudo apt-get install -y build-essential linux-tools-common linux-tools-generic liblz4-tool dwarves binutils elfutils gdb flex bison libncurses-dev libssl-dev libelf-dev
	sudo apt-get install -y cmake gcc g++ make libiberty-dev autoconf zstd libboost-all-dev arch-install-scripts
	sudo apt-get install -y libdw-dev systemtap-sdt-dev libunwind-dev libslang2-dev libperl-dev liblzma-dev libzstd-dev libcap-dev libnuma-dev libbabeltrace-ctf-dev libbfd-dev
}

function install_checkinstall {
	sudo apt-get install -y checkinstall
}

function install_dotnet {
	declare repo_version=$(if command -v lsb_release &> /dev/null; then lsb_release -r -s; else grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"'; fi)
	sudo wget https://packages.microsoft.com/config/ubuntu/$repo_version/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
	sudo dpkg -i packages-microsoft-prod.deb
	sudo rm packages-microsoft-prod.deb

	sudo apt-get update
	sudo apt-get install dotnet-sdk-7.0
}

function install_xonsh {
	sudo apt-get update
	sudo apt-get install -y xonsh

	install_file "xonsh" ".xonshrc" "$HOME/.xonshrc"
}

function install_micro {
	sudo apt-get update
	sudo apt-get install -y xclip # for SSH clipboard support
	sudo apt-get install -y fzf exuberant-ctags # for jump plugin

	curl https://getmic.ro | sudo bash
	move_path "micro" "/usr/bin/micro" 1 1

	micro --plugin install detectindent # auto select indent for files
	micro --plugin install filemanager # file system support
	micro --plugin install jump # enable definition jump with F4, need fzf and ctags
	micro --plugin install quoter # enable auto quote surrounding for selections

	install_file "micro" "bindings.json" "$HOME/.config/micro/bindings.json"
	install_file "micro" "settings.json" "$HOME/.config/micro/settings.json"
}

function install_utils {
	sudo apt-get update
	sudo apt-get install -y ripgrep
}

function install_utils {
	sudo apt-get update
	sudo apt-get install -y ripgrep
}

function install_ssh_conf {
	if sudo test ! -e "$HOME/.ssh/config"; then
		sudo mkdir -vp "$HOME/.ssh"
		sudo touch "$HOME/.ssh/config"
	fi

	if ! sudo grep -q "Host github.deanon" "$HOME/.ssh/config"; then
		cat << 'END' >> "$HOME/.ssh/config"
Host github.deanon
	HostName github.com
	User git
	IdentityFile ~/.ssh/id_ed25519_unsafe
END
	fi

	install_file "ssh" "id_ed25519_unsafe.pub" "$HOME/.ssh/id_ed25519_unsafe.pub"
	sudo nano "$HOME/.ssh/id_ed25519_unsafe"

	sudo pip3 install ssh-import-id
	ssh-import-id gh:jiyuzh
}

function install_bash_conf {
	if sudo test ! -e "$HOME/.bashrc"; then
		sudo mkdir -vp "$HOME"
		sudo touch "$HOME/.bashrc"
	fi

	if ! sudo grep -q 'if [ -f ~/.bashrc_jz ]' "$HOME/.bashrc"; then
		cat << 'END' >> "$HOME/.bashrc"
if [ -f ~/.bashrc_jz ]; then
	. ~/.bashrc_jz
fi
END
	fi

	install_file "bash" ".bashrc_jz" "$HOME/.bashrc_jz"
	sed -i "s@{{buruaka}}@$SCRIPT_DIR/bin@g" "$HOME/.bashrc_jz"
}

function install_tmux {
	sudo apt-get update
	sudo apt-get install -y tmux xclip

	install_file "tmux" ".tmux.conf" "$HOME/.tmux.conf"
	install_file "tmux" ".tmux.conf.local" "$HOME/.tmux.conf.local"
}
