PID namespace creation by unshare https://qiita.com/Ewokkkkk/items/f2fc09d09584bcb135da

```
$ sudo unshare --pid --mount-proc --fork /bin/bash
```

- `--pid`: isolate PID namespace
- `--mount-proc`: mount `/proc`, without this option it will output the information of **parent** PID namespace.
- `--fork`: forking