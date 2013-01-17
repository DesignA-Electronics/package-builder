#!/bin/sh

rm -f Contents
rm -f tmp_Contents
echo -n "Adding packages"
for f in packages/*.ipk ; do
    name=`basename $f`
    ar p ${f} data.tar.gz | tar tz | awk "{print \$1 \"\t${name}\"}" >> tmp_Contents
    echo -n "."
done
echo
cat tmp_Contents | sed 's/^\.\///g' | sort -u > Contents
rm tmp_Contents
echo -n "Compressing to Contents.gz"
cat Contents | gzip -c > Contents.gz
echo

