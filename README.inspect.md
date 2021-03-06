The inspect tool allows you to look inside the content store and see what's
going on.  It supports various subcommands to take multiple views of the
content store without having to worry about database schemas and the like.

Before you can use the inspect tool, you must first build it and then
import a bunch of RPMs to generate a metadata database (mddb) and content
store.  More complete instructions for how to do this are in the README.md
file in the top level of the bdcs source.

Like a lot of programs, the inspect tool uses subcommands with options to
figure out what to do.  Regardless of what subcommand you use, however, you
must pass it the location of the mddb and the content store as the first two
command line parameters.  Thus, all invocations of inspect start like this:

```
$ bdcs inspect metadata.db cs.repo
```

If you run it with no subcommands, you will get some brief output listing
available subcommands and what they do:

```
$ bdcs inspect metadata.db cs.repo
inspect fcc8987
Usage: inspect output.db repo subcommand [args ...]
- output.db is the path to a metadata database
- repo is the path to a content store repo
- subcommands:
      groups - List groups (packages, etc.)
      ls     - List files
      nevras - List NEVRAs of RPM packages
```

The groups and nevras commands are very similar.  If your content store holds
only RPMs (which is all that's supported right now anyway), their output will
almost identical.  The only difference will be that groups lists just the names
while nevras lists the full RPM filename information.  In the future, groups
could include things besides RPMs like Fedora modules, language-specific
packages, or all sorts of other things.

On a small test database containing just a few packages, the output looks like
this:

```
$ bdcs inspect metadata.db cs.repo groups
systemd
systemd-devel
systemd-libs
systemd-python

$ bdcs inspect metadata.db cs.repo nevras
systemd-219-30.el7.x86_64
systemd-devel-219-30.el7.x86_64
systemd-libs-219-30.el7.x86_64
systemd-python-219-30.el7.x86_64
```

Subcommands also typically take options that modify their behavior.  Options go
after the name of the subcommand.  If you pass an invalid option, you will get
help output showing what is supported.

Both groups and nevras take a -m option, which takes a regular expression as an
argument.  Only those group or nevra values that match the provided regular
expression will be output.  For example

```
$ bdcs inspect metadata.db cs.repo groups -m "devel$"
systemd-devel
```

There is also an ls subcommand.  If provided with no options, it simply lists
all files stored in the database.  This could be a very large number of files,
depending on how much you have imported.  Because the content store is capable
of storing several versions of the same file, it is possible for the same name
to be printed out several times.

```
$ bdcs inspect metadata.db cs.repo ls
/etc/X11/xorg.conf.d
/etc/X11/xorg.conf.d/00-keyboard.conf
/etc/binfmt.d
...
/var/log/btmp
/var/log/journal
/var/log/wtmp
/var/run/utmp
```

Just like the ls program, the ls subcommand also takes a -l option that prints
out information about each file:

```
$ bdcs inspect metadata.db cs.repo ls -l
drwxr-xr-x     root     root          0 Sep 13 2016 /etc/X11/xorg.conf.d
drwxr-xr-x     root     root          0 Sep 13 2016 /etc/binfmt.d
-rw-r--r--     root     root        947 Sep 13 2016 /etc/dbus-1/system.d/org.freedesktop.hostname1.conf
...
-rw-r--r--     root     root       5952 Sep 13 2016 /usr/share/zsh/site-functions/_udevadm
drwxr-xr-x     root     root          0 Sep 13 2016 /var/lib/systemd
drwxr-xr-x     root     root          0 Sep 13 2016 /var/lib/systemd/catalog
```

And just like the groups and nevras commands, it also takes a -m option:

```
$ bdcs inspect metadata.db cs.repo ls -m ".service$"
/usr/lib/systemd/system/autovt@.service
/usr/lib/systemd/system/console-getty.service
/usr/lib/systemd/system/console-shell.service
/usr/lib/systemd/system/container-getty@.service
...
```
