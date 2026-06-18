#!/bin/bash
# wasm2aot: universal cart compiler. Cross-compiles a .wasm cart to native
# .aot for every WasmCart platform from ANY host - LLVM carries all the
# backends, so a single Mac/Linux/Windows(WSL/git-bash) box targets them all.
#
#   ./wasm2aot.sh game.wasm                          all default targets
#   ./wasm2aot.sh --targets=arm64 game.wasm          just one (comma list)
#   ./wasm2aot.sh --triple=riscv64-unknown-linux-gnu game.wasm   any LLVM triple
#   ./wasm2aot.sh -o outdir game.wasm                output directory
#   ./wasm2aot.sh game-cart.zip                      compile the zip's .wasm and
#                                                    pack the .aot files back in
#
# wamrc emits ELF-container .aot for every unix-like OS, so ONE file per
# arch covers macOS + Linux + Android (Intel and ARM are the two that
# matter); Windows needs its own msvc-ABI build. The defaults:
#   game.arm64.aot         macOS/Linux/Android on ARM64
#   game.x64.aot           macOS/Linux/Android on x86-64
#   game.windows-x64.aot   Windows on x86-64
# The console matches the tag against the machine it runs on and falls back
# to interpreting the .wasm. wamrc is built once from the vendored WAMR
# tree, so the AOT file format always matches the runtime in the console.
set -euo pipefail
cd "$(dirname "$0")"

# target name -> wamrc flags; aliases share one recipe so a zip built with
# --targets=macos-x64,linux-x64 simply carries two tags of the same code.
# x64 ELF gets --size-level=1: macOS/Windows can't map low memory, and the
# small code model's 32-bit relocations would fail there at load time.
flags_for() {
  case "$1" in
    arm64|macos-arm64|linux-arm64|android-arm64) echo "--target=aarch64 --target-abi=gnu" ;;
    x64|macos-x64|linux-x64|android-x64)         echo "--target=x86_64 --target-abi=gnu --size-level=1" ;;
    windows-x64)                                 echo "--target=x86_64 --target-abi=msvc" ;;
    # Windows ARM64 AOT is UNSUPPORTED by WAMR 2.x and must NOT be shipped:
    # wamrc emits a malformed bin_type (LLVMBinaryTypeCOFF - ELF32L = -1 =
    # 0xFFFF; its COFF fixup only knows AMD64/I386, not IMAGE_FILE_MACHINE_ARM64
    # 0xAA64), and the loader has no 0xAA64 machine case either. The resulting
    # file fails to load AND the host would pick it over the .wasm, hard-failing
    # the cart. Windows ARM64 runs the interpreted .wasm instead (it works).
    # Kept here only so an explicit --targets=windows-arm64 can compile for
    # testing; it is deliberately absent from DEFAULT_TARGETS.
    windows-arm64)                               echo "--target=aarch64 --target-abi=msvc --size-level=3" ;;
    x86|linux-x86)                               echo "--target=i386 --target-abi=gnu" ;;
    riscv64)                                     echo "--target=riscv64" ;;
    *) return 1 ;;
  esac
}
# Three distinct .aot files cover every OS x arch a player runs on a real .aot:
# the bare-arch ELF builds (arm64, x64) load as-is on macOS, Linux AND Android
# of that arch - WAMR's own AOT loader maps the code and resolves natives, so
# the host OS never touches it, only the CPU arch + register ABI matter (System
# V / AAPCS on all three, KitABI passes every arg in registers). windows-x64 is
# the lone COFF build. Windows ARM64 has no working AOT (see above) and falls
# back to the bundled .wasm interpreter.
DEFAULT_TARGETS="arm64 x64 windows-x64"

usage() {
  echo "Usage: $0 [--targets=a,b|--triple=<llvm-triple>] [-o dir] [--simd] <cart.wasm|cart.zip>"
  echo "Default targets: $DEFAULT_TARGETS"
  echo "Also: macos-/linux-/android- arm64|x64 (tag aliases), windows-arm64, x86, riscv64"
  exit 1
}

TARGETS="$DEFAULT_TARGETS"
CUSTOM_TRIPLE=""
OUTDIR=""
SIMD=0
INPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --targets=*) TARGETS="$(echo "${1#--targets=}" | tr ',' ' ')" ;;
    --triple=*)  CUSTOM_TRIPLE="${1#--triple=}" ;;
    --simd)      SIMD=1 ;;
    -o)          shift; OUTDIR="$1" ;;
    -h|--help)   usage ;;
    *)           INPUT="$1" ;;
  esac
  shift
done
[ -n "$INPUT" ] || usage
[ -f "$INPUT" ] || { echo "ERROR: no such file: $INPUT"; exit 1; }

# --- build wamrc once, from the SAME vendored WAMR as the runtime ----------
if [ ! -x vendor/wamrc ]; then
  [ -d vendor/wamr ] || ./vendor.sh

  # WAMR 2.4.2 bug: on macOS hosts the !abi fallback overwrites a full
  # --target=<triple> with the host arch; guard both paths with !triple
  AOTC=vendor/wamr/core/iwasm/compilation/aot_llvm.c
  if ! grep -q '!abi && !triple' "$AOTC"; then
    perl -0pi -e 's/(#if defined\(__APPLE__\) \|\| defined\(__MACH__\)\n\s+)if \(!abi\) \{/$1if (!abi && !triple) {/' "$AOTC"
    perl -0pi -e 's/if \(abi\) \{(\n\s+\/\* Construct target triple)/if (abi && !triple) {$1/' "$AOTC"
    grep -q '!abi && !triple' "$AOTC" || { echo "ERROR: triple patch failed"; exit 1; }
  fi

  # WAMR 2.4.2 builds against LLVM 18.x - prefer it, fall back to whatever is around
  LLVM_CMAKE="${LLVM_DIR:-}"
  if [ -z "$LLVM_CMAKE" ]; then
    for cfg in llvm-config-18 "$(brew --prefix llvm@18 2>/dev/null)/bin/llvm-config" \
               /usr/lib/llvm-18/bin/llvm-config llvm-config \
               "$(brew --prefix llvm 2>/dev/null)/bin/llvm-config"; do
      if command -v "$cfg" >/dev/null 2>&1; then LLVM_CMAKE="$("$cfg" --cmakedir)"; break; fi
    done
  fi
  if [ -z "$LLVM_CMAKE" ]; then
    echo "ERROR: LLVM not found. Install it (brew install llvm@18 / apt install llvm-18-dev)"
    echo "       or point LLVM_DIR at <llvm>/lib/cmake/llvm and rerun."
    exit 1
  fi
  echo "building wamrc with LLVM at $LLVM_CMAKE ..."
  cmake -S vendor/wamr/wamr-compiler -B vendor/wamrc-build \
    -DCMAKE_BUILD_TYPE=Release -DWAMR_BUILD_WITH_CUSTOM_LLVM=1 \
    -DLLVM_DIR="$LLVM_CMAKE" >/dev/null
  cmake --build vendor/wamrc-build -j >/dev/null
  cp vendor/wamrc-build/wamrc vendor/
fi
echo "✓ vendor/wamrc"

# --- unpack a zip cart's wasm to a temp dir --------------------------------
ZIP_IN=""
WASM="$INPUT"
if [[ "$INPUT" == *.zip ]]; then
  command -v unzip >/dev/null || { echo "ERROR: unzip required for zip carts"; exit 1; }
  command -v zip   >/dev/null || { echo "ERROR: zip required for zip carts"; exit 1; }
  ZIP_IN="$INPUT"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  ENTRY="$(unzip -Z1 "$ZIP_IN" | grep '\.wasm$' | head -1 || true)"
  [ -n "$ENTRY" ] || { echo "ERROR: no .wasm inside $ZIP_IN"; exit 1; }
  unzip -p "$ZIP_IN" "$ENTRY" > "$TMP/cart.wasm"
  WASM="$TMP/cart.wasm"
  STEM="$(basename "$ENTRY" .wasm)"
  [ -n "$OUTDIR" ] || OUTDIR="$TMP"
else
  STEM="$(basename "$WASM")"
  STEM="${STEM%.wasm}"
  [ -n "$OUTDIR" ] || OUTDIR="$(dirname "$INPUT")"
fi
mkdir -p "$OUTDIR"

# --- compile ----------------------------------------------------------------
# no --simd by default: the console runtime is built without SIMD.
# --opt-level=0: wamrc's optimizer (any level >= 1) miscompiles address math
# in Embedded-Swift carts on aarch64 - the aot then reads/writes the wrong
# linear-memory offsets (random hangs, corrupted scenes, crashes) while the
# same .wasm interprets cleanly. O0 code is still native and holds 60 fps.
# --bounds-checks=1: the aot carries its own checks, so a bad access traps
# with a clean exception on any runtime flavor instead of corrupting memory.
EXTRA=(--opt-level=${OPT_LEVEL:-0} --bounds-checks=1)
[ "$SIMD" = 1 ] || EXTRA+=(--disable-simd)

BUILT=()
compile_one() { # tag flags...
  local tag="$1"; shift
  local out="$OUTDIR/$STEM.$tag.aot"
  if vendor/wamrc "${EXTRA[@]}" "$@" -o "$out" "$WASM" >/dev/null 2>"$OUTDIR/.wamrc-err"; then
    echo "✓ $out ($(stat -f%z "$out" 2>/dev/null || stat -c%s "$out") bytes)"
    BUILT+=("$out")
  else
    echo "✗ $tag failed:"
    sed 's/^/    /' "$OUTDIR/.wamrc-err"
  fi
}

if [ -n "$CUSTOM_TRIPLE" ]; then
  compile_one "$CUSTOM_TRIPLE" --target="$CUSTOM_TRIPLE"
else
  for t in $TARGETS; do
    FLAGS="$(flags_for "$t")" || { echo "✗ unknown target: $t (see --help)"; continue; }
    compile_one "$t" $FLAGS
  done
fi
rm -f "$OUTDIR/.wamrc-err"

# --- pack .aot files back into the zip cart ---------------------------------
# the .aot entries land in the SAME zip folder as the .wasm, so an unzipped
# cart stays one flat root: assets/, manifest.json, .wasm and .aot together
if [ -n "$ZIP_IN" ] && [ "${#BUILT[@]}" -gt 0 ]; then
  PREFIX="$(dirname "$ENTRY")"
  [ "$PREFIX" = "." ] && PREFIX=""
  ZIPABS="$(cd "$(dirname "$ZIP_IN")" && pwd)/$(basename "$ZIP_IN")"
  PACKDIR="$TMP/pack"
  mkdir -p "$PACKDIR/$PREFIX"
  REL=()
  for f in "${BUILT[@]}"; do
    cp "$f" "$PACKDIR/$PREFIX/"
    if [ -n "$PREFIX" ]; then REL+=("$PREFIX/$(basename "$f")"); else REL+=("$(basename "$f")"); fi
  done
  (cd "$PACKDIR" && zip -q "$ZIPABS" "${REL[@]}")
  echo "✓ packed ${#BUILT[@]} .aot into $ZIP_IN (loader picks the native one, .wasm stays as fallback)"
fi
