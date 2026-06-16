// WasmCart: the console as a permutation-3 SuperBox64Kit app. The shell UI
// is a real SKScene on the framework; inserted carts run through WAMR and
// draw through the SAME KitABI backend. Embedded Swift, static SDL3 +
// static WAMR, cross-platform.
//
//   ./WasmCart                 empty slot: click or drop a wasm to load
//   CARTRIDGE_WASM=... ./WasmCart
//   CTRL+ESC ejects back to the shell.
import SpriteKit
import CSDL3
import CWamr
import CZip

@_silgen_name("kit_register_natives")
func kitRegisterNatives() -> Bool

nonisolated(unsafe) var currentZipArchive: OpaquePointer? = nil

@_silgen_name("set_current_zip_archive")
func setCurrentZipArchive(_ archive: OpaquePointer?) -> Void

// MARK: - cart slot state (main thread inserts/ejects, game thread owns it)

nonisolated(unsafe) var slotMutex: OpaquePointer? = nil
nonisolated(unsafe) var pendingCartPath: String? = nil
nonisolated(unsafe) var ejectFlag = SDL_AtomicInt(value: 0)
nonisolated(unsafe) var cartLoaded = SDL_AtomicInt(value: 0)
nonisolated(unsafe) var runFlag = SDL_AtomicInt(value: 1)

func insertCart(_ path: String) {
    SDL_LockMutex(slotMutex)
    pendingCartPath = path
    SDL_UnlockMutex(slotMutex)
}

func takePendingCart() -> String? {
    SDL_LockMutex(slotMutex)
    let p = pendingCartPath
    pendingCartPath = nil
    SDL_UnlockMutex(slotMutex)
    return p
}

func openCartDialog() {
    print("DEBUG: openCartDialog called")
    print("DEBUG: calling SDL_ShowOpenFileDialog with no filters")
    SDL_ShowOpenFileDialog({ _, files, _ in
        print("DEBUG: dialog callback called, files=\(files != nil ? "yes" : "nil")")
        if let files {
            var filePtr = files
            while let file = filePtr.pointee {
                print("DEBUG: selected file: \(String(cString: file))")
                insertCart(String(cString: file))
                filePtr += 1
            }
        }
    }, nil, Kit.shared.window, nil, 0, nil, false)
    print("DEBUG: SDL_ShowOpenFileDialog returned")
}

nonisolated(unsafe) var wantDialog = SDL_AtomicInt(value: 0)
nonisolated(unsafe) var currentFPS = SDL_AtomicInt(value: 0)

// MARK: - zip loading

// Kit asset source while a cart is inserted: images/fonts/levels resolve
// straight from the cart zip (CZip itself falls back past a single
// top-level folder prefix, so Finder-zipped carts work too)
func zipAssetBytes(_ name: String) -> [UInt8]? {
    guard let archive = currentZipArchive else { return nil }
    // The Kit asks by basename (SKScene(fileNamed:"GameMenu") -> "GameMenu.json",
    // SKTexture(imageNamed:"x") -> "x.svg"), but the web asset tree groups files
    // into subfolders (scenes/, images/, particles/, fonts/, sfx/, voice/). Try
    // those so e.g. GameMenu.json resolves to assets/scenes/GameMenu.json — without
    // this the scene/particle JSON never loads and the cart renders nothing.
    for candidate in [name, "assets/" + name,
                      "assets/scenes/" + name, "assets/particles/" + name,
                      "assets/images/" + name, "assets/fonts/" + name,
                      "assets/sfx/" + name, "assets/voice/" + name] {
        if let file = candidate.withCString({ zip_fopen(archive, $0) }) {
            let size = zip_fget_size(file)
            var out = [UInt8](repeating: 0, count: size)
            let read = out.withUnsafeMutableBytes { zip_fread($0.baseAddress, size, file) }
            zip_fclose(file)
            return read == size ? out : nil
        }
    }
    return nil
}

// Color-emoji fallback: when no emoji font is installed, the Kit asks for a
// codepoint's PNG and we pull <cp>.png out of apple-color-emoji.zip on the fly
// (no extraction). The archive is opened once, beside the binary; CZip's
// folder-prefix fallback matches the zip's apple-color-emoji/ entries by bare
// name. The decoded texture is cached by the Kit, so each glyph reads once.
nonisolated(unsafe) var emojiZip: OpaquePointer? = nil
nonisolated(unsafe) var emojiZipOpened = false

private func cpHexUpper(_ v: Int32) -> String {
    let digits = Array("0123456789ABCDEF")
    var n = Int(v)
    var out: [Character] = []
    if n == 0 { out = ["0"] }
    while n > 0 { out.insert(digits[n & 0xF], at: 0); n >>= 4 }
    while out.count < 4 { out.insert("0", at: 0) }
    return String(out)
}

func emojiZipPng(_ cp: Int32) -> [UInt8]? {
    if !emojiZipOpened {
        emojiZipOpened = true
        var candidates: [String] = []
        if let base = SDL_GetBasePath() {
            candidates.append(String(cString: base) + "apple-color-emoji.zip")
            SDL_free(UnsafeMutableRawPointer(mutating: base))
        }
        candidates.append("apple-color-emoji.zip")
        for c in candidates where emojiZip == nil { emojiZip = zip_open(c) }
    }
    guard let archive = emojiZip else { return nil }
    let hex = cpHexUpper(cp)
    for name in ["apple-color-emoji/u\(hex).png", "u\(hex).png"] {
        if let file = name.withCString({ zip_fopen(archive, $0) }) {
            let size = zip_fget_size(file)
            var out = [UInt8](repeating: 0, count: size)
            let read = out.withUnsafeMutableBytes { zip_fread($0.baseAddress, size, file) }
            zip_fclose(file)
            if read == size {
                print("emoji png: apple-color-emoji.zip!\(name) (\(size) bytes, cp U+\(hex))")
                return out
            }
        }
    }
    return nil
}

// A bare .wasm cart plays exactly like its zip: the wasm's folder is the
// cart root, so assets and manifest.json resolve beside it
nonisolated(unsafe) var cartDir: String? = nil

// A bare .aot/.wasm dropped beside its cart zip still needs the zip's assets
// and manifest: wasm2aot names every output <stem>.<target>.aot after the
// zip's <stem>.wasm, so the sibling zip carrying that wasm is the cart root.
func siblingCartZip(dir: String, stem: String) -> String? {
    var count: Int32 = 0
    guard let list = dir.withCString({ SDL_GlobDirectory($0, nil, 0, &count) }) else { return nil }
    defer { SDL_free(UnsafeMutableRawPointer(list)) }
    let want = stem + ".wasm"
    for i in 0..<Int(count) {
        guard let entry = list[i] else { continue }
        let name = String(cString: entry)
        guard name.hasSuffix(".zip") else { continue }
        let zipPath = dir + "/" + name
        guard let archive = zip_open(zipPath) else { continue }
        var nameBuf = [CChar](repeating: 0, count: 256)
        var found = false
        for j in 0..<zip_get_num_files(archive) {
            var size: size_t = 0
            guard zip_get_file_info(archive, UInt32(j), &nameBuf, nameBuf.count, &size) == 0 else { continue }
            let entryName = String(cString: nameBuf)
            if entryName == want || entryName.hasSuffix("/" + want) {
                found = true
                break
            }
        }
        zip_close(archive)
        if found { return zipPath }
    }
    return nil
}

func dirAssetBytes(_ name: String) -> [UInt8]? {
    guard let dir = cartDir else { return nil }
    for candidate in [dir + "/" + name, dir + "/assets/" + name] {
        var size = 0
        if let data = candidate.withCString({ SDL_LoadFile($0, &size) }), size > 0 {
            let bytes = UnsafeRawPointer(data).bindMemory(to: UInt8.self, capacity: size)
            var out = [UInt8](repeating: 0, count: size)
            for i in 0..<size { out[i] = bytes[i] }
            SDL_free(data)
            return out
        }
    }
    return nil
}

// Pull an integer out of the cart manifest without a JSON parser:
// the value after `"key":`, digits only
func manifestInt(_ json: [UInt8], _ key: String) -> Int? {
    let pat = Array(("\"" + key + "\"").utf8)
    var i = 0
    while i + pat.count < json.count {
        var match = true
        for j in 0..<pat.count where json[i + j] != pat[j] { match = false; break }
        if match {
            var p = i + pat.count
            while p < json.count, json[p] == 58 || json[p] == 32 { p += 1 }
            var value = 0
            var any = false
            while p < json.count, json[p] >= 48, json[p] <= 57 {
                value = value * 10 + Int(json[p] - 48)
                any = true
                p += 1
            }
            return any ? value : nil
        }
        i += 1
    }
    return nil
}

func applyCartManifest() {
    guard let manifest = Kit.shared.assetProvider?("manifest.json") else { return }
    if let w = manifestInt(manifest, "logicalWidth"), let h = manifestInt(manifest, "logicalHeight"), w > 0, h > 0 {
        Kit.shared.logicalW = Float(w)
        Kit.shared.logicalH = Float(h)
        print("DEBUG: cart logical size \(w)x\(h)")
    }
}

// .aot carts are native code; wasm2aot.sh tags each output with the bare
// arch (its ELF .aot runs on macOS/Linux/Android alike) or with os-arch
// for Windows' msvc ABI, so one zip carries the .wasm plus a few .aot
// files and every player gets native speed
#if os(Windows)
let aotOsName = "windows"
let elfAotOk = false // windows code needs the msvc ABI, never the ELF .aot
#elseif os(Android)
let aotOsName = "android"
let elfAotOk = true
#elseif os(macOS)
let aotOsName = "macos"
let elfAotOk = true
#else
let aotOsName = "linux"
let elfAotOk = true
#endif

var archTag: String {
    #if arch(arm64)
    return "arm64"
    #elseif arch(x86_64)
    return "x64"
    #elseif arch(i386)
    return "x86"
    #else
    return "arm32"
    #endif
}

var platformTag: String { aotOsName + "-" + archTag }

func nameContains(_ haystack: String, _ needle: String) -> Bool {
    let h = Array(haystack.utf8), n = Array(needle.utf8)
    guard !n.isEmpty, h.count >= n.count else { return false }
    for i in 0...(h.count - n.count) {
        var match = true
        for j in 0..<n.count where h[i + j] != n[j] { match = false; break }
        if match { return true }
    }
    return false
}

func loadWasmFromZip(_ zipPath: String) -> (data: UnsafeMutableRawPointer?, size: Int)? {
    print("DEBUG: opening zip: \(zipPath)")
    guard let archive = zip_open(zipPath) else {
        print("ERROR: failed to open zip: \(zipPath)")
        return nil
    }
    print("DEBUG: zip opened")

    var wasmFile: String? = nil
    var nativeAot: String? = nil
    var archAot: String? = nil
    var anyAot: String? = nil
    let numFiles = zip_get_num_files(archive)
    print("DEBUG: found \(numFiles) files in zip")
    var nameBuf = [CChar](repeating: 0, count: 256)

    for i in 0..<numFiles {
        var size: size_t = 0
        if zip_get_file_info(archive, UInt32(i), &nameBuf, nameBuf.count, &size) == 0 {
            let name = String(cString: nameBuf)
            print("DEBUG: file \(i): \(name) (\(size) bytes)")
            if name.hasSuffix(".aot") {
                if anyAot == nil { anyAot = name }
                if nativeAot == nil, nameContains(name, platformTag) { nativeAot = name }
                if elfAotOk, archAot == nil, nameContains(name, archTag),
                   !nameContains(name, "windows") { archAot = name }
            } else if name.hasSuffix(".wasm"), wasmFile == nil {
                wasmFile = name
            }
        }
    }

    // native code for this machine beats the interpreter: the exact os-arch
    // tag, then this arch's ELF .aot (shared by macOS/Linux/Android), then
    // the .wasm; a lone untagged .aot is a last resort (a mismatched one is
    // rejected by the loader)
    guard let wasmFileName = nativeAot ?? archAot ?? wasmFile ?? anyAot else {
        zip_close(archive)
        print("ERROR: no .wasm or .aot cart found in zip")
        return nil
    }

    print("DEBUG: opening \(wasmFileName)")
    guard let file = zip_fopen(archive, wasmFileName) else {
        zip_close(archive)
        print("ERROR: failed to open \(wasmFileName) in zip")
        return nil
    }
    print("DEBUG: file opened")

    let size = zip_fget_size(file)
    print("DEBUG: file size: \(size)")

    guard let data = SDL_malloc(size) else {
        zip_fclose(file)
        zip_close(archive)
        print("ERROR: malloc failed for \(size) bytes")
        return nil
    }

    let read = zip_fread(data, size, file)
    print("DEBUG: read \(read) bytes")
    zip_fclose(file)

    if read != size {
        free(data)
        zip_close(archive)
        print("ERROR: read mismatch: expected \(size), got \(read)")
        return nil
    }

    currentZipArchive = archive
    setCurrentZipArchive(archive)
    Kit.shared.assetProvider = zipAssetBytes
    applyCartManifest()
    print("DEBUG: zip cartridge loaded successfully")
    return (data, Int(size))
}

// Preload every .wav entry straight from the zip into the Kit's sound
// table (same registration shape as loadSoundImpl, keyed by basename).
// Nothing is extracted to disk; the cart's snd_by_name hits the cache.
func preloadZipSounds(_ archive: OpaquePointer) {
    let numFiles = zip_get_num_files(archive)
    var nameBuf = [CChar](repeating: 0, count: 256)
    for i in 0..<numFiles {
        var size: size_t = 0
        guard zip_get_file_info(archive, UInt32(i), &nameBuf, nameBuf.count, &size) == 0 else { continue }
        let name = String(cString: nameBuf)
        guard name.hasSuffix(".wav"), size > 0 else { continue }
        var base = name
        if let slash = name.utf8.lastIndex(of: 47) {
            base = String(name[name.index(after: slash)...])
        }
        if Kit.shared.soundNames[base] != nil { continue }
        guard let file = zip_fopen(archive, name) else { continue }
        guard let data = SDL_malloc(size) else { zip_fclose(file); continue }
        let read = zip_fread(data, size, file)
        zip_fclose(file)
        var spec = SDL_AudioSpec()
        var buf: UnsafeMutablePointer<UInt8>? = nil
        var len: UInt32 = 0
        if read == size, let io = SDL_IOFromConstMem(data, size) {
            _ = SDL_LoadWAV_IO(io, true, &spec, &buf, &len)
        }
        SDL_free(data)
        guard let buf else {
            print("ERROR: bad wav in zip: \(name)")
            continue
        }
        Kit.shared.soundNames[base] = Int32(Kit.shared.soundSpecs.count)
        Kit.shared.soundSpecs.append(spec)
        Kit.shared.soundBufs.append(buf)
        Kit.shared.soundLens.append(len)
    }
}

// MARK: - main

@main
enum Main {
    static func main() {
        slotMutex = SDL_CreateMutex()
        kitEscapeReserved = true
        kitHostInit(appName: "WasmCart")

        // Three emoji sources, picked from the shell's EMOJI menu (apple / png /
        // noto). Load each independently so the menu can switch live:
        //  - apple: Apple Color Emoji (sbix), macOS only
        //  - png:   apple-color-emoji.zip PNGs, pulled on the fly, any platform
        //  - noto:  NotoColorEmoji (CBDT), bundled or system-installed
        func loadEmojiFont(_ paths: [String], _ set: (UnsafePointer<UInt8>, Int) -> Void) {
            for path in paths {
                var size = 0
                guard let data = path.withCString({ SDL_LoadFile($0, &size) }), size > 0 else { continue }
                // kit_emoji_init keeps pointers INTO this buffer for the app's
                // lifetime, so it must stay alive — never SDL_free it. (Freeing
                // it left the font's cmap/CBDT pointers dangling, which read back
                // as garbage and crashed the glyph lookup.)
                set(UnsafeRawPointer(data).bindMemory(to: UInt8.self, capacity: size), size)
                return
            }
        }
        loadEmojiFont(["/System/Library/Fonts/Apple Color Emoji.ttc"]) {
            Kit.shared.setEmojiFont($0, $1)
        }
        var notoPaths = [
            "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf",
            "/usr/share/fonts/noto/NotoColorEmoji.ttf",
        ]
        if let base = SDL_GetBasePath() {
            notoPaths.insert(String(cString: base) + "NotoColorEmoji.ttf", at: 0)
        }
        loadEmojiFont(notoPaths) { Kit.shared.setNotoEmojiFont($0, $1) }
        Kit.shared.emojiPngProvider = emojiZipPng
        // restore the saved mode (default apple → on non-Mac that falls to png,
        // then noto, so Apple art wins and Noto is the last resort). Namespaced
        // with the console name so it never collides with a cart's own keys.
        // Load the console store.tsv FIRST — at startup Kit's store isn't pointed at
        // it yet (that only happens per-cart in ejectCart), so without this the saved
        // NOTO/PNG pick was ignored and every glyph fell back to APPLE.
        if let pref = ("SuperBox64".withCString { o in "WasmCart".withCString { SDL_GetPrefPath(o, $0) } }) {
            Kit.shared.storePath = String(cString: pref) + "store.tsv"
            SDL_free(UnsafeMutableRawPointer(mutating: pref))
            Kit.shared.loadStore()
        }
        if let saved = Kit.shared.storeGet("WasmCart.emojiMode"), let m = Int32(saved) {
            Kit.shared.setEmojiMode(m)
        }

        guard wasm_runtime_init() else { fatalError("wamr init failed") }
        guard kitRegisterNatives() else { fatalError("native registration failed") }

        if let p = ("CARTRIDGE_WASM".withCString { SDL_getenv($0) }) {
            insertCart(String(cString: p))
        }
        var selftest: Float = 0
        if let s = ("CARTRIDGE_SELFTEST".withCString { SDL_getenv($0) }) {
            selftest = Float(SDL_strtod(s, nil))
        }

        // the shell: a SuperBox64Kit scene
        let view = SKView()
        view.preferredFramesPerSecond = 60
        let shell = ShellScene(size: CGSize(width: 1920, height: 1080))
        shell.scaleMode = .aspectFill
        view.presentScene(shell)

        struct GameCtx { var selftest: Float }
        let ctxBox = UnsafeMutablePointer<GameCtx>.allocate(capacity: 1)
        ctxBox.initialize(to: GameCtx(selftest: selftest))

        shellView = view

        // the game thread owns BOTH the shell scene tick and the cart
        let gameThread = SDL_CreateThreadRuntime({ raw in
            let ctx = raw!.assumingMemoryBound(to: GameCtx.self)
            _ = wasm_runtime_init_thread_env()

            var inst: wasm_module_inst_t? = nil
            var module: wasm_module_t? = nil
            var cartData: UnsafeMutableRawPointer? = nil
            var exec: wasm_exec_env_t? = nil
            var frameFn: wasm_function_inst_t? = nil
            var elapsedMs: Float = 0
            var frames = 0
            var sentStart = false
            var sentThrust = false

            func ejectCart() {
                if let e2 = exec { wasm_runtime_destroy_exec_env(e2) }
                if let i2 = inst { wasm_runtime_deinstantiate(i2) }
                if let m2 = module { wasm_runtime_unload(m2) }
                if let d2 = cartData { SDL_free(d2) }
                if let z = currentZipArchive { zip_close(z); currentZipArchive = nil; setCurrentZipArchive(nil) }
                cartDir = nil
                Kit.shared.assetProvider = nil
                Kit.shared.logicalW = LOGICAL_W
                Kit.shared.logicalH = LOGICAL_H
                exec = nil; inst = nil; module = nil; cartData = nil; frameFn = nil
                SDL_SetAtomicInt(&cartLoaded, 0)
                Kit.shared.stopAllVoices()
                while Kit.shared.popEvent() != nil {}
                // back the console's own store, so shell settings (emoji mode)
                // persist to store.tsv and never land in the last cart's file
                if let pref = ("SuperBox64".withCString { o in "WasmCart".withCString { SDL_GetPrefPath(o, $0) } }) {
                    Kit.shared.storePath = String(cString: pref) + "store.tsv"
                    SDL_free(UnsafeMutableRawPointer(mutating: pref))
                }
                Kit.shared.storeKeys = []
                Kit.shared.storeVals = []
                Kit.shared.loadStore()
                // Re-apply the saved console emoji mode now that store.tsv is loaded. The
                // startup read (main init) runs BEFORE this store exists, so the user's
                // NOTO/PNG pick was ignored and every glyph fell back to APPLE. With Noto
                // + the PNG zip both loaded, this makes either a real replacement "for
                // anything", and on non-Mac (no Apple Color Emoji) it's what renders.
                if let saved = Kit.shared.storeGet("WasmCart.emojiMode"), let m = Int32(saved) {
                    Kit.shared.setEmojiMode(m)
                }
            }

            func loadCart(_ path: String) {
                ejectCart()

                var data: UnsafeMutableRawPointer
                var size: Int

                if path.hasSuffix(".zip") {
                    guard let result = loadWasmFromZip(path) else {
                        print("failed to load wasm from zip: " + path)
                        return
                    }
                    data = result.data!
                    size = result.size
                } else {
                    var rawSize = 0
                    guard let rawData = path.withCString({ SDL_LoadFile($0, &rawSize) }) else {
                        print("cart not found: " + path)
                        return
                    }
                    data = rawData
                    size = rawSize
                }
                // DEBUG: dump first 4 bytes (magic), size, and head/tail
                // hex of the buffer about to be handed to wasm_runtime_load.
                // \0asm = wasm, \0aot = WAMR AOT. Anything else means the
                // loader is getting a wrong/truncated buffer. Head+tail hex
                // lets you compare against `xxd` on the wasm file on disk.
                do {
                    let bytes = data.assumingMemoryBound(to: UInt8.self)
                    func hex2(_ v: UInt8) -> String {
                        let d = Array("0123456789abcdef")
                        return String(d[Int(v >> 4)]) + String(d[Int(v & 0xF)])
                    }
                    func hexRange(_ start: Int, _ count: Int) -> String {
                        var s = ""
                        for i in 0..<count {
                            let idx = start + i
                            if idx < 0 || idx >= size { continue }
                            if !s.isEmpty { s += " " }
                            s += hex2(bytes[idx])
                        }
                        return s
                    }
                    let b0 = size > 0 ? bytes[0] : 0
                    let b1 = size > 1 ? bytes[1] : 0
                    let b2 = size > 2 ? bytes[2] : 0
                    let b3 = size > 3 ? bytes[3] : 0
                    var magicAscii = ""
                    for b in [b0, b1, b2, b3] {
                        magicAscii += (b >= 0x20 && b < 0x7f) ? String(UnicodeScalar(b)) : "."
                    }
                    print("DEBUG: wasm_runtime_load buf size=\(size) magic='\(magicAscii)' head16=[\(hexRange(0, 16))] tail16=[\(hexRange(max(0, size - 16), 16))]")
                }
                var errBuf = [CChar](repeating: 0, count: 128)
                let m = errBuf.withUnsafeMutableBufferPointer { eb in
                    wasm_runtime_load(data.assumingMemoryBound(to: UInt8.self),
                                      UInt32(size), eb.baseAddress, UInt32(eb.count))
                }
                guard let m else {
                    print("cart load failed: " + String(cString: errBuf))
                    SDL_free(data)
                    return
                }
                wasm_runtime_set_wasi_args(m, nil, 0, nil, 0, nil, 0, nil, nil)
                let i = errBuf.withUnsafeMutableBufferPointer { eb in
                    wasm_runtime_instantiate(m, 256 * 1024, 0, eb.baseAddress, UInt32(eb.count))
                }
                guard let i else {
                    print("cart instantiate failed: " + String(cString: errBuf))
                    wasm_runtime_unload(m)
                    SDL_free(data)
                    return
                }
                guard let e2 = wasm_runtime_create_exec_env(i, 256 * 1024) else {
                    wasm_runtime_deinstantiate(i); wasm_runtime_unload(m); SDL_free(data); return
                }

                var dir = path
                var base = path
                if let slash = path.utf8.lastIndex(of: 47) {
                    dir = String(path[..<slash])
                    base = String(path[path.index(after: slash)...])
                } else {
                    dir = "."
                }

                if path.hasSuffix(".zip") {
                    if let z = currentZipArchive { preloadZipSounds(z) }
                } else {
                    var stem = base
                    if let dot = stem.utf8.firstIndex(of: 46) { stem = String(stem[..<dot]) }
                    if let zipPath = siblingCartZip(dir: dir, stem: stem), let archive = zip_open(zipPath) {
                        currentZipArchive = archive
                        setCurrentZipArchive(archive)
                        Kit.shared.assetProvider = zipAssetBytes
                        applyCartManifest()
                        preloadZipSounds(archive)
                    } else {
                        Kit.shared.assetDir = dir + "/assets/sfx"
                        cartDir = dir
                        Kit.shared.assetProvider = dirAssetBytes
                        applyCartManifest()
                    }
                }

                if let pref = ("SuperBox64".withCString { org in "WasmCart".withCString { SDL_GetPrefPath(org, $0) } }) {
                    Kit.shared.storePath = String(cString: pref) + base + ".store.tsv"
                    SDL_free(UnsafeMutableRawPointer(mutating: pref))
                }
                Kit.shared.storeKeys = []
                Kit.shared.storeVals = []
                Kit.shared.loadStore()

                // Do NOT call _initialize here. WAMR's wasm_runtime_instantiate
                // already runs a WASI reactor's _initialize (which runs
                // __wasm_call_ctors) automatically, for BOTH the interpreter and
                // AOT. Calling it a second time re-enters the reactor's run-once
                // guard, which is compiled to `unreachable` — that was the
                // long-standing "boot trapped: unreachable" on full-Swift-WASI
                // carts (the old code called it explicitly). By the time we reach
                // boot() the cart's globals/runtime are already initialized.
                if let ex = wasm_runtime_get_exception(i) {
                    print("post-instantiate trapped: " + String(cString: ex))
                    wasm_runtime_dump_call_stack(e2)
                    wasm_runtime_destroy_exec_env(e2); wasm_runtime_deinstantiate(i)
                    wasm_runtime_unload(m); SDL_free(data)
                    return
                }
                guard let bootFn = "boot".withCString({ wasm_runtime_lookup_function(i, $0) }),
                      let fFn = "frame".withCString({ wasm_runtime_lookup_function(i, $0) }) else {
                    print("not a cartridge: missing boot/frame")
                    wasm_runtime_destroy_exec_env(e2); wasm_runtime_deinstantiate(i)
                    wasm_runtime_unload(m); SDL_free(data)
                    return
                }
                _ = wasm_runtime_call_wasm(e2, bootFn, 0, nil)
                if let ex = wasm_runtime_get_exception(i) {
                    print("boot trapped: " + String(cString: ex))
                    wasm_runtime_dump_call_stack(e2)
                    wasm_runtime_destroy_exec_env(e2); wasm_runtime_deinstantiate(i)
                    wasm_runtime_unload(m); SDL_free(data)
                    return
                }
                cartData = data; module = m; inst = i; exec = e2; frameFn = fFn
                elapsedMs = 0; frames = 0; sentStart = false; sentThrust = false
                SDL_SetAtomicInt(&cartLoaded, 1)
            }

            var vsyncOn: Int32 = 0
            _ = SDL_GetRenderVSync(Kit.shared.renderer, &vsyncOn)
            var fpsFrames = 0
            var fpsStart = SDL_GetTicksNS()
            var last = SDL_GetTicksNS()
            while SDL_GetAtomicInt(&runFlag) == 1 {
                if let path = takePendingCart() { loadCart(path) }
                if SDL_GetAtomicInt(&ejectFlag) == 1 {
                    SDL_SetAtomicInt(&ejectFlag, 0)
                    ejectCart()
                }

                let now = SDL_GetTicksNS()
                var dt = Float(now - last) / 1_000_000
                last = now
                if dt > 50 { dt = 50 }

                if let exec2 = exec, let fFn = frameFn, let inst2 = inst {
                    var arg = wasm_val_t()
                    arg.kind = wasm_valkind_t(WASM_F64.rawValue)
                    arg.of.f64 = Double(dt)
                    _ = wasm_runtime_call_wasm_a(exec2, fFn, 0, nil, 1, &arg)
                    if let ex = wasm_runtime_get_exception(inst2) {
                        print("frame trapped: " + String(cString: ex))
                        ejectCart()
                    }
                    frames += 1
                    elapsedMs += dt
                    let st = ctx.pointee.selftest
                    if st > 0 {
                        if elapsedMs >= 1000, !sentStart {
                            sentStart = true
                            Kit.shared.pushEvent((5, 57, 0, 0, 0))
                            Kit.shared.pushEvent((6, 57, 0, 0, 0))
                        }
                        if elapsedMs >= 2000, !sentThrust {
                            sentThrust = true
                            Kit.shared.pushEvent((5, 73, 0, 0, 0))
                        }
                        if elapsedMs >= st * 1000 {
                            if let surf = SDL_RenderReadPixels(Kit.shared.renderer, nil) {
                                let sRGB = SDL_ConvertSurfaceAndColorspace(surf, SDL_PIXELFORMAT_ARGB8888, nil, SDL_COLORSPACE_SRGB, 0)
                                _ = "cart-selftest.bmp".withCString { SDL_SaveBMP(sRGB ?? surf, $0) }
                                if let sRGB { SDL_DestroySurface(sRGB) }
                                SDL_DestroySurface(surf)
                            }
                            print("selftest: \(frames) frames in cart -> cart-selftest.bmp")
                            SDL_SetAtomicInt(&runFlag, 0)
                        }
                    }
                } else {
                    // empty slot: the shell scene runs like any kit game
                    shellTick(Double(dt))
                }
                let _ppt0 = SDL_GetTicksNS(); kitHostPresent(); Kit.shared.profPresentNs += SDL_GetTicksNS() - _ppt0

                fpsFrames += 1
                let fnow = SDL_GetTicksNS()
                if fnow - fpsStart >= 1_000_000_000 {
                    let fps = (UInt64(fpsFrames) * 1_000_000_000 + (fnow - fpsStart) / 2) / (fnow - fpsStart)
                    SDL_SetAtomicInt(&currentFPS, Int32(fps))
                    let pk = Kit.shared
                    let pn = UInt64(max(1, fpsFrames))
                    print("PROF fps=\(fps)  img=\(pk.profImgNs/pn/1000)us  txt=\(pk.profTxtNs/pn/1000)us  present=\(pk.profPresentNs/pn/1000)us  (per frame; /1000=ms)")
                    pk.profImgNs = 0; pk.profTxtNs = 0; pk.profPresentNs = 0
                    fpsFrames = 0
                    fpsStart = fnow
                }

                // vsync paces the loop by blocking in present; sleeping the
                // remainder on top of that beats against the vblank and drops
                // frames (~52 fps). The sleep stays as the cap for vsync-off
                // renderers and occluded windows where present returns at once.
                let used = SDL_GetTicksNS() - now
                if vsyncOn == 0 || used < 4_000_000 {
                    if used < 16_666_666 { SDL_DelayNS(16_666_666 - used) }
                }
            }
            ejectCart()
            wasm_runtime_destroy_thread_env()
            return 0
        }, "game", UnsafeMutableRawPointer(ctxBox), nil, nil)

        // main thread: the OS event pump plus console controls
        var shownFPS: Int32 = -1
        while SDL_GetAtomicInt(&runFlag) == 1 {
            let fps = SDL_GetAtomicInt(&currentFPS)
            if fps != shownFPS {
                shownFPS = fps
                _ = "WasmCart - \(fps) FPS".withCString { SDL_SetWindowTitle(Kit.shared.window, $0) }
            }
            if !kitHostPump() {
                SDL_SetAtomicInt(&runFlag, 0)
                break
            }
            if kitEscapePressed {
                kitEscapePressed = false
                if SDL_GetAtomicInt(&cartLoaded) == 1 {
                    SDL_SetAtomicInt(&ejectFlag, 1)
                }
            }
            if SDL_GetAtomicInt(&wantDialog) == 1 {
                print("DEBUG: processing wantDialog")
                SDL_SetAtomicInt(&wantDialog, 0)
                openCartDialog()
            }
            if let dropped = kitDroppedFile {
                kitDroppedFile = nil
                insertCart(dropped)
            }
            SDL_DelayNS(2_000_000)
        }

        var status: Int32 = 0
        SDL_WaitThread(gameThread, &status)
        SDL_Quit()
    }

}

// the shell scene's view tick, reachable from the game thread
nonisolated(unsafe) var shellView: SKView? = nil

func shellTick(_ dtMs: Double) {
    shellView?.tick(dtMs)
}
