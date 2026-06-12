#!/bin/bash
# WasmCart host build. Embedded Swift, static SDL3 + static WAMR, both
# vendored from source - no package managers, no dylibs.
#   HOST_NAME=WasmUp ./build.sh builds the reserved-name variant.
set -euo pipefail
cd "$(dirname "$0")"
./vendor.sh
KIT="${KIT:-$(cd ../SuperBox64Kit && pwd)}"
TC="$(dirname "$(dirname "$(TOOLCHAINS=${SWIFT_TOOLCHAIN:-org.swift.6.3.2-release} xcrun --toolchain swift -f swiftc)")")"
B="$(mktemp -d)"; trap 'rm -rf "$B"' EXIT
OUT="${HOST_NAME:-WasmCart}"

python3 gen-natives.py "$KIT/Sources/KitABI/include/KitABI.h" "$B/natives.c"
clang -c -Os -DNDEBUG -ffunction-sections \
  -I vendor/wamr/core/iwasm/include -I "$KIT/Sources/KitABI/include" \
  "$B/natives.c" -o "$B/natives.o"

TOOLCHAINS="${SWIFT_TOOLCHAIN:-org.swift.6.3.2-release}" xcrun --toolchain swift swiftc \
  -enable-experimental-feature Embedded -wmo -Osize -parse-as-library \
  -Xcc -fmodule-map-file=Sources/CSDL3/module.modulemap \
  -Xcc -fmodule-map-file=Sources/CWamr/module.modulemap \
  -Xcc -Ivendor/SDL/include -Xcc -Ivendor/wamr/core/iwasm/include \
  -I Sources/CSDL3 -I Sources/CWamr \
  -c Sources/cartridge.swift -o "$B/cartridge.o"

clang -o "$OUT" "$B/cartridge.o" "$B/natives.o" \
  vendor/libSDL3.a vendor/libiwasm.a \
  "$TC/lib/swift/embedded/arm64-apple-macos/libswiftUnicodeDataTables.a" \
  -framework Cocoa -framework QuartzCore -framework Metal -framework IOKit \
  -framework CoreVideo -framework CoreAudio -framework AudioToolbox \
  -framework Carbon -framework UniformTypeIdentifiers -liconv -lpthread \
  -dead_strip
strip "$OUT"
echo "✓ $OUT ($(stat -f%z "$OUT") bytes) - static SDL3 + static WAMR, no dylibs"
