#!/bin/bash
# Helper functions to make building easier

# Regex for matching files that should go into development packages
DOC_FILES=".*/man/.*|.*/info/.*|.*/share/.*doc/.*"
DEV_FILES=".*\.h|.*\.a|.*\.la|.*/pkgconfig/.*|.*/bin/.*-config|.*/share/aclocal/.*\.m4"
# Regex for matching LOCALE files
LOCALE_FILES=".*/share/locale/.*"

# Builds a .ipk
build_package() {
    TMPIPKG=/tmp/ipkg.tmpbuild.$$
    PKG_NAME="$1"
    PKG_VERSION="$2"
    PKG_DIR="$3"
    pushd $PKG_DIR
    if [ -z "$4" ] ; then
        PKG_FILES=`echo *`
    else
        PKG_FILES=`find . -regextype posix-extended -regex "$4"`
    fi
    if [ -z "$PKG_FILES"  -o "$PKG_FILES" == "*" ] ; then
        echo "Skipping creation of $PKG_NAME - no files"
        return
    fi
    #echo PKG_NAME=${PKG_NAME} pkg_files= ${PKG_FILES}
    mkdir $TMPIPKG
    tar cfz $TMPIPKG/data.tar.gz ${PKG_FILES}
    rm -rf ${PKG_FILES}
    find . -depth -type d -empty ! -name "." -exec rmdir {} \;
    popd
    pushd $STAGING ; tar xfz $TMPIPKG/data.tar.gz ; popd
    pushd $TMPIPKG
    cat > control << EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Architecture: $ARCH
Arch: $ARCH
EOF
    tar cfz control.tar.gz control
    rm control
    echo 2.0 > debian-binary
    ar crs "${PACKAGE_DIR}/${PKG_NAME}_${PKG_VERSION}_${ARCH}.ipk" debian-binary data.tar.gz control.tar.gz
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
        LDFLAGS=$LDFLAGS CFLAGS=$CFLAGS ./autogen.sh --host=$HOST --prefix=/ $CONFIGURE_PARAMS
    fi

    LDFLAGS=$LDFLAGS CFLAGS=$CFLAGS ./configure --host=$HOST --prefix=/ $CONFIGURE_PARAMS
}

do_make() {
    make -j4
}

do_install() {
    if type pre_install > /dev/null 2>&1 ; then
        pre_install "$1"
    fi
    make install DESTDIR=$1 $INSTALL_PARAMS

    if type post_install > /dev/null 2>&1 ; then
        post_install "$1"
    fi
}

# Performs a standard configure, make, make install build
do_build_install() {
    download_unpack "$SOURCE" "$FILENAME" "$FORCE_DIRNAME"
    do_configure
    do_make
    do_install "$1"
}

# Builds a package, and puts all of its installation into
# a single archive
do_simple() {
    do_build_install "$1"

    build_package ${NAME} ${VERSION} "$1"
}

build_generic_package() {
    build_package "${NAME}"-doc "${VERSION}" "$1" "${DOC_FILES}"
    build_package "${NAME}"-dev "${VERSION}" "$1" "${DEV_FILES}"
    build_package "${NAME}"-locale "${VERSION}" "$1" "${LOCALE_FILES}"
    build_package "${NAME}" "${VERSION}" "$1"
}

# Builds a package using the standard ./configure, make, make install
# and then packages it up into 4 archives:
# doc, dev, locale & what ever is left.
do_generic() {
    do_build_install "$1"
    build_generic_package "$1"
}


