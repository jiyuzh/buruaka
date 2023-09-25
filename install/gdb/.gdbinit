define kerndbg
	set auto-load safe-path /
	target remote localhost:1234
	source ./vmlinux-gdb.py
	lx-symbols
end
document kerndbg
	Attach to QEMU at port 1234 and automatically load symbols
end