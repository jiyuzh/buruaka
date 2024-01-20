#!/usr/bin/env bash

#
# Preemble
#

set -euo pipefail

# failure message
function __error_handing {
	local last_status_code="$1";
	local error_line_number="$2";
	echo 1>&2 "Error - exited with status $last_status_code at line $error_line_number";
	perl -slne 'if($.+5 >= $ln && $.-4 <= $ln){ $_="$. $_"; s/$ln/">" x length($ln)/eg; s/^\D+.*?$/\e[1;31m$&\e[0m/g;  print}' -- -ln="$error_line_number" "$0"
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

DISTRO_VERSION=$(lsb_release -a 2>&1 | perl -ne 'print "$1" if /\b(Ubuntu 2.*)/')
if [ -z "$DISTRO_VERSION" ]; then
	echo "This script requires Ubuntu 20.04 or 22.04 to run"
	exit 1
else
	echo "Detected your OS as: $DISTRO_VERSION"
	echo
fi

if [ "$EUID" -eq 0 ]; then
	echo "It seems like you are running this script as root."
	echo "- If you are running the script with sudo, please quit, remove sudo and try again."
	echo "- If you are running the script with root account, please ignore this message."
	echo
	do_confirm issudo "Are you running this with sudo?"
	echo
	if [ "$issudo" -eq "1" ]; then
		echo "Please remove sudo and try again"
		exit 1
	fi
fi

#
# Dependency
#

# Parameters:
# 	$1: Package name.
# 	$2: File name.
# 	$3: Target path,
function deploy_file {
	link_path "$SCRIPT_DIR/install/$1/$2" "$3" 1 0
}

function reflect_file {
	link_path "$3" "$SCRIPT_DIR/reflect/$1/$2" 2 0
}

function dep_uctags {
	sudo wget -O "/opt/uctags.tar.xz" "$("$SCRIPT_DIR/bin/github-get-release" -1 universal-ctags/ctags-nightly-build 'uctags-.*-linux-x86_64.tar.xz')"
	sudo mkdir -p "/opt/uctags"
	sudo tar -xf "/opt/uctags.tar.xz" -C "/opt/uctags" --strip-components=1
	sudo rm -f "/opt/uctags.tar.xz"

	if sudo test -e "/opt/uctags/bin/ctags"; then
		sudo ln -s /opt/uctags/bin/ctags /usr/local/bin/ctags
	else
		sudo rm -rf "/opt/uctags"
	fi
}

#
# Installer
#

function install_noop {
	true
}

function install_core {
	# How can you survive without these?
	sudo apt-get update
	sudo apt-get install -y apt-transport-https
	sudo apt-get update
	sudo apt-get install -y bash curl git man perl perl-doc sudo wget screen vim nano software-properties-common zip unzip tar rsync
	sudo apt-get install -y python3 python3-dev python3-pip python3-venv
	sudo apt-get install -y python3-userpath || pip3 install userpath

	if ! python3 -m userpath verify "$HOME/.local/bin"; then
		python3 -m userpath append "$HOME/.local/bin"
		export PATH="$PATH:$HOME/.local/bin"
	fi

	if ! python3 -m userpath verify "$SCRIPT_DIR/bin"; then
		python3 -m userpath append "$SCRIPT_DIR/bin"
		export PATH="$PATH:$SCRIPT_DIR/bin"
	fi
}

function install_kernbuild {
	# Kernel build tools (tested for 5.15)
	sudo apt-get update
	sudo apt-get install -y build-essential linux-tools-common linux-tools-generic liblz4-tool dwarves binutils elfutils gdb flex bison libncurses-dev libssl-dev libelf-dev
	sudo apt-get install -y cmake gcc g++ make libiberty-dev autoconf zstd libboost-all-dev arch-install-scripts
	sudo apt-get install -y libdw-dev systemtap-sdt-dev libunwind-dev libslang2-dev libperl-dev liblzma-dev libzstd-dev libcap-dev libnuma-dev libbabeltrace-ctf-dev libbfd-dev
	sudo apt-get install -y clang clang-format clang-tools llvm
}

function install_dotnet {
	# I love Microsoft
	sudo wget https://dot.net/v1/dotnet-install.sh -O /opt/dotnet-install.sh
	sudo chmod +x /opt/dotnet-install.sh
	sudo /opt/dotnet-install.sh --version latest --install-dir /opt/dotnet/
	if sudo test -e "/opt/dotnet/dotnet"; then
		sudo ln -s /opt/dotnet/dotnet /usr/local/bin/dotnet
	fi
}

function install_micro {
	# Install micro editor, depends on bash_conf to override `vi` (use `vim` for _that_ editor)
	sudo apt-get update
	sudo apt-get install -y xsel xclip # for SSH clipboard support
	sudo apt-get install -y fzf # for jump plugin
	dep_uctags

	curl https://getmic.ro | sudo bash
	move_path "micro" "/usr/bin/micro" 1 1

	micro --plugin install detectindent # auto select indent for files
	micro --plugin install filemanager # file system support
	micro --plugin install jump # enable definition jump with F4, need fzf and ctags
	micro --plugin install quoter # enable auto quote surrounding for selections

	deploy_file "micro" "bindings.json" "$HOME/.config/micro/bindings.json"
	deploy_file "micro" "settings.json" "$HOME/.config/micro/settings.json"
	deploy_file "micro" "colorschemes/vscode.micro" "$HOME/.config/micro/colorschemes/vscode.micro"
}

function install_ripgrep {
	# Nice little grep tool with sane regex
	sudo apt-get update
	sudo apt-get install -y ripgrep

	export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/ripgreprc"

	deploy_file "ripgrep" ".ripgreprc" "$HOME/.config/ripgrep/ripgreprc"
}

function install_delta {
	# Use musl version to avoid libc mess
	sudo wget -O delta-musl.deb "$("$SCRIPT_DIR/bin/github-get-release" -1 dandavison/delta 'git-delta-musl_.*_amd64.deb')"
	sudo dpkg -i delta-musl.deb
	sudo rm -f delta-musl.deb

	if sudo test ! -e "$HOME/.gitconfig"; then
		sudo mkdir -vp "$HOME"
		sudo touch "$HOME/.gitconfig"
		sudo chown -R "$USER:$USER" "$HOME/.gitconfig"
	fi

	if ! sudo grep -Fq 'pager = delta' "$HOME/.gitconfig"; then
		cat << 'END' >> "$HOME/.gitconfig"
[core]
	pager = delta

[interactive]
	diffFilter = delta --color-only

[delta]
	line-buffer-size = 256
	line-numbers = true
	syntax-theme = OneHalfLight
	tabs = 4

[merge]
	conflictstyle = diff3

[diff]
	colorMoved = default
END
	fi

	reflect_file "git" "gitconfig" "$HOME/.gitconfig"
	reflect_file "delta" "gitconfig" "$HOME/.gitconfig"
}

function install_bat {
	# Use musl version to avoid libc mess
	sudo wget -O bat-musl.deb "$("$SCRIPT_DIR/bin/github-get-release" -1 sharkdp/bat 'bat-musl_.*_amd64.deb')"
	sudo dpkg -i bat-musl.deb
	sudo rm -f bat-musl.deb

	deploy_file "bat" "config" "$HOME/.config/bat/config"
}

function install_moar {
	sudo wget -O /usr/local/bin/moar "$("$SCRIPT_DIR/bin/github-get-release" -1 walles/moar 'moar-.*-linux-386')"
	sudo chmod +x /usr/local/bin/moar
}

function install_tmux {
	# TMUX configuration for myself, depends on bash_conf to auto-start
	sudo apt-get update
	sudo apt-get install -y tmux xsel xclip

	deploy_file "tmux" ".tmux.conf" "$HOME/.tmux.conf"
	deploy_file "tmux" ".tmux.conf.local" "$HOME/.tmux.conf.local"
}

function install_xonsh {
	# Not used, but maybe one day...
	sudo apt-get update
	sudo apt-get install -y xonsh

	deploy_file "xonsh" ".xonshrc" "$HOME/.xonshrc"
}

function install_bash_conf {
	# Mostly visual changes, but also auto-starts TMUX on SSH and tweak rg behavior
	if sudo test ! -e "$HOME/.bashrc"; then
		sudo mkdir -vp "$HOME"
		sudo touch "$HOME/.bashrc"
		sudo chown -R "$USER:$USER" "$HOME/.bashrc"
	fi

	if ! sudo grep -Fq 'if [ -f ~/.bashrc_jz ]; then' "$HOME/.bashrc"; then
		cat << 'END' >> "$HOME/.bashrc"
if [ -f ~/.bashrc_jz ]; then
	. ~/.bashrc_jz
fi
END
	fi

	# generate from template
	copy_path "$SCRIPT_DIR/install/bash/.bashrc_jz.tmpl" "$SCRIPT_DIR/install/bash/.bashrc_jz" 1 1
	sed -i "s@{{buruaka}}@$SCRIPT_DIR@g" "$SCRIPT_DIR/install/bash/.bashrc_jz"

	deploy_file "bash" ".bashrc_jz" "$HOME/.bashrc_jz"
}

function install_gdb_conf {
	# For full-VM kernel debugging in QEMU KVM
	# This depends on grub_conf (nokaslr) to work properly
	# It also needs to modify virsh xml:
	# <domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
	#   <qemu:commandline>
	#     <qemu:arg value='-s'/>
	#   </qemu:commandline>
	#   ...
	# </domain>
	# For some kernel versions, this patch also needs to be backported
	# https://lore.kernel.org/lkml/20230607221337.2781730-1-florian.fainelli@broadcom.com/T/
	sudo apt-get update
	sudo apt-get install -y gdb

	deploy_file "gdb" ".gdbinit" "$HOME/.gdbinit"

	wget -O "$HOME/.gdb-dashboard" https://git.io/.gdbinit
	pip3 install pygments
}

function install_grub_conf {
	# Update grub to:
	#   Allow kernel selection
	#   Remember last selected entry
	#   Disable KASLR (for KGDB)
	TS=$(date '+%F-%s')

	if sudo test ! -e "/etc/default/grub"; then
		sudo mkdir -vp "/etc/default/"
		sudo touch "/etc/default/grub"
	fi

	if sudo test -e "/etc/default/grub"; then
		move_path "/etc/default/grub" "/etc/default/grub.bak.$TS" 1 1
	fi

	if sudo test -f "/etc/grub.d/10_linux"; then
		copy_path "/etc/grub.d/10_linux" "$SCRIPT_DIR/reflect/grub/10_linux.bak.$TS" 1 1
		sudo patch -l /etc/grub.d/10_linux "$SCRIPT_DIR/install/grub/10_linux.patch"
	fi

	copy_path "$SCRIPT_DIR/install/grub/grub.default" "/etc/default/grub" 1 1
	reflect_file "grub" "grub_default" "/etc/default/grub"
	sudo update-grub
}

function install_ssh_conf {
	# Add unsafe key pair to system and import trusted keys from github
	# Need to enter private key manually

	if sudo test ! -e "$HOME/.ssh/config"; then
		sudo mkdir -vp "$HOME/.ssh"
		sudo touch "$HOME/.ssh/config"
	fi

	sudo chown -R "$USER:$USER" "$HOME/.ssh/"

	if ! sudo grep -Fq "Host github.deanon" "$HOME/.ssh/config"; then
		cat << 'END' >> "$HOME/.ssh/config"
Host github.deanon
	HostName github.com
	User git
	IdentityFile ~/.ssh/id_ed25519_unsafe
END
	fi

	if sudo test ! -e "$HOME/.ssh/id_ed25519_unsafe"; then
		deploy_file "ssh" "id_ed25519_unsafe.pub" "$HOME/.ssh/id_ed25519_unsafe.pub"
		echo "Please provide the private key" | tee "$HOME/.ssh/id_ed25519_unsafe"
		nano "$HOME/.ssh/id_ed25519_unsafe"
	fi

	chmod 600 "$HOME/.ssh/"*

	pip3 install ssh-import-id
	ssh-import-id gh:jiyuzh

	# Now we can use ssh auth for buruaka repo
	"$SCRIPT_DIR/bin/extra/fixup-buruaka"
}

function install_kcompile {
	pushd "$SCRIPT_DIR/bin/"
	if sudo test ! -e "$SCRIPT_DIR/bin/kernel-compile"; then
		git clone https://github.com/jiyuzh/kernel-compile.git
	fi

	pushd "$SCRIPT_DIR/bin/kernel-compile/"
	git pull
	popd
	popd
}

help_mode=0
help_at=""

avail_install=($(declare -F | "$SCRIPT_DIR/bin/regex" 'install_(\w+)$' '$1\n'))

for var in "$@"; do
	help_mode=1

	for i in "${avail_install[@]}"; do
		if [ "$i" == "$var" ]; then
			help_mode=0
		fi
	done

	if [ "$help_mode" -eq 1 ]; then
		help_at="$help_at $var"
	fi
done

if [ "$#" -le 0 ] || [ ! -z "$help_at" ]; then

	if [ "$#" -le 0 ]; then
		echo "No install target found"
	else
		echo "Uncognized install target found:$help_at"
	fi
	echo

	echo "The following install targets are available:"
	for i in "${avail_install[@]}"; do
		echo "    $i"
	done

	exit 1

fi

echo "The following targets will be installed:"
for var in "$@"; do
	echo "    $var"
done
echo

do_confirm goahead "Perform install?"
echo
if [ "$goahead" -ne "1" ]; then
	echo "Goodbye"
	exit 1
fi

sudo -v

for var in "$@"; do
	echo
	echo "--------------------------------------------------------"
	echo
	echo "Installing $var"
	echo
	echo "--------------------------------------------------------"
	echo
	eval "install_$var"
done

echo
echo "--------------------------------------------------------"
echo
echo "All operations have finished successfully"
