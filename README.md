# WasmCart

**A native game console: an Embedded‑Swift + SDL3 shell that plays `.wasm`/`.aot` SuperBox64Kit cartridges through WAMR — no browser, no JavaScript, one ~1.6 MB binary.**

WasmCart is the **native console** of the SuperBox64Kit game stack. It owns the
**WAMR runtime** and the **AOT toolchain**: a vendored
[wasm‑micro‑runtime](https://github.com/bytecodealliance/wasm-micro-runtime)
(fast‑interpreter + `wamrc` AOT loader) plus `wasm2aot.sh`, the universal cart
compiler that cross‑compiles one cart `.wasm` to native `.aot` for every console
platform from any single dev box.

Insert a cartridge — a zip (game `.wasm`/`.aot` + `assets/` + `manifest.json`), a
bare `.wasm`, or a precompiled `.aot` — and it runs through the **exact same
KitABI graphics/audio/input backend** as the web build. The shell UI itself is a
real SuperBox64Kit `SKScene`. One cartridge file runs unchanged on the web (via
[WasmKit](../WasmKit)) and natively here. Everything — SDL3, WAMR, resvg — is
**vendored and statically linked from source**: no package managers, no dylibs.

```
WasmCart asteroidz/asteroidz-embedded.wasm
CARTRIDGE_WASM=carts/ufoemoji-cart.zip ./WasmCart
```

---

## What is this — the drop‑in story

The whole constellation runs **one unchanged game source tree** (the original
Xcode SpriteKit app, [UFO‑Emoji‑Arcade](../UFO-Emoji-Arcade)) through several
build × runtime permutations. The trick is
[**SuperBox64Kit**](../SuperBox64Kit): a Swift reimplementation of Apple's
SpriteKit that compiles a game three ways — browser wasm, wasm cartridge, native
binary — and presents a single C ABI called **KitABI** to whatever host renders
it. Apple's `NSEvent`/`UITouch`/`SKScene`/`GCController` surface is emulated; the
physics use **Box2D v3** under a SpriteKit‑shaped API; SVG cart art is rasterized
with **reSVG**.

WasmCart is **permutation 3**: the native console. A cartridge `.wasm` (the same
file that runs in a browser through WasmKit's Canvas2D `runtime.js`) is loaded
into a **WAMR** module by an Embedded‑Swift SDL3 shell. WasmCart's
`vendor/natives.c` registers ~100 native functions into the WASM `env` module —
each one a thin thunk forwarding the cart's KitABI import to the same
`sdl3-backend.swift` the Kit uses natively. So:

> The cart calls `gfx_draw_image` / `snd_play` / `gp_button`. On the web those are
> JavaScript functions in `runtime.js` drawing to Canvas2D. Here they are C
> functions drawing to **SDL3 + Metal**. Same cart, same calls, different host.

Carts play two ways inside the console:

- **Interpreted** — WAMR fast‑interpreter on the cart's `.wasm` (`\0asm` magic).
  The universal fallback that always works on every CPU and OS.
- **AOT‑native** — `wamrc` ahead‑of‑time compiles the `.wasm` to a native `.aot`
  (`\0aot` magic) that loads at **60 fps native speed**. `wasm2aot.sh` produces
  these for every platform from a single machine.

---

## Where this repo sits among the 5

```
                    ┌──────────────────────────────────────────────┐
                    │            UFO-Emoji-Arcade                  │
                    │  ONE SpriteKit game source (the demo/flagship)│
                    │  iOS · macOS · web · native consoles          │
                    └───────────────────┬──────────────────────────┘
                                        │ same game source, transformed
                    ┌───────────────────▼──────────────────────────┐
                    │               SuperBox64Kit                   │
                    │  SpriteKit reimpl · KitABI · Box2D v3 · SDL3  │
                    │  reSVG · native/build-native-game.sh          │
                    └───┬───────────────┬───────────────┬──────────┘
                        │ KitABI (env imports) fulfilled by each host:
        ┌───────────────┘               │               └───────────────┐
        ▼                               ▼                               ▼
 ┌─────────────┐                 ┌─────────────┐                 ┌─────────────┐
 │  WasmKit    │                 │  WasmCart   │  ◀── YOU ARE    │   Wasm5     │
 │  (web)      │                 │  (native)   │      HERE       │  (webview)  │
 │ runtime.js  │                 │ SDL3 shell  │                 │ SDL3 shell  │
 │ Canvas2D    │                 │ + WAMR      │                 │ + WKWebView │
 │             │                 │ + wamrc AOT │                 │ (runtime.js)│
 └─────────────┘                 └─────────────┘                 └─────────────┘
   browser, no                   .wasm interp +                  cart's WEB build
   webview                       native .aot                     in a real browser
                                 SDL3 + Metal                    stack, SDL keys
                                                                 forwarded as DOM
```

WasmCart and Wasm5 share the **same SDL3 SKScene shell**. The difference: WasmCart
runs the cart through **WAMR** (KitABI → SDL3); Wasm5 runs the cart's **web build
inside a WKWebView** (KitABI → Canvas2D, via `runtime.js`).

---

## Features

- **Plays any SuperBox64Kit cartridge** — a zip (`game.wasm`/`.aot` + `assets/` +
  `manifest.json`), a bare `.wasm`, or a bare `.aot`. Assets, fonts, scenes,
  particles, sounds and the manifest are read **straight out of the zip** with no
  extraction (`zipAssetBytes`, `loadWasmFromZip`, `preloadZipSounds`,
  `applyCartManifest`).
- **Per‑machine payload selection** — the host picks the best cart payload for the
  machine: the exact `os-arch` `.aot` tag, then this CPU arch's ELF `.aot` (shared
  by macOS/Linux/Android), then the interpreted `.wasm` fallback.
- **WAMR runtime built lean** — fast‑interpreter + AOT loader + **WASI Preview 1**;
  no JIT, no SIMD, no multi‑module. Carts are core wasm + WASI P1 — exactly what
  the Swift wasm toolchain emits.
- **`wasm2aot.sh`, the universal cart compiler** — cross‑compiles one cart `.wasm`
  into native `.aot` for every console platform (arm64 / x64 / windows‑x64 by
  default, plus aliases, x86, riscv64, or any custom LLVM `--triple`) from a single
  dev box, and can repack the `.aot` files back into the cart zip.
- **The shell UI is itself a SuperBox64Kit `SKScene`** — a hand‑built 10×14
  segment vector font (`ShellFont`, drawn with `SKShapeNode` line segments), an
  auto‑rescanning carts list, keyboard + mouse navigation (single‑click select,
  double‑click load), a native SDL3 **open‑file dialog**, and a live **EMOJI mode**
  switch.
- **Three switchable color‑emoji sources** — Apple Color Emoji `.ttc` (macOS),
  `apple-color-emoji.zip` PNGs decoded on the fly (any platform), and bundled/
  system **NotoColorEmoji** — with the choice persisted in a namespaced `store.tsv`.
- **Full KitABI native surface bridged to wasm** — 2D graphics, polygons, images,
  text, offscreen/shadow/filter/composite, GPU‑style shader / lighting / warp /
  3D‑billboard calls, an audio‑graph engine (`eng_*`), gamepad, TTS, key/mouse/
  event polling, and window control (see [KitABI surface](#kitabi-surface)).
- **reSVG‑backed SVG rasterization** (`KIT_USE_RESVG` / `libresvg.a`, resvg 0.45.1)
  so vector cart art renders crisply.
- **`CARTRIDGE_SELFTEST` mode** — auto‑drives input, runs *N* seconds, and dumps a
  `cart-selftest.bmp` screenshot for automated verification.
- **PROF/HUD frame‑timing instrumentation** — splits real per‑frame work
  (logic / img / txt / blit) from vsync‑idle, and mirrors the web `runtime.js`
  on‑screen FPS overlay via the `dbg_set_overlays` native.
- **Fully static, vendored‑from‑source build** (SDL3 + WAMR + resvg), a single
  self‑contained executable, no package managers or dylibs.

---

## Build × runtime permutations

WasmCart is rows 5 and 6 below — the **WAMR interpreter** and the **wamrc AOT**
native paths. (Full matrix lives in [SuperBox64Kit](../SuperBox64Kit) and
[UFO‑Emoji‑Arcade](../UFO-Emoji-Arcade); abbreviated here.)

| # | wasm flavor | Host / runtime | Renderer | Repo |
|---|-------------|----------------|----------|------|
| 1 | none — Apple‑native | Apple SpriteKit (UIKit/AppKit) | Metal + UIKit | UFO‑Emoji‑Arcade |
| 2 | full‑Swift `wasm32‑wasip1` (~4.18 MB) | `runtime.js` in a browser | Canvas2D | WasmKit |
| 3 | Embedded‑Swift `wasm32` (~688 KB) | minified `runtime.js` in a browser | Canvas2D | WasmKit |
| 4 | none — Embedded‑Swift native | SDL3 backend, no wasm | SDL3 + Metal | SuperBox64Kit |
| **5** | **full/Embedded cart `.wasm`** | **WAMR interpreter** (`\0asm`) | **SDL3 + Metal** | **WasmCart** |
| **6** | **cart `.wasm` → native `.aot`** | **WAMR + wamrc AOT** (`\0aot`) | **SDL3 + Metal** | **WasmCart** |
| 7 | the web build, unchanged | WKWebView (`runtime.js`) | Canvas2D in WebView | Wasm5 |

**Rows 5 & 6 in detail.** `build.sh` builds the console (Embedded Swift, static
SDL3 + static WAMR `libiwasm.a` + `libresvg.a`) via the Kit's
`native/build-native-game.sh`. `host-main.swift` loads a cart zip, and
`wasm_runtime_load` detects the magic: `\0asm` → interpreted, `\0aot` → native.
PROF note: a typical cart does **~2.3 ms of real work per frame**; the rest is
vsync idle, so don't chase rendering for FPS. The interpreter path is the
universal fallback that always works; native `.aot` holds 60 fps.

---

## Build & Run

### Build

```bash
./build.sh                  # vendors SDL3 + WAMR, builds the WasmCart executable
HOST_NAME=WasmUp ./build.sh # build the reserved-name variant (WasmUp)
./vendor.sh                 # just vendor + statically build libSDL3.a and libiwasm.a
SDL_VER=release-3.4.10 WAMR_VER=WAMR-2.4.2 ./vendor.sh   # pin/override vendored versions
```

> **Note:** the shipped console executable is produced by **`build.sh`**
> (`host-main.swift` + `Sources/ShellScene.swift` via the Kit's native build),
> **not** by `swift build` of `Package.swift`. The SwiftPM target only exposes a
> small library; building the executable requires the `../SuperBox64Kit` checkout
> present (`build.sh` resolves it via `KIT=../SuperBox64Kit`).

`build.sh` runs `vendor.sh`, compiles `vendor/natives.c` and the Kit's CZip
`zip.c`, then invokes `native/build-native-game.sh` with `GAME_SRC=Sources`,
`GAME_MAIN=host-main.swift`, the static `libSDL3.a` + `libiwasm.a` + `libresvg.a`,
`KIT_USE_RESVG`, and `CWamr`/`CZip` module‑map `-Xcc` flags.

### Run

```bash
./WasmCart                                       # empty slot: pick a cart from carts/, click, or drop a wasm
WasmCart asteroidz/asteroidz-embedded.wasm       # run a specific cart
CARTRIDGE_WASM=path/game.wasm ./WasmCart         # auto-insert a cart by env var
CARTRIDGE_WASM=carts/ufoemoji-cart.zip ./WasmCart
WASMCART_CARTS=/path/to/carts ./WasmCart         # point the shell at a carts folder
```

The repo ships four cartridges in `carts/` (the shell's default scan location):
`asteroidz-cart.zip`, `bossman-cart.zip`, `ufoemoji-cart.zip`,
`ufoemoji-embedded-cart.zip`.

### Compile AOT carts (`wasm2aot.sh`)

`wasm2aot.sh` builds `wamrc` **once** from the same vendored WAMR tree (needs
**LLVM 18.x**; it patches a WAMR 2.4.2 macOS triple bug), then cross‑compiles a
cart `.wasm` to native `.aot` for any target — so a Mac builds the Windows, Linux,
and Android carts too.

```bash
./wasm2aot.sh game.wasm                          # .aot for all default targets (arm64 x64 windows-x64)
./wasm2aot.sh game-cart.zip                      # compile + pack the .aot files back INTO the zip
./wasm2aot.sh --targets=arm64 game.wasm          # one target (comma list)
./wasm2aot.sh --triple=riscv64-unknown-linux-gnu game.wasm   # any LLVM triple
./wasm2aot.sh -o outdir --simd game.wasm         # output dir / enable SIMD
```

`wamrc` emits **ELF‑container `.aot`** for every unix‑like OS, so three files cover
the whole console matrix: `game.arm64.aot` (macOS/Linux/Android on ARM64),
`game.x64.aot` (the same trio on Intel), and `game.windows-x64.aot` (the msvc ABI).
The console loads the `.aot` matching the machine it runs on and falls back to
interpreting the `.wasm`, so one zip stays universal. Bare `.aot` files load too —
drop one on the window or put it in `carts/`.

> **AOT correctness flags (do not change):** `wasm2aot.sh` uses
> **`--opt-level=0`** — `wamrc`'s optimizer (level ≥ 1) **miscompiles address math
> in Embedded‑Swift carts on aarch64**, reading/writing the wrong linear‑memory
> offsets (random hangs, corrupted scenes, crashes) while the same `.wasm`
> interprets cleanly. O0 is still native and holds 60 fps. **`--bounds-checks=1`**
> makes bad accesses trap cleanly. The x64 ELF `.aot` additionally gets
> `--size-level=1` (small code model; macOS/Windows can't map low memory).

---

## Cartridge contract & API

### What a cart must export

A cartridge is a WASM module that exports two functions the host calls:

| export | when | meaning |
|--------|------|---------|
| `boot()` | once, after instantiate | one‑time game setup |
| `frame(dt: f64)` | every frame | advance + render one frame |

Missing either export ⇒ **"not a cartridge"**. (Do **not** call `_initialize`
yourself — WAMR already runs the WASI reactor's `_initialize`/`__wasm_call_ctors`
for both interpreter and AOT.)

### Host entry point — `host-main.swift`

`enum Main.main()` is the console entry point (Embedded Swift, ~840 lines). It
boots Kit + SDL3 + WAMR, loads emoji fonts, runs a dedicated game thread that
loads/instantiates a cart and calls its `boot()`/`frame(dt)` exports, ejects on
**CTRL+ESC**, and reads assets/sounds/manifest straight out of the cart zip. Key
internals: `insertCart`, `takePendingCart`, `ejectCart`, `loadWasmFromZip`,
`zipAssetBytes`, `emojiZipPng`, `applyCartManifest`, `manifestInt`,
`siblingCartZip`, `shellTick`.

### The WAMR ↔ KitABI bridge — `vendor/natives.c`

Defines `NativeSymbol kit_natives[]` (~100 entries) and
`bool kit_register_natives(void)`, which registers them into the WASM `env`
module. Each `wamr_*` thunk forwards to the KitABI C function. `vid_*` are stubs.
Also exposes `void set_current_zip_archive(void*)`. (Marked "generate with
`gen-natives.py`"; that generator is not in this repo's tree.)

C symbols imported by the host via `@_silgen_name`/`@_cdecl`:
`kit_register_natives`, `set_current_zip_archive`, `wc_set_overlays`.

<a name="kitabi-surface"></a>**KitABI surface bridged into wasm:**

| group | functions (selection) |
|-------|------------------------|
| 2D gfx | `gfx_clear/save/restore/translate/scale/rotate/set_alpha/set_blend/set_tint`, `gfx_fill_rect/circle/poly`, `gfx_stroke_*`, `gfx_draw_image` |
| text | `gfx_draw_text`, `txt_width`, `gfx_set_text_baseline`, `font_by_name` |
| images | `img_by_name/width/height`, `img_polygon_from_alpha`, `gfx_upload_pixels` |
| offscreen / fx | `gfx_offscreen_begin/end_to_image/discard`, `gfx_draw_shadow_image`, `gfx_set_filter/shadow/composite`, `gfx_free_image` |
| shader / 3D | `gfx_shader_compile/release/set_uniform_*/draw`, `gfx_lighting_draw`, `gfx_warp_draw`, `gfx_3d_draw_billboard` |
| audio | `snd_by_name/create_pcm/play/stop/set_volume/set_pan/set_rate/status`, `snd_pause_all/resume_all` |
| audio graph | `eng_player_create/release/schedule_buffer/play/stop`, `eng_mixer_create`, `eng_node_set_volume/pan`, `eng_connect`, `eng_start/stop` |
| input | `key_pressed`, `mouse_x/y/button`, `evt_poll`, `gp_connected/button/button_value/axis/map_to_keys` |
| TTS | `tts_speak/cancel/set_preferred_voices/set_robotic_voices/set_female_voices` |
| window / store / assets | `win_width/height/set_title/request_fullscreen/exit_fullscreen/download`, `store_get/set`, `asset_exists/text`, `load_asset_from_zip`, `dbg_set_overlays`, `js_log` |

### SwiftPM library product — `Sources/WasmCart/WasmCart.swift`

The `Package.swift` product (`swift-tools-version 6.2`, language mode v6) exposes a
small public surface — **not** the executable:

```swift
public struct WasmCart { public init() }
public func loadAssetFromZip(_ archive: OpaquePointer, _ name: String) -> [UInt8]?
```

### Environment variables

| var | effect |
|-----|--------|
| `CARTRIDGE_WASM` | auto‑insert a cart path (zip, `.wasm`, or `.aot`) |
| `CARTRIDGE_SELFTEST` | run *N* seconds, auto‑drive input, dump `cart-selftest.bmp`, exit |
| `WASMCART_CARTS` | carts directory the shell scans |
| `HOST_NAME` | build‑time output executable name (e.g. `WasmUp`) |
| `SDL_VER` / `WAMR_VER` / `LLVM_DIR` | vendoring / wamrc toolchain overrides |

---

## Keyboard & controls

| key | action |
|-----|--------|
| arrows / WASD + Space | game movement / fire |
| C | coin |
| F | fullscreen |
| E | cycle EMOJI mode (APPLE → PNG → NOTO) |
| Enter / double‑click | load the selected cart |
| (drop a `.wasm`/`.aot`/zip anytime) | insert that cart |
| **CTRL+ESC** | eject to the shell |

In the shell, navigate the carts list with arrows / mouse; single‑click selects,
double‑click (or Enter) loads. An **OPEN FILE** row brings up the native SDL3 file
dialog.

---

## Cross‑platform notes

- **ELF `.aot` is arch‑keyed, not OS‑keyed.** One bare‑arch `.aot` (e.g.
  `game.arm64.aot`) loads on **macOS, Linux, and Android** of that arch — only the
  CPU arch + register ABI matter. Windows‑x64 uses a COFF/msvc `.aot`.
- **Windows‑arm64 AOT is deliberately unshipped.** WAMR 2.x emits a malformed COFF
  `bin_type` and the loader has no `IMAGE_FILE_MACHINE_ARM64` case, so a
  windows‑arm64 `.aot` would break the cart (the host prefers `.aot` over `.wasm`).
  Windows‑arm64 runs the **interpreted `.wasm`** instead — the universal fallback.
- **macOS triple bug patch.** On macOS hosts, WAMR 2.4.2's `!abi` fallback
  overwrites a full `--target=<triple>` with the host arch; `wasm2aot.sh`
  perl‑patches `aot_llvm.c` to guard with `!triple` so cross‑compilation works.
- **Asset name resolution.** Cart asset names arrive by basename, but the web
  export groups files into subfolders (`scenes/`, `images/`, `particles/`,
  `fonts/`, `sfx/`, `voice/`) and lowercases filenames; `zipAssetBytes` tries those
  prefixes and a lowercased fallback, or scenes/particles never load.
- **Emoji fonts must not be freed** after `kit_emoji_init` — it keeps pointers
  *into* the buffer for the app's lifetime.
- **Vsync paces the loop.** An extra sleep on top of `present` beats against vblank
  and drops frames; the remainder‑sleep is kept only as the cap for vsync‑off
  renderers and occluded windows.

---

## Dependencies (all vendored, static, from source)

| dep | version | how |
|-----|---------|-----|
| **SuperBox64Kit** | local path `../SuperBox64Kit` | supplies SpriteKit, CSDL3, CWamr, CZip, KitABI + `native/build-native-game.sh`, `sdl3-backend.swift`, `KitABI.h` |
| **SDL3** | release‑3.4.10 | `git` clone → cmake `MinSizeRel` static (`SDL_STATIC=ON`, dialog on; camera/sensor/haptic/GPU/Vulkan/OpenGL off; joystick + hidapi on) → `libSDL3.a` |
| **WAMR** | WAMR‑2.4.2 | `git` clone → static `libiwasm.a` (fast‑interp + AOT + WASI; no JIT/SIMD/multi‑module). `wamrc` built separately from the same tree |
| **resvg** | 0.45.1 (Apache‑2.0 / MIT) | prebuilt `vendor/libresvg.a` + `vendor/resvg.h`, linked via `KIT_USE_RESVG` |
| **LLVM** | 18.x | host build dep for `wamrc` **only** (`brew install llvm@18` / `apt install llvm-18-dev`, or `LLVM_DIR`) |
| system libs | — | `-liconv`, `-lz`; build tools: clang, cmake, swift 6.2 toolchain, git; `zip`/`unzip` for zip carts |
| emoji assets | — | `apple-color-emoji.zip` (PNG glyphs), `NotoColorEmoji.ttf`; Apple Color Emoji `.ttc` read from the system on macOS |

> `vendor/*` is gitignored except **`vendor/natives.c`** — the one
> source‑controlled file there. The `.a` files and the `SDL/`, `wamr/`,
> `*-build/` trees are produced by `vendor.sh` and cached.

---

## Related repos

| repo | role |
|------|------|
| [**SuperBox64Kit**](../SuperBox64Kit) | **The Kit.** The SpriteKit reimplementation, KitABI, Box2D v3 physics, SDL3 backend, and reSVG rasterizer this console is built **on**. `Package.swift` depends on it; `build.sh` shells out to its `native/build-native-game.sh`; the shell UI is one of its `SKScene`s. |
| [**WasmKit**](../WasmKit) | **The web runtime.** `runtime.js` + Canvas2D — the browser host that fulfils the same KitABI imports WasmCart bridges to SDL3. The **same cart `.wasm` runs unchanged** there. "One cartridge, every console" is the shared design goal. |
| [**Wasm5**](../Wasm5) | **The webview console.** WasmCart's SDL3 shell, but carts play in a **WKWebView** (real Canvas2D/`runtime.js` stack) with SDL3 keystrokes forwarded as synthetic DOM `KeyboardEvent`s. |
| [**UFO‑Emoji‑Arcade**](../UFO-Emoji-Arcade) | **The flagship game/demo.** One SpriteKit codebase that ships to Apple, the web, and native consoles — it produces the carts run here (`carts/ufoemoji-cart.zip`, `carts/ufoemoji-embedded-cart.zip`). |

---

## Credits & License

- **WAMR** — [wasm‑micro‑runtime](https://github.com/bytecodealliance/wasm-micro-runtime),
  Bytecode Alliance (Apache‑2.0 WITH LLVM‑exception). Vendored, statically linked.
- **SDL3** — [libsdl-org/SDL](https://github.com/libsdl-org/SDL) (zlib license).
  Vendored, statically linked. *(SDL upstream forbids AI‑generated contributions to
  SDL itself; that constraint applies to the SDL project, not to WasmCart's code.)*
- **resvg** — [resvg](https://github.com/RazrFalcon/resvg) 0.45.1, the Resvg
  Authors (Apache‑2.0 OR MIT); see `vendor/resvg.h`.
- **NotoColorEmoji** — SIL Open Font License v1.1; see
  [`NotoColorEmoji-LICENSE`](NotoColorEmoji-LICENSE).
- **Apple Color Emoji** — read from the system font on macOS; not redistributed.

This repo ships no top‑level license file; the bundled `NotoColorEmoji-LICENSE`
covers the Noto font, and `vendor/resvg.h` carries resvg's Apache‑2.0/MIT notice.
WasmCart's own console code (`host-main.swift`, `Sources/ShellScene.swift`,
`vendor/natives.c`, the build/vendor/AOT scripts) is part of the SuperBox64Kit
project by Heisenburg.
