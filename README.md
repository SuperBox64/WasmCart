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

## AOT carts

Carts also play as precompiled native code. `wasm2aot.sh` cross-compiles a
.wasm to `.aot` for every console platform from any single dev box (the
vendored WAMR's `wamrc` + LLVM do the targeting, so a Mac builds the
Windows, Linux, and Android carts too):

```
./wasm2aot.sh game.wasm                      # .aot for all default targets
./wasm2aot.sh game-cart.zip                  # compile + pack them INTO the zip
./wasm2aot.sh --targets=arm64 game.wasm
./wasm2aot.sh --triple=riscv64-unknown-linux-gnu game.wasm   # anything LLVM knows
```

wamrc emits ELF-container `.aot` for every unix-like OS, so three files
cover the whole console matrix: `game.arm64.aot` (macOS/Linux/Android on
ARM64), `game.x64.aot` (same trio on Intel), and `game.windows-x64.aot`
(the msvc ABI). The console loads the `.aot` matching the machine it runs
on and falls back to interpreting the `.wasm`, so one zip stays universal.
Bare `.aot` files load too - drop one on the window or put it in `carts/`.

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
