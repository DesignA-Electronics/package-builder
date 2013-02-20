#!/bin/bash
# Helper functions to make building easier

# Regex for matching files that should go into development packages
DOC_FILES=".*/man/.*|.*/info/.*|.*/share/.*doc/.*|.*/docs/.*"
DEV_FILES=".*\.h|.*\.a|.*\.la|.*/pkgconfig/.*|.*/bin/.*-config|.*/share/aclocal/.*\.m4|.*/include/.*\.x|.*/include/.*\.hpp"
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
    if [ -n "$DESCRIPTION" ] ; then
        echo "Description: $DESCRIPTION" >> control
    fi
    tar cfz control.tar.gz control
    rm control
    echo 2.0 > debian-binary
    ar crs "${PACKAGE_DIR}/${PKG_NAME}_${PKG_VERSION}_${PACKAGE_ARCH}.ipk" debian-binary data.tar.gz control.tar.gz
    popd
    rm -rf $TMPIPKG
}

git_download() {
    SOURCE=$1
    FILENAME=`basename $SOURCE`
    DIRNAME=${FILENAME%%.git}

    if [ ! -d "${DIRNAME}" ] ; then
        git clone $SOURCE
    fi

    pushd ${DIRNAME}
    git pull
}

download() {
    SOURCE="$1"
    FILENAME="$2"
    if [ -z "$FILENAME" ] ; then
        FILENAME=`basename "$SOURCE"`
    fi

    # If the file is already in the cache, then copy it from there
    # If it isn't in the cache, but is in the current directory,
    # then just unpack it from there
    # Finally, if it is in neither place, then download it
    if [ -n "${DOWNLOAD_CACHE_DIR}" -a ! -d "${DOWNLOAD_CACHE_DIR}" ] ; then
        echo "Download cache dir ${DOWNLOAD_CACHE_DIR} doesn't exist - not using it" 2>&1
    fi
    if [ -n "${DOWNLOAD_CACHE_DIR}" -a \
         -f "${DOWNLOAD_CACHE_DIR}/${FILENAME}" -a \
         ! -f "${FILENAME}" ] ; then
        echo "File ${FILENAME} exists in ${DOWNLOAD_CACHE_DIR} - copying from there"
        cp "${DOWNLOAD_CACHE_DIR}/${FILENAME}" "${FILENAME}"
    elif [ -f "$FILENAME" ] ; then
        echo "Skipping download of ${FILENAME} - already present"
    else
        wget --no-check-certificate "$SOURCE" -O ${FILENAME}
        if [ -n "${DOWNLOAD_CACHE_DIR}" -a -d "${DOWNLOAD_CACHE_DIR}" ] ; then
            cp "${FILENAME}" "${DOWNLOAD_CACHE_DIR}"
        fi
    fi
}

unpack() {
    FILENAME="$1"
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
    elif [ ${FILENAME%.tar.lzma} != ${FILENAME} ] ; then
        EXTRACT="tar xfJ"
        DIRNAME=${FILENAME%.tar.lzma}
    else
        echo "Unknown extraction name: $FILENAME"
        exit 1
    fi

    if [ -n "$2" ] ; then
        DIRNAME="$2"
    fi

    if [ -d "${DIRNAME}" ] ; then
        echo "Skipping unpack - ${DIRNAME} already exists"
    else
        ${EXTRACT} ${FILENAME}
        pushd ${DIRNAME}
        # If we define 'post_unpack', then run it
        if type post_unpack >/dev/null 2>&1 ; then
            post_unpack
        fi
        popd
    fi
}

download_unpack() {
    SOURCE="$1"
    FILENAME="$2"
    DIRNAME="$3"

    if [ -z "$FILENAME" ] ; then
        FILENAME=`basename "$SOURCE"`
    fi

    download "$SOURCE" "$FILENAME"
    unpack "$FILENAME" "$DIRNAME"

    pushd ${DIRNAME}
}

# Downloads and unpacks the debian pakage source
download_unpack_debian() {
    NAME=$1
    VERSION=$2
    EXTENSION=$3

    DIR=${NAME:0:1}
    if [ "${NAME:0:3}" = "lib" ] ; then
        DIR=${NAME:0:4}
    fi

    BASE="http://ftp.de.debian.org/debian/pool/main/${DIR}/${NAME}"

    if [ -n "$4" ] ; then
        PATCH=$4
        PATCH_FILENAME=${NAME}_${VERSION}-${PATCH}.debian.${EXTENSION}
        PATCH_SOURCE=${BASE}/${PATCH_FILENAME}
        download "$PATCH_SOURCE" "$PATCH_FILENAME"
    fi

    FILENAME=${NAME}_${VERSION}.orig.${EXTENSION}
    SOURCE=${BASE}/${FILENAME}
    DIRNAME=${NAME}-${VERSION}

    download_unpack "$SOURCE" "$FILENAME" "$DIRNAME"

    if [ -n "$4" ] ; then
        unpack ../${PATCH_FILENAME} "debian"

        # Apply any patches
        if [ -d "debian/patches" -a -f "debian/patches/series" ] ; then
            for patch in `cat debian/patches/series` ; do
                patch -p1 < debian/patches/$patch
            done
        fi
    fi
}

do_configure() {
    export PKG_CONFIG_PATH=${STAGING}/lib/pkgconfig

    if [ -z "$CONFIGURE_SCRIPT" ] ; then
        CONFIGURE_SCRIPT=./configure
    fi

    # Some config.sub files don't understand the -linux-uclibcgnueabi os 
    # option, so fix them to think of it the same way as -linux-gnueabi
    if [ "$FIX_CONFIG_SUB" == "1" ] ; then
        if [ -f config.sub ] ; then
            file=config.sub
        else
            file=*/config.sub
        fi
        if [ -z "$file" ] ; then
            echo "Cannot find config.sub file"
            exit 1
        fi
        echo "Fixing linux-uclibcgnu* option in $file"
        sed -i 's/ linux-gnu\*/ linux-uclibcgnu\* | linux-gnu\*/g' $file
        sed -i 's/ -linux-gnu\*/ -linux-uclibcgnu\* | -linux-gnu\*/g' $file
    fi

    if [ ! -f $CONFIGURE_SCRIPT ] ; then
        LDFLAGS=$LDFLAGS CFLAGS=$CFLAGS sh autogen.sh --host=$HOST --prefix=/ $CONFIGURE_PARAMS
    fi

    LDFLAGS=$LDFLAGS CFLAGS=$CFLAGS $CONFIGURE_SCRIPT --host=$HOST --prefix=/ $CONFIGURE_PARAMS
    if type post_configure > /dev/null 2>&1 ; then
        post_configure
    fi
}

do_make() {
    if [ -z "$J" -a -f /proc/cpuinfo ] ; then
        J=`grep -c "^processor" /proc/cpuinfo`
    fi
    make -j$J $MAKE_PARAMS

    if type post_make > /dev/null 2>&1 ; then
        post_make
    fi
}

# Sometimes the .la files contain the /tmp directory for various paths.
# Adjust them to point to the staging directory instead
# They can also end up pointing to /lib (or //lib), which is no 
# good for the cross compile. 
# Similar issues happen with pkg-config files
# Also, pre pkg-config packages which have their own bin/*-config
# script need some adjustment
fix_install_paths() {
    find "$1" -name "*.la" -exec sed -i "s#${1}#${STAGING}#g" {} \;
    find "$1" -name "*.la" -exec sed -i "s#\([' ]\)//*lib#\1${STAGING}/lib#g" {} \;
    find "$1" -name "*.pc" -exec sed -i "s#${1}#${STAGING}#g" {} \;
    find "$1" -name "*.pc" -exec sed -i "s#prefix=/\$#prefix=${STAGING}#g" {} \;
    find "$1" -path "*/bin/*-config" -exec sed -i "s#^prefix=/\$#prefix=${STAGING}#g" {} \;
    find "$1" -path "*/bin/*-config" -exec sed -i "s#^prefix=\"/\"\$#prefix=${STAGING}#g" {} \;
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

# Build using CMake
do_cmake() {
	mkdir -p build
	pushd build

	cmake -DCMAKE_INSTALL_PREFIX='/' \
	      -DCMAKE_TOOLCHAIN_FILE=${PACKAGE_BUILDER_BASE}/package_builder.cmake \
	      ..
	make
	make install DESTDIR="$1"

	popd
}

# Build a package with the NetBSD make
do_pmake_build() {
    DIR="$1"
    if [ -n "$DIR" ] ; then
        pushd $DIR
    fi

    CFLAGS="-I${STAGING}/include"
    CC=${CROSS}gcc LD=${CROSS}ld CFLAGS=${CFLAGS} pmake

    if [ -n "$DIR" ] ; then
        popd
    fi
}

# Install using the NetBSD make
do_pmake_install() {
    DEST=$1
    DIR="$2"
    if [ -n "$DIR" ] ; then
        pushd $DIR
    fi

    for i in 1 2 3 4 5 6 7 8 9 ; do
        mkdir -p ${DEST}/usr/share/man/man$i/
    done

    GROUP=`id -gn`
    ARGS="DESTDIR=${DEST} LIBDIR=/lib INCSDIR=/include"
    ARGX="${ARGS} OBJECT_FMT=ELF"
    ARGS="${ARGS} BINOWN=${USER} BINGRP=${GROUP}"
    ARGS="${ARGS} MANOWN=${USER} MANGRP=${GROUP}"
    INSTALL="install -D" MACHINE_MULTIARCH="" pmake install ${ARGS}
    INSTALL="install -D" MACHINE_MULTIARCH="" pmake incinstall ${ARGS}

    # Attempt to remove empty directories
    for i in 1 2 3 4 5 6 7 8 9 ; do
        rmdir ${DEST}/usr/share/man/man$i/ > /dev/null 2>&1 || true
    done

    if [ -n "$DIR" ] ; then
        popd
    fi
}

# Build and install with the NetBSD make
do_pmake() {
    DESTDIR="$1"
    BASEDIR="$2"

    do_pmake_build "${BASEDIR}"
    do_pmake_install "${DESTDIR}" "${BASEDIR}"
}

# Builds a bunch of standard packages based on file wildcards
# -dev, -doc, -locale & whatever is left
build_generic_package() {
    build_package "${NAME}"-doc "${VERSION}" "$1" "${DOC_FILES}"
    build_package "${NAME}"-dev "${VERSION}" "$1" "${DEV_FILES}"
    build_package "${NAME}"-locale "${VERSION}" "$1" "${LOCALE_FILES}"
    build_package "${NAME}" "${VERSION}" "$1"
}

remove_cflags() {
    for remove in $* ; do
        CFLAGS=`echo $CFLAGS | sed "s#$remove##g"`
    done
}

# Builds a package using the standard ./configure, make, make install
# and then packages it up into 4 archives:
# doc, dev, locale & what ever is left.
do_generic() {
    do_build_install "$1"
    build_generic_package "$1"
}

executable_required() {
    for f in $* ; do
        if ! which "$f" > /dev/null ; then
            echo "Required executable '$f' is not available. Please install" >&2
            exit 1
        fi
    done
}
