#!/bin/bash
# Helper functions to make building easier

##
# Builds a package split into two files, the -dev one contains everything
# that ends in .a, .h, .la or is a info/manpage
# The normal one contains everything else
##
build_lib_package() {
    TMPIPKG=/tmp/ipkg-lib.tmpbuild.$$
    mkdir $TMPIPKG
    pushd $3
    FILES=`find . \( -type f -o -type l \) -a \( -name "*.h" -o -name "*.a" -o -name "*.la" -o -wholename "*/man/*" -o -wholename "*/pkgconfig/*" -o -wholename "*/info/*" -o -wholename "*/bin/*-config" -o -wholename "*/share/aclocal/*.m4" \) `
    tar cfz $TMPIPKG/data.tar.gz ${FILES}
    pushd $STAGING ; tar xfz $TMPIPKG/data.tar.gz ; popd
    popd
    pushd $TMPIPKG
    cat > control << EOF
Package: $1-dev
Version: $2
Architecture: $ARCH
Arch: $ARCH
EOF
    tar cfz control.tar.gz control
    rm control
    echo 2.0 > debian-binary
    ar crs "${PACKAGE_DIR}/$1-dev_$2.ipk" debian-binary data.tar.gz control.tar.gz
    popd
    rm -rf $TMPIPKG
    pushd $3
    rm ${FILES}
    # Remove any empty directories,
    find . -depth -type d -empty -exec rmdir {} \;
    popd

    # Just go build the normal packages
    build_package $1 $2 $3
}

build_package() {
    TMPIPKG=/tmp/ipkg.tmpbuild.$$
    mkdir $TMPIPKG
    pushd $TMPIPKG
    pushd $3
    tar cfz $TMPIPKG/data.tar.gz .
    pushd $STAGING ; tar xfz $TMPIPKG/data.tar.gz ; popd
    popd
    cat > control << EOF
Package: $1
Version: $2
Architecture: $ARCH
Arch: $ARCH
EOF
    tar cfz control.tar.gz control
    rm control
    echo 2.0 > debian-binary
    ar crs "${PACKAGE_DIR}/$1_$2.ipk" debian-binary data.tar.gz control.tar.gz
    popd
    rm -rf $TMPIPKG
}

download_unpack() {
    SOURCE="$1"
    FILENAME=$2
    if [ -z "$FILENAME" ] ; then
        FILENAME=`basename "$SOURCE"`
    fi

    if [ ${FILENAME%.tar.gz} != ${FILENAME} ] ; then
        EXTRACT="tar xfz"
        DIRNAME=${FILENAME%.tar.gz}
    elif [ ${FILENAME%.tar.bz2} != ${FILENAME} ] ; then
        EXTRACT="tar xfj"
        DIRNAME=${FILENAME%.tar.bz2}
    elif [ ${FILENAME%.zip} != ${FILENAME} ] ; then
        EXTRACT="unzip"
        DIRNAME=${FILENAME%.zip}
    else
        echo "Unknown extraction name: $FILENAME"
        exit 1
    fi

    if [ -n "$3" ] ; then
        DIRNAME=$3
    fi

    if [ ! -f $FILENAME ] ; then
        wget "$SOURCE" -O ${FILENAME}
    fi
    if [ ! -d ${DIRNAME} ] ; then
        ${EXTRACT} ${FILENAME}
    fi
    pushd ${DIRNAME}

    # If we define 'post_unpack', then run it
    if type post_unpack >/dev/null 2>&1 ; then
        post_unpack
    fi
}

do_configure() {
    if [ ! -f configure ] ; then
        LDFLAGS=$LDFLAGS CFLAGS=$CFLAGS ./autogen.sh --host=$HOST $CONFIGURE_PARAMS
    fi

    LDFLAGS=$LDFLAGS CFLAGS=$CFLAGS ./configure --host=$HOST $CONFIGURE_PARAMS
}

do_make() {
    make -j4
}

do_install() {
    make install prefix=$1 $INSTALL_PARAMS

    if type post_install > /dev/null 2>&1 ; then
        post_install "$1"
    fi
}

do_generic() {
    download_unpack "$SOURCE" "$FILENAME" "$FORCE_DIRNAME"
    do_configure
    do_make
    do_install "$1"

    if [ "$BUILD_LIBRARY" == "1" ] ; then
        build_lib_package ${NAME} ${VERSION} "$1"
    else
        build_package ${NAME} ${VERSION} "$1"
    fi
}

