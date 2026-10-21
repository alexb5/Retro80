#!/bin/bash
# Сборка Retro80 и быстрых тестов libkr580 в контейнере:
# исходники в /src (только чтение), результат в /work/build.
# Аргументы передаются ctest, например -L long для долгого 8080EXM
set -e

. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh

cmake -S /src -B /work/build -G Ninja -DCMAKE_BUILD_TYPE=Debug
ninja -C /work/build
[ $# -eq 0 ] && set -- -LE long
ctest --test-dir /work/build --output-on-failure "$@"
