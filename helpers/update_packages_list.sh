#!/bin/bash
# Generates the Packages list - run this after building any new packages

set -e
OUTPUT=packages/Packages

rm -f $OUTPUT

echo -n "Updating $OUTPUT: "
for f in packages/*.ipk ; do
    echo -n "."
    ar p $f control.tar.gz | tar xzO control >> $OUTPUT
    echo "Filename: `basename $f`" >> $OUTPUT
    echo "MD5Sum: `md5sum $f | cut -d' ' -f 1`" >> $OUTPUT
    echo "SHA1: `sha1sum $f | cut -d' ' -f 1`" >> $OUTPUT
    echo "Size: `wc -c $f | cut -d' ' -f 1`" >> $OUTPUT
    echo >> $OUTPUT
done

gzip -c $OUTPUT > packages/Packages.gz
echo
