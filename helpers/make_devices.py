#!/usr/bin/env python
# Parses a device_table file and creates the appropriate device node from
# it.
# Note: This could be relatively trivially exploited, as it requires root
# permissions and essentially creates files with arbitrary permissions
# in arbitrary locations. Use with caution.

import sys
import stat
import os

class DeviceList:
    def __init__(self, filename):
        self.data = open(filename, "r").readlines()

    def makedevices(self, prefix):
        # If we're running under sudo, then reset directories to
        # be owned by the actual user, so that they can be
        # erased again
        if os.environ.has_key("SUDO_UID"):
            owner_uid = int(os.environ["SUDO_UID"])
        else:
            owner_uid = -1

        for l in self.data:
            if len(l.strip()) == 0:
                continue
            if l[0] == '#':
                continue
            s = l.split()
            name = s[0]
            fullname = prefix + os.sep + name
            devtype = s[1]

            try:
                basedir=os.path.dirname(fullname)
                os.mkdir(basedir)
                os.chown(basedir, owner_uid, -1)
            except OSError, e:
                pass

            if devtype == "d":
                os.mkdir(fullname)
                os.chown(fullname, owner_uid, -1)
            elif devtype == "l":
                src = s[2]
                os.symlink(src, fullname)
            elif devtype == "c" or devtype == "b":
                mode = int(s[2], 8)
                if devtype == "c":
                    mode |= stat.S_IFCHR
                else:
                    mode |= stat.S_IFBLK
                uid = int(s[3])
                gid = int(s[4])
                major = int(s[5])
                minor = int(s[6])
                if len(s) < 10 or s[9] == "-":
                    device = os.makedev(major, minor)
                    os.mknod(fullname, mode, device)
                    os.chown(fullname, uid, gid)
                else:
                    count = int(s[9])
                    start = int(s[7])
                    inc = int(s[8])
                    for i in range(start,start + count):
                        device = os.makedev(major, minor)
                        os.mknod(fullname + str(i), mode, device)
                        os.chown(fullname + str(i), uid, gid)
                        minor += inc
            elif devtype == "p":
                mode = int(s[2], 8)
                os.mkfifo(fullname, mode)
            else:
                raise SystemError, "Unhandled device type '%s' for %s" % (devtype, name)

            sys.stdout.write(".")
            sys.stdout.flush()


if __name__ == '__main__':
    d = DeviceList(sys.argv[1])
    d.makedevices(sys.argv[2])
