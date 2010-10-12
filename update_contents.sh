#!/bin/sh

rm Contents
for f in packages/*.ipk ; do
    name=`basename $f`
    ar p ${f} data.tar.gz | tar tz | awk "{print \$1 \"\t${name}\"}" >> Contents
done
sort -u Contents | gzip -c > Contents.gz

