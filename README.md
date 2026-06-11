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

Embedded Swift (no Swift stdlib, no Foundation) talking to SDL3 and the
wasmtime C API through C interop, about 190 KB. The env import surface is
bound from each module's own import table, so new games keep working
without host changes.

```
brew install sdl3 wasmtime
./build.sh                  # builds WasmCart
HOST_NAME=WasmUp ./build.sh # the reserved-name variant
```

Controls: arrows/WASD + Space, C for coin, F for fullscreen.
