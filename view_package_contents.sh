#!/bin/sh

for f in $* ; do
    ar p $f data.tar.gz | tar tvz
done
