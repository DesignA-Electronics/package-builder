#!/bin/sh

if [ -z "$*" ] ; then
    echo "Usage: $0 [file.ipk ...]"
    exit 1
fi

for f in $* ; do
    ar p $f data.tar.gz | tar tvz
done
