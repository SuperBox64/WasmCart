#!/bin/bash
# Vendor BOTH dependencies from source - no package managers, any platform.
# SDL3: static, minimal subsystems. WAMR: static fast-interpreter + AOT
# loader + WASI, no JIT, no SIMD. Carts ship as .wasm (interpreted) or
# .aot (precompiled with wasm2aot.sh for native speed).
set -euo pipefail
cd "$(dirname "$0")"
SDLVER="${SDL_VER:-release-3.4.10}"
WAMRVER="${WAMR_VER:-WAMR-2.4.4}"
THORVGVER="${THORVG_VER:-9bb0e24}"
PLATFORM="$(uname | tr '[:upper:]' '[:lower:]')"

if [ ! -f vendor/libSDL3.a ]; then
  mkdir -p vendor
  [ -d vendor/SDL ] || git clone --depth 1 --branch "$SDLVER" https://github.com/libsdl-org/SDL vendor/SDL
  cmake -S vendor/SDL -B vendor/sdl-build -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST_LIBRARY=OFF \
    -DSDL_CAMERA=OFF -DSDL_SENSOR=OFF -DSDL_HAPTIC=OFF -DSDL_GPU=OFF \
    -DSDL_VULKAN=OFF -DSDL_DIALOG=ON -DSDL_POWER=OFF -DSDL_OPENGL=OFF -DSDL_OPENGLES=OFF \
    -DSDL_JOYSTICK=ON -DSDL_HIDAPI=ON >/dev/null
  cmake --build vendor/sdl-build -j >/dev/null
  cp vendor/sdl-build/libSDL3.a vendor/
fi
echo "✓ vendor/libSDL3.a ($(stat -f%z vendor/libSDL3.a 2>/dev/null || stat -c%s vendor/libSDL3.a) bytes)"

if [ ! -f vendor/libiwasm.a ]; then
  [ -d vendor/wamr ] || git clone --depth 1 --branch "$WAMRVER" https://github.com/bytecodealliance/wasm-micro-runtime vendor/wamr
  cmake -S "vendor/wamr/product-mini/platforms/$PLATFORM" -B vendor/wamr-build \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DWAMR_BUILD_INTERP=1 -DWAMR_BUILD_FAST_INTERP=1 \
    -DWAMR_BUILD_AOT=1 -DWAMR_BUILD_JIT=0 -DWAMR_BUILD_FAST_JIT=0 \
    -DWAMR_BUILD_LIBC_WASI=1 -DWAMR_BUILD_LIBC_BUILTIN=0 \
    -DWAMR_BUILD_SIMD=0 -DWAMR_BUILD_MULTI_MODULE=0 \
    -DWAMR_BUILD_BULK_MEMORY=1 -DWAMR_BUILD_REF_TYPES=1 \
    -DWAMR_BUILD_DUMP_CALL_STACK=1 -DWAMR_BUILD_CUSTOM_NAME_SECTION=1 >/dev/null
  cmake --build vendor/wamr-build -j  >/dev/null
  cp vendor/wamr-build/libiwasm.a vendor/
fi
echo "✓ vendor/libiwasm.a ($(stat -f%z vendor/libiwasm.a 2>/dev/null || stat -c%s vendor/libiwasm.a) bytes)"

# ThorVG: SVG rasterizer (replaces the prebuilt libresvg.a drop -- buildable from
# source + reproducible + smaller). CPU SW engine only: it bakes SVG into a
# caller-provided pixel buffer for SDL_UpdateTexture; the gl/wg engines render into
# GPU textures and don't fit the bake-to-texture step. SIMD + multi-threaded.
# Pinned to the commit verified to render the cart SVGs (clip + mask + embedded
# base64 PNG) correctly. The C API header lives in the cloned source tree.
if [ ! -f vendor/libthorvg-1.a ]; then
  if [ ! -d vendor/thorvg ]; then
    git clone https://github.com/thorvg/thorvg vendor/thorvg
  fi
  ( cd vendor/thorvg && { git fetch --depth 1 origin "$THORVGVER" 2>/dev/null || true; } && git checkout -q "$THORVGVER" )
  rm -rf vendor/thorvg-build
  meson setup vendor/thorvg vendor/thorvg-build \
    --default-library=static --buildtype=release \
    -Dengines=cpu -Dloaders=svg,png -Dthreads=true -Dsimd=true \
    -Dbindings=capi -Dstatic=true -Dextra= -Dsavers= -Dtools= -Dtests=false -Dlog=false >/dev/null
  meson compile -C vendor/thorvg-build >/dev/null
  cp vendor/thorvg-build/src/libthorvg-1.a vendor/
fi
echo "✓ vendor/libthorvg-1.a ($(stat -f%z vendor/libthorvg-1.a 2>/dev/null || stat -c%s vendor/libthorvg-1.a) bytes)"