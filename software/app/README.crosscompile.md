# How to cross-compile the test application

To cross-compile the test application you need to define the `CROSS_COMPILE` and `BITENV` variables when calling `make`.

For example, to cross-compile the application for the SLAC buildroot 2019 version, you should call make this way:

```bash
$ make \
    BITENV=64 \
    CROSS_COMPILE=/afs/slac/package/linuxRT/buildroot-2019.08/host/linux-x86_64/x86_64/usr/bin/x86_64-buildroot-linux-gnu- \
```

On the other hand, if you do not want to cross-compile the application, and build it for the host instead, you need to call `make` without defining any variable:

```bash
$ make
```