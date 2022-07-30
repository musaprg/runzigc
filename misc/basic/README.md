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