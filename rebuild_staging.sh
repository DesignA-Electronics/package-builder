#!/bin/bash
# Rebuilds the staging directory be erasing the current one, and then 
# unpacking all of the currently built packages into a new one

set -e

rm -rf staging
mkdir staging

for f in packages/*.ipk ; do
    echo ${f}
    ar p ${f} data.tar.gz | (cd staging ; tar xfz -)
done

