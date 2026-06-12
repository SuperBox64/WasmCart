// WasmCart: the console as a permutation-3 SuperBox64Kit app. The shell UI
// is a real SKScene on the framework; inserted carts run through WAMR and
// draw through the SAME KitABI backend. Embedded Swift, static SDL3 +
// static WAMR, cross-platform.
//
//   ./WasmCart                 empty slot: click or drop a wasm to load
//   CARTRIDGE_WASM=... ./WasmCart
//   ESC ejects back to the shell.
import SpriteKit
import CSDL3
import CWamr
import CZip

@_silgen_name("kit_register_natives")
func kitRegisterNatives() -> Bool

nonisolated(unsafe) var currentZipArchive: OpaquePointer? = nil

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
    "wasm cartridge".withCString { desc in
        "wasm".withCString { pat in
            var filter = SDL_DialogFileFilter(name: desc, pattern: pat)
            SDL_ShowOpenFileDialog({ _, files, _ in
                if let files, let first = files.pointee {
                    insertCart(String(cString: first))
                }
            }, nil, Kit.shared.window, &filter, 1, nil, false)
        }
    }
}

nonisolated(unsafe) var wantDialog = SDL_AtomicInt(value: 0)

// MARK: - zip loading

func loadWasmFromZip(_ zipPath: String) -> (data: UnsafeMutableRawPointer?, size: Int)? {
    guard let archive = zip_open(zipPath) else {
        print("failed to open zip: \(zipPath)")
        return nil
    }

    var wasmFile: String? = nil
    let numFiles = zip_get_num_files(archive)
    var nameBuf = [CChar](repeating: 0, count: 256)

    for i in 0..<numFiles {
        var size: size_t = 0
        if zip_get_file_info(archive, UInt32(i), &nameBuf, nameBuf.count, &size) == 0 {
            let name = String(cString: nameBuf)
            if name.hasSuffix(".wasm") && !name.contains("/") {
                wasmFile = name
                break
            }
        }
    }

    guard let wasmFileName = wasmFile else {
        zip_close(archive)
        print("no .wasm file found in zip root")
        return nil
    }

    guard let file = zip_fopen(archive, wasmFileName) else {
        zip_close(archive)
        print("failed to open \(wasmFileName) in zip")
        return nil
    }

    var size: size_t = 0
    _ = zip_locate_file(archive, wasmFileName)
    size = zip_get_current_file_info_size(archive)

    guard let data = SDL_malloc(size) else {
        zip_fclose(file)
        zip_close(archive)
        return nil
    }

    let read = zip_fread(data, size, file)
    zip_fclose(file)

    if read != size {
        free(data)
        zip_close(archive)
        print("failed to read \(wasmFileName) from zip")
        return nil
    }

    currentZipArchive = archive
    return (data, Int(size))
}

// MARK: - main

@main
enum Main {
    static func main() {
        slotMutex = SDL_CreateMutex()
        kitEscapeReserved = true
        kitHostInit(appName: "WasmCart")

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
                if let z = currentZipArchive { zip_close(z); currentZipArchive = nil }
                exec = nil; inst = nil; module = nil; cartData = nil; frameFn = nil
                SDL_SetAtomicInt(&cartLoaded, 0)
                Kit.shared.stopAllVoices()
                while Kit.shared.popEvent() != nil {}
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
                var errBuf = [CChar](repeating: 0, count: 128)
                let m = errBuf.withUnsafeMutableBufferPointer { eb in
                    wasm_runtime_load(data.assumingMemoryBound(to: UInt8.self),
                                      UInt32(size), eb.baseAddress, UInt32(eb.count))
                }
                guard let m else { print("cart load failed"); SDL_free(data); return }
                wasm_runtime_set_wasi_args(m, nil, 0, nil, 0, nil, 0, nil, nil)
                let i = errBuf.withUnsafeMutableBufferPointer { eb in
                    wasm_runtime_instantiate(m, 256 * 1024, 0, eb.baseAddress, UInt32(eb.count))
                }
                guard let i else { print("cart instantiate failed"); wasm_runtime_unload(m); SDL_free(data); return }
                guard let e2 = wasm_runtime_create_exec_env(i, 256 * 1024) else {
                    wasm_runtime_deinstantiate(i); wasm_runtime_unload(m); SDL_free(data); return
                }

                // assets and the per-cart store live beside / are named by the cart
                var dir = path
                var base = path
                if let slash = dir.utf8.lastIndex(of: 47) {
                    dir = String(dir[..<slash])
                    base = String(path[path.index(after: slash)...])
                } else {
                    dir = "."
                }
                Kit.shared.assetDir = dir + "/assets/sfx"
                if let pref = ("SuperBox64".withCString { org in "WasmCart".withCString { SDL_GetPrefPath(org, $0) } }) {
                    Kit.shared.storePath = String(cString: pref) + base + ".store.tsv"
                    SDL_free(UnsafeMutableRawPointer(mutating: pref))
                }
                Kit.shared.storeKeys = []
                Kit.shared.storeVals = []
                Kit.shared.loadStore()

                if let initFn = "_initialize".withCString({ wasm_runtime_lookup_function(i, $0) }) {
                    _ = wasm_runtime_call_wasm(e2, initFn, 0, nil)
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
                    wasm_runtime_destroy_exec_env(e2); wasm_runtime_deinstantiate(i)
                    wasm_runtime_unload(m); SDL_free(data)
                    return
                }
                cartData = data; module = m; inst = i; exec = e2; frameFn = fFn
                elapsedMs = 0; frames = 0; sentStart = false; sentThrust = false
                SDL_SetAtomicInt(&cartLoaded, 1)
            }

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
                            print("selftest: \(frames) frames in cart")
                            SDL_SetAtomicInt(&runFlag, 0)
                        }
                    }
                } else {
                    // empty slot: the shell scene runs like any kit game
                    shellTick(Double(dt))
                }
                kitHostPresent()

                let used = SDL_GetTicksNS() - now
                if used < 16_666_666 { SDL_DelayNS(16_666_666 - used) }
            }
            ejectCart()
            wasm_runtime_destroy_thread_env()
            return 0
        }, "game", UnsafeMutableRawPointer(ctxBox), nil, nil)

        // main thread: the OS event pump plus console controls
        while SDL_GetAtomicInt(&runFlag) == 1 {
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
