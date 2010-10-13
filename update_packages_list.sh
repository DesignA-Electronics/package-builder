#!/bin/bash
# Generates the Packages list - run this after building any new packages

set -e 
OUTPUT=packages/Packages

rm -f $OUTPUT

echo "Updating $OUTPUT: "
for f in packages/*.ipk ; do
    echo -n "."
    ar p $f control.tar.gz | tar xzO control >> $OUTPUT
    echo "Filename: `basename $f`" >> $OUTPUT
    echo >> $OUTPUT
done

gzip -c $OUTPUT > packages/Packages.gz
echo
