#!/bin/bash
# WasmCart: permutation-3 console. The shell is a SuperBox64Kit SKScene;
# carts run through WAMR into the same KitABI backend. Embedded Swift,
# static SDL3 (with the file dialog) + static WAMR, vendored from source.
#   HOST_NAME=WasmUp ./build.sh builds the reserved-name variant.
set -euo pipefail
cd "$(dirname "$0")"
./vendor.sh
KIT="${KIT:-$(cd ../SuperBox64Kit && pwd)}"
OUT_NAME="${HOST_NAME:-WasmCart}"

if [ ! -f vendor/natives.c ]; then
  echo "ERROR: vendor/natives.c not found. Generate it with: python3 gen-natives.py"
  exit 1
fi

clang -c -Os -DNDEBUG -ffunction-sections \
  -I vendor/wamr/core/iwasm/include -I "$KIT/Sources/KitABI/include" -I "$KIT/Sources/CZip/include" \
  vendor/natives.c -o vendor/natives.o

clang -c -Os -DNDEBUG -ffunction-sections \
  -I "$KIT/Sources/CZip/include" \
  "$KIT/Sources/CZip/src/zip.c" -o vendor/zip.o

GAME_SRC="$PWD/Sources" \
GAME_MAIN="$PWD/host-main.swift" \
OUT="$PWD/$OUT_NAME" \
SDL_STATIC_A="$PWD/vendor/libSDL3.a" \
EXTRA_OBJS="$PWD/vendor/natives.o $PWD/vendor/zip.o" \
EXTRA_LIBS="$PWD/vendor/libiwasm.a $PWD/vendor/libresvg.a -liconv -lz" \
KIT_STB_CFLAGS="-DKIT_USE_RESVG -I$PWD/vendor" \
EXTRA_XCC="-Xcc -I$PWD/vendor/wamr/core/iwasm/include -Xcc -fmodule-map-file=$KIT/Sources/CWamr/include/module.modulemap -I $KIT/Sources/CWamr/include -Xcc -fmodule-map-file=$KIT/Sources/CZip/include/module.modulemap -I $KIT/Sources/CZip/include" \
  "$KIT/native/build-native-game.sh"
