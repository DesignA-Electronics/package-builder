To build a package:
./pbuild build <package_name>
This is done as a normal user - builds don't require root access generally,
only the final assembly of the root filesystem requires this (as /dev
files & mknod require it)
If the package is already partially built, this will still run the configure,
make & make install processes

To add a new package:
Create a new file in the 'scripts' directory, with the name of the package.
This script should download, unpack, compile & install the package as
apporiate, and call the 'build_package' helper macro to build its final
package output.
Add the new package to the bottom of full_packages_list so that it will be
automatically built by the "pbuild build-all" script


The following variables are used by the 'do_generic' function:
NAME - name of the package
VERSION - package version
SOURCE - downloadable location of the source
FORCE_DIRNAME - if the unpacked directory name is not the same as the
                filename (without suffix), then set this to the correct
                directory name
The following functions can be defined within a script to give finer control
over the build process:
post_unpack - This will be run after the archive is unpacked from within the
              source directory
post_install - This will be run after the installation process to the
               temporary directory has completed. It will be passed the full
               directory path as its argument
pre_install - This will be run after the project has been 'make install'd.
              It will be passed the temporary installation directory as its
              only argument

Each script should follow the following general build process:
1. Download archive
2. Unpack archive to build/PACKAGENAME directory
3. Build software
4. Install software to temporary directory
5. Package temporary installation directory into one (or more) .ipk files
6. Install .ipk files into staging directory
7. Delete temporary installation directory

To go back to a complete clean setup, erase the following directories:
* build
* staging
* packages

To build a root fs, use the "pbuild build-rootfs" script.
Set STRIP_ROOTFS=1 if you want all of the binary files to be stripped of
debugging symbols in the output

By default "pbuild build-rootfs" assumes that a fully intact /dev filesystem
is desired, and as such uses 'sudo' to ensure that the device nodes
are created with the correct permissions. This is useful if the filesystem
is going to be used as an NFS root or similar, however if the resultant
filesystem is going to be packaged up in an image (such as a .tar, squashfs, 
cramfs etc...), then sudo may not be desired, and a system such as fakeroot
can be used. In this case, set SKIP_SUDO=1 prior to running pbuild, ie:

SKIP_SUDO=1 fakeroot -s rootfs.fakeroot ./pbuild build-rootfs packages_list rootfs
fakeroot -i rootfs.fakeroot mksquashfs rootfs rootfs.squashfs -noappend

This will create the rootfs.squashfs image without the need to ever have
permissions to use the sudo command, and as such is the preferred solution.

Configuration
=============
The 'config' file defines most of the settings that are used in package-builder. 
To make changes, the easiest thing to do is create a new file called 
'custom_config', which contains alternative settings. The following settings
are often edited:
CFLAGS - contains an optimisation flags desired
LDFLAGS
PACKAGE_ARCH - sets the name that will be placed in/on the .ipk files 
    designating which architecture these packages are for
TOOLCHAIN_DIR - the base directory containing the toolchain (should 
    contain bin/arm-none-linux-gnueabi-gcc or similar)
TOOLCHAIN_LIBC_DIR - the directory containing libc.so from the toolchain
SKIP_TOOLCHAIN_LIBS - if set to 'y', don't use the libc from the toolchain.
    This should be set if using an out-of-toolchain libc, like musl/uclibc.
USE_MUSL - set to 'y' if building MUSL (as musl needs to override gcc)
USE_TSLIB - set to 'y' if using tslib, so that other packages can be built
    appropriately
USE_STATIC - set to 'y' if attempting to build a predominantly statically
    linked system. Some packages can use loadable modules or static modules,
    and will look at this variable to determine how to be build
