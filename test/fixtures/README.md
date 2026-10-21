# Fixtures

Captured on an Apple Silicon MacBook (macOS 26, 24 GiB RAM):

- `top.txt`: `top -l 2 -n 0 -s 1`
- `vm_stat.txt`: `vm_stat`
- `netstat-en0.txt`: `netstat -ibn -I en0`, twice, 1 s apart
- `pmset-charging.txt`: `pmset -g batt`

Written by hand in the same format, for states the Mac was not in at capture time:

- `pmset-discharging.txt`, `pmset-no-estimate.txt`, `pmset-charged.txt`, `pmset-not-charging.txt`, `pmset-low.txt`, `pmset-desktop.txt`
- `netstat-utun.txt`: a VPN tunnel row with no link address. The column layout was checked against a real `netstat -ibn -I utun0`; the byte counts are made up.
