#!/bin/bash
# Сборка Retro80 в контейнере: исходники в /src (только чтение), результат в /work/build
set -e

. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh

cmake -S /src -B /work/build -G Ninja -DCMAKE_BUILD_TYPE=Debug
ninja -C /work/build
