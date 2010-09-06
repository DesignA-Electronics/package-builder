To build a package:
./update_package <package_name>

To add a new package:
Create a new file in the 'scripts' directory, with the name of the package.
This script should download, unpack, compile & install the package as apporiate, and call the 'build_package' helper macro to build its final package output


The following variables are used by the 'do_generic' function:
NAME - name of the package
VERSION - package version
SOURCE - downloadable location of the source
FORCE_DIRNAME - if the unpacked directory name is not the same as the filename (without suffix), then set this to the correct directory name
BUILD_LIBRARY - if set to 1, then a -dev version of the package will be built containing all the .a, .h & man pages
post_unpack - if this function is defined, it will be run after the archive is unpacked from within the source directory
post_install - if this function is defined, it will be run after the installation process to the temporary directory has completed. It will be passed the full directory path as its argument

