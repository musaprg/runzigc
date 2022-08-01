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

CapEffが0だからダメじゃんねこれ

cap_setuid and cap_setgid exists by default.

## troubleshooting

なぜかuid_mapにoperation not permittedとなって書き込めない。

> gid_mapについても同様ですが、 Linux 3.19 からプロセスの補助グループを設定する setgroups の権限と、gid_mapの設定権限が排他となったため、 setgroups が有効な場合には、先にそちらを無効にする必要があります。
プロセスに対する setgroups 権限は、同様に /proc ファイルシステム上のファイルを使い、確認/設定することができます。
https://tech.retrieva.jp/entry/2019/06/04/130134

マジ？

```
$ sudo /home/mssn/.linuxbrew/bin/zig run namespace.zig
parent pid: 10086
child pid: 10153
uid: 65534
gid: 65534
uid_map_path: /proc/10153/uid_map
gid_map_path: /proc/10153/gid_map
$ echo deny > /proc/10153/setgroups
/bin/sh: 1: cannot create /proc/10153/setgroups: Permission denied
$ echo deny >> /proc/10153/setgroups
/bin/sh: 2: cannot create /proc/10153/setgroups: Permission denied
```

あっ、そういうことかこれか

> また、User名前空間の中のプロセスが自身のuid_map/gid_mapに書き込むことはできず、かならず親User名前空間のプロセスから書き込む必要があります。
C++などで実装しているときには、 fork (2) 後に子プロセス、親プロセスそれぞれに制御が移るため実装は楽ですが、シェルスクリプトだと別のシェルを開いたり、バックグラウンドプロセスを作ってpidをやりとりする、などの工夫が必要になります。
https://tech.retrieva.jp/entry/2019/06/04/130134#%E3%81%84%E3%81%96%E5%AE%9F%E8%B7%B5-%E3%81%A8%E3%82%8A%E3%81%82%E3%81%88%E3%81%9Aroot%E3%81%AB%E3%81%AA%E3%81%A3%E3%81%A6%E3%81%BF%E3%82%8B

> 1.
>書き込みプロセスは、 プロセス pid のユーザー名前空間で CAP_SETUID (CAP_SETGID) ケーパビリティを持っていなければならない。
>2.
書き込みプロセスは、 プロセス pid のユーザー名前空間もしくはプロセス pid の親のユーザー名前空間に属していなければならない。
>3.
マッピングされたユーザー ID (グループ ID) は親のユーザー名前空間にマッピングを持っていなければならない。
>4.
以下のいずれか一つが真である。
>*
uid_map (gid_map) に書き込まれるデータは、 書き込みを行うプロセスの親のユーザー名前空間でのファイルシステムユーザー ID (グループ ID) をそのユーザー名前空間でのユーザー ID (グループ ID) にマッピングする 1 行で構成されている。
>*
オープンしたプロセスが親のユーザー名前空間で CAP_SETUID (CAP_SETGID) ケーパビリティを持っている。 したがって、 特権プロセスは親のユーザー名前空間の任意のユーザー ID (グループ ID) に対するマッピングを作成できる。
上記のルールを満たさない書き込みはエラー EPERM で失敗する。 
https://linuxjm.osdn.jp/html/LDP_man-pages/man7/user_namespaces.7.html

https://www.slideshare.net/AkihiroSuda/container-runtime-meetup-runc-user-namespaces

大前提→親プロセスはroot権限で動作する必要あり（rootlessにしないなら）

