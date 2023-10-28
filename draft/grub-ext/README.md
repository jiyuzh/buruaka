1. Apply the patch to `/etc/grub.d/10_linux`
2. Add the following example to `/etc/default/grub`

```bash
# This is an unofficial extension to the grub
# This is a list of key-value pairs, one line per pair.
# Each pair element is:
#   Key: a PCRE to match GRUB boot entry header string (i.e. the menuentry line)
#   Value: a string for extra kernel options
# The pair follows "Key : Value" format, where the style of spacing in between (" : ") is mandatory
export GRUB_CMDLINE_LINUX_KERNEL='
	gnulinux-5\.\d+\.\d+-dft\+ : nokaslr
	gnulinux-5\.0\.21 : memmap=20G!132G memmap=20G!153G
'
```

