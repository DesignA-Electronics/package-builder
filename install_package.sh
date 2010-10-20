#!/bin/sh
#
# Usage: install_package.sh PACKAGE DEST

FILE=$1
DEST=$2

ar p ${FILE} data.tar.gz | (cd $DEST ; tar xmz)
