#! /usr/bin/env bash

name=${1:-"OpenSans-Regular"}
size=${2:-96}
tx=${3:-0}
ty=${4:-8}

if [ ! -x "$(which msdfgen 2>/dev/null)" ]; then
    echo -e "This script requires 'msdfgen' to be in the \$PATH\n    - msdfgen can be found at 'https://github.com/Chlumsky/msdfgen'"
    exit
fi

echo -e "${name}_msdf\n96\n${size}\n" > ./res/font/${name}_msdfmetrics
for i in $(seq 32 127); do
    mkdir -p ./res/font/${name}_msdf/
    metrics="$(msdfgen -font ./res/font/${name}.ttf $i -o ./res/font/${name}_msdf/${i}.png -size $size $size -translate $tx $ty -printmetrics -pxrange 4)"

    if grep -q "bounds" <(echo -e "$metrics"); then
        sed -n 's/^bounds = \(.*\), \(.*\), \(.*\), \(.*\)$/\1 \2 \3 \4 /p' <(echo -e "$metrics") | tr -d '\n' | awk "{printf(\"%f %f %f %f \", \$1+$tx, \$2+$ty, \$3+$tx, \$4+$ty)}" >> ./res/font/${name}_msdfmetrics
    else
        echo -n '-1 -1 -1 -1 ' >> ./res/font/${name}_msdfmetrics
    fi
    sed -n "s/^advance = \(.*\)$/\1/p" <(echo -e "$metrics") >> ./res/font/${name}_msdfmetrics
done
