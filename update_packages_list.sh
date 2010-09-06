#!/bin/bash
# Generates the Packages list - run this after building any new packages
IDX=/work/snapper/releases/latest/oe/build/tmp/staging/i686-linux/usr/bin/ipkg-make-index
IPKG_DIR=./packages

touch $IPKG_DIR/Packages
$IDX -r $IPKG_DIR/Packages -p $IPKG_DIR/Packages -l $IPKG_DIR/Packages.filelist -m $IPKG_DIR

for f in $IPKG_DIR/* ; do
    if [ -d "$f" ] ; then
    	echo "Building package list for $f"
        touch $f/Packages
        $IDX -r $f/Packages -p $f/Packages -l $f/Packages.filelist -m $f
    fi
done
