#!/bin/bash
# Vendor BOTH dependencies from source - no package managers, any platform.
# SDL3: static, minimal subsystems. WAMR: static fast-interpreter + WASI,
# no JIT, no AOT, no SIMD - the no-dead-code build.
set -euo pipefail
cd "$(dirname "$0")"
SDLVER="${SDL_VER:-release-3.4.10}"
WAMRVER="${WAMR_VER:-WAMR-2.4.2}"
PLATFORM="$(uname | tr '[:upper:]' '[:lower:]')"

if [ ! -f vendor/libSDL3.a ]; then
  mkdir -p vendor
  [ -d vendor/SDL ] || git clone --depth 1 --branch "$SDLVER" https://github.com/libsdl-org/SDL vendor/SDL
  cmake -S vendor/SDL -B vendor/sdl-build -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST_LIBRARY=OFF \
    -DSDL_CAMERA=OFF -DSDL_SENSOR=OFF -DSDL_HAPTIC=OFF -DSDL_GPU=OFF \
    -DSDL_VULKAN=OFF -DSDL_DIALOG=OFF -DSDL_POWER=OFF -DSDL_OPENGL=OFF -DSDL_OPENGLES=OFF \
    -DSDL_JOYSTICK=OFF -DSDL_HIDAPI=OFF >/dev/null
  cmake --build vendor/sdl-build -j >/dev/null
  cp vendor/sdl-build/libSDL3.a vendor/
fi
echo "✓ vendor/libSDL3.a ($(stat -f%z vendor/libSDL3.a 2>/dev/null || stat -c%s vendor/libSDL3.a) bytes)"

if [ ! -f vendor/libiwasm.a ]; then
  [ -d vendor/wamr ] || git clone --depth 1 --branch "$WAMRVER" https://github.com/bytecodealliance/wasm-micro-runtime vendor/wamr
  cmake -S "vendor/wamr/product-mini/platforms/$PLATFORM" -B vendor/wamr-build \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DWAMR_BUILD_INTERP=1 -DWAMR_BUILD_FAST_INTERP=1 \
    -DWAMR_BUILD_AOT=0 -DWAMR_BUILD_JIT=0 -DWAMR_BUILD_FAST_JIT=0 \
    -DWAMR_BUILD_LIBC_WASI=1 -DWAMR_BUILD_LIBC_BUILTIN=0 \
    -DWAMR_BUILD_SIMD=0 -DWAMR_BUILD_MULTI_MODULE=0 \
    -DWAMR_BUILD_BULK_MEMORY=1 -DWAMR_BUILD_REF_TYPES=1 >/dev/null
  cmake --build vendor/wamr-build -j  >/dev/null
  cp vendor/wamr-build/libiwasm.a vendor/
fi
echo "✓ vendor/libiwasm.a ($(stat -f%z vendor/libiwasm.a 2>/dev/null || stat -c%s vendor/libiwasm.a) bytes)"
