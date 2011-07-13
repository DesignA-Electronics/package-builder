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
    # We used to remove empty directories, 
    # but I don't think we really want to do that anymore
    # find . -depth -type d -empty ! -name "." -exec rmdir {} \;
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

download() {
    SOURCE="$1"
    FILENAME=$2
    if [ -z "$FILENAME" ] ; then
        FILENAME=`basename "$SOURCE"`
    fi

    # If the file is already in the cache, then copy it from there
    # If it isn't in the cache, but is in the current directory,
    # then just unpack it from there
    # Finally, if it is in neither place, then download it
    if [ -n "${DOWNLOAD_CACHE_DIR}" -a \
         -f "${DOWNLOAD_CACHE_DIR}/${FILENAME}" ] ; then
        echo "File ${FILENAME} exists in ${DOWNLOAD_CACHE_DIR} - copying from there"
        cp "${DOWNLOAD_CACHE_DIR}/${FILENAME}" "${FILENAME}"
    elif [ -f $FILENAME ] ; then
        echo "Skipping download of ${FILENAME} - already present"
    else
        wget --no-check-certificate "$SOURCE" -O ${FILENAME}
        if [ -n "${DOWNLOAD_CACHE_DIR} " ] ; then
            cp "${FILENAME}" "${DOWNLOAD_CACHE_DIR}"
        fi
    fi
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
    elif [ ${FILENAME%.tgz} != ${FILENAME} ] ; then
        EXTRACT="tar xfz"
        DIRNAME=${FILENAME%.tgz}
    elif [ ${FILENAME%.tar.bz2} != ${FILENAME} ] ; then
        EXTRACT="tar xfj"
        DIRNAME=${FILENAME%.tar.bz2}
    elif [ ${FILENAME%.zip} != ${FILENAME} ] ; then
        EXTRACT="unzip"
        DIRNAME=${FILENAME%.zip}
    elif [ ${FILENAME%.tar.xz} != ${FILENAME} ] ; then
        EXTRACT="tar xfJ"
        DIRNAME=${FILENAME%.tar.xz}
    else
        echo "Unknown extraction name: $FILENAME"
        exit 1
    fi

    if [ -n "$3" ] ; then
        DIRNAME=$3
    fi

    download "$SOURCE" "$FILENAME"

    if [ ! -d ${DIRNAME} ] ; then
        ${EXTRACT} ${FILENAME}
        pushd ${DIRNAME}
        # If we define 'post_unpack', then run it
        if type post_unpack >/dev/null 2>&1 ; then
            post_unpack
        fi
    else
        pushd ${DIRNAME}
    fi

}

do_configure() {
    export PKG_CONFIG_PATH=${STAGING}/lib/pkgconfig

    if [ ! -f configure ] ; then
        LDFLAGS=$LDFLAGS CFLAGS=$CFLAGS ./autogen.sh --host=$HOST --prefix=/ $CONFIGURE_PARAMS
    fi

    LDFLAGS=$LDFLAGS CFLAGS=$CFLAGS ./configure --host=$HOST --prefix=/ $CONFIGURE_PARAMS
    if type post_configure > /dev/null 2>&1 ; then
        post_configure
    fi
}

do_make() {
    make -j4 $MAKE_PARAMS

    if type post_make > /dev/null 2>&1 ; then
        post_make
    fi
}

# Sometimes the .la files contain the /tmp directory for various paths.
# Adjust them to point to the staging directory instead
# They can also end up pointing to /lib (or //lib), which is no 
# good for the cross compile. 
# Similar issues happen with pkg-config files
fix_install_paths() {
    find "$1" -name "*.la" -exec sed -i "s#${1}#${STAGING}#g" {} \;
    find "$1" -name "*.la" -exec sed -i "s#\([' ]\)//*lib#\1${STAGING}/lib#g" {} \;
    find "$1" -iname "*.pc" -exec sed -i "s#${1}#${STAGING}#g" {} \;
    find "$1" -iname "*.pc" -exec sed -i "s#prefix=/\$#prefix=${STAGING}#g" {} \;
}

#
do_install() {
    if type pre_install > /dev/null 2>&1 ; then
        pre_install "$1"
    fi
    make install DESTDIR=$1 $INSTALL_PARAMS

    fix_install_paths "$1"

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

# Builds a bunch of standard packages based on file wildcards
# -dev, -doc, -locale & whatever is left
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


