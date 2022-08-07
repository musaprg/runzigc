```
$ strace -f -o ./strace.txt unshare --pid --fork --mount-proc /bin/sh
# exit
```