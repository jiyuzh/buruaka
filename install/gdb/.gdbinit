directory ~
source ~/.gdb-dashboard

define kerndbg
	lx-symbols
	target remote localhost:1234
end
document kerndbg
	Attach to QEMU at port 1234 and automatically load symbols
end
