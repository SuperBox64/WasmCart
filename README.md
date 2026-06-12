# WasmCart

A native console for wasm game cartridges. No browser, no webview, no
JavaScript: one small host binary plays every game built on SuperBox64Kit,
straight from a cartridge zip.

```
WasmCart asteroidz/asteroidz-embedded.wasm
CARTRIDGE_WASM=path/game.wasm ./WasmCart
```

## Cartridges

A cart zip holds the game wasm plus its assets folder. Unzip anywhere and
point the host at the wasm. The same wasm file also runs unchanged on the
web through WasmKit, which is the point: one cartridge, every console.

Releases carry the host binaries and `{game}-cart.zip` files.

## Host

Embedded Swift (no Swift stdlib, no Foundation) talking to SDL3 and WAMR
through C interop. BOTH dependencies are vendored and built from source -
static, no package managers, no dylibs - and the sealed binary is about
1.6 MB. Cartridges are core wasm + WASI Preview 1, exactly what the Swift
wasm toolchain emits.

```
./build.sh                  # vendors SDL3 + WAMR, builds WasmCart
HOST_NAME=WasmUp ./build.sh # the reserved-name variant
```

Controls: arrows/WASD + Space, C for coin, F for fullscreen.
