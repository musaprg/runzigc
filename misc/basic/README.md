## PID namespace

PID namespace creation by unshare https://qiita.com/Ewokkkkk/items/f2fc09d09584bcb135da

```
$ sudo unshare --pid --mount-proc --fork /bin/bash
```

- `--pid`: isolate PID namespace
- `--mount-proc`: mount `/proc`, without this option it will output the information of **parent** PID namespace.
- `--fork`: forking

## UTS (Unix Time-Sharing) namespace (hostname isolation)

btw what is UTS?

> It means the process has a separate copy of the hostname and the (now mostly unused) NIS domain name, so it can set it to something else without affecting the rest of the system.  
>The hostname is set via sethostname and is the nodename member of the struct returned by uname. The NIS domain name is set by setdomainname and is the domainname member of the struct returned by uname.
https://unix.stackexchange.com/questions/183717/whats-a-uts-namespace

```
$ sudo unshare -u /bin/bash
```

- `-u`: isolate UTS Namespace

## capability
without any capability option

```
$ /home/mssn/.linuxbrew/bin/zig run namespace.zig
parent pid: 678
child pid: 745
uid: 65534
gid: 65534
$ getpcap 745
/bin/sh: 1: getpcap: not found
$ getpcaps 745
745: =
$ getpcaps 678
678: =
$ cat /proc/678/status | grep Cap
CapInh: 0000000000000000
CapPrm: 0000000000000000
CapEff: 0000000000000000
CapBnd: 0000003fffffffff
CapAmb: 0000000000000000
$ cat /proc/745/status | grep Cap
CapInh: 0000000000000000
CapPrm: 0000000000000000
CapEff: 0000000000000000
CapBnd: 0000003fffffffff
CapAmb: 0000000000000000
$ capsh --decode=0000003fffffffff
0x0000003fffffffff=cap_chown,cap_dac_override,cap_dac_read_search,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_linux_immutable,cap_net_bind_service,cap_net_broadcast,cap_net_admin,cap_net_raw,cap_ipc_lock,cap_ipc_owner,cap_sys_module,cap_sys_rawio,cap_sys_chroot,cap_sys_ptrace,cap_sys_pacct,cap_sys_admin,cap_sys_boot,cap_sys_nice,cap_sys_resource,cap_sys_time,cap_sys_tty_config,cap_mknod,cap_lease,cap_audit_write,cap_audit_control,cap_setfcap,cap_mac_override,cap_mac_admin,cap_syslog,cap_wake_alarm,cap_block_suspend,cap_audit_read
```

cap_setuid and cap_setgid exists by default.