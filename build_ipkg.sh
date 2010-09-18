#!/bin/bash
# This is a standalone script suitable for use in external projects.
# It is designed to build a .ipk file from 
# It accepts input on stdin in the following format:
# <local file name> <destination location>
# ie:
# ../app/obj/arm/app /usr/local/bin/
#
# If the destination is a directory, make sure it has a trailing /
# If the destination is a directory, then the source can be a wildcard
# ie:
# ../app/docs/*.html /usr/share/doc/app/

set -e

PACKAGE=$1
VERSION=$2
ARCH=$3

if [ -z "$PACKAGE" -o -z "$VERSION" -o -z "$ARCH" ] ; then
    echo "Usage: $0 <package name> <version> <architecture>"
    exit 1
fi
OUTPUT=${PWD}/${PACKAGE}_${VERSION}_${ARCH}.ipk

STAGING=/tmp/`basename $0`.$$
PKGDIR=/tmp/`basename $0`.pkg.$$

mkdir $STAGING

while read source dest ; do
    if [ ${dest: -1} == "/" ] ; then
        dir=${dest}
    else
        dir=$(dirname ${dest})
    fi
    mkdir -p "${STAGING}/${dir}"
    cp -a ${source} "${STAGING}/${dir}"

    # Remove .svn directories that have been copied over
    find ${STAGING}/${dir} -name "*\.svn" | xargs -r rm -Rf 
done

# Create the data archive
cd ${STAGING} 
mkdir ${PKGDIR}
# Should be finding & deleting .svn directories
find . -depth -type d -name ".svn" -exec rm -rf {} \;
tar cfz ${PKGDIR}/data.tar.gz *
cd /
rm -rf "${STAGING}"

# Create the control files & ar it up
cd ${PKGDIR}
cat > control << EOF
Package: ${PACKAGE}
Version: ${VERSION}
Architecture: ${ARCH}
EOF
tar cfz control.tar.gz control
rm control
echo 2.0 > debian-binary
ar crs ${OUTPUT} debian-binary data.tar.gz control.tar.gz
cd /

rm -rf ${PKGDIR}

