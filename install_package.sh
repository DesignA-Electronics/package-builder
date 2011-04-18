#!/bin/bash
#
# Usage: install_package.sh PACKAGE1 [PACKAGE2 PACKAGE3...] DEST

set -e

if [ -z "$*" ] ; then
    echo "Usage: $0 <ipkg files...> <destination directory>"
    exit 1
fi

PACKAGE_COUNT=$(( ${BASH_ARGC} - 1 ))
DEST=${BASH_ARGV[${PACAKGE_COUNT}]}
if [ ! -d "$DEST" ] ; then
    echo "$DEST is not a directory"
    exit 1
fi

while [ ${PACKAGE_COUNT} -gt 0 ] ; do
    FILE=$1
    ar p "${FILE}" data.tar.gz | (cd "$DEST" ; tar xmz)
    shift
    PACKAGE_COUNT=$(( ${PACKAGE_COUNT} - 1 ))
done


