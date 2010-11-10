#!/bin/sh
#
# Usage: install_package.sh PACKAGE DEST

FILE=$1
DEST=$2

if [ -z "$FILE" -o -z "$DEST" ] ; then
    echo "Usage: $0 <ipkg file> <destination directory>"
    exit 1
fi

ar p "${FILE}" data.tar.gz | (cd "$DEST" ; tar xmz)
