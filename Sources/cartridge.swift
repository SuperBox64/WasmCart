// WasmCart: a native console for wasm game cartridges. Loads ANY game
// wasm built on SuperBox64Kit and plays it like a cartridge. Embedded Swift
// host (no stdlib, no Foundation), SDL3 + WAMR statically vendored from
// source - no package managers, no dylibs, cross-platform by construction.
//
//   ./WasmCart game.wasm
//   CARTRIDGE_WASM=game.wasm ./WasmCart
//   CARTRIDGE_SELFTEST=4 ./WasmCart game.wasm
import CSDL3
import CWamr

let LOGICAL_W: Float = 1920
let LOGICAL_H: Float = 1080

// MARK: - Canvas2D-compatible affine matrix

struct Mat {
    var a: Float = 1, b: Float = 0, c: Float = 0, d: Float = 1, e: Float = 0, f: Float = 0

    mutating func mul(_ n: Mat) {
        self = Mat(
            a: a * n.a + c * n.b, b: b * n.a + d * n.b,
            c: a * n.c + c * n.d, d: b * n.c + d * n.d,
            e: a * n.e + c * n.f + e, f: b * n.e + d * n.f + f
        )
    }

    func apply(_ x: Float, _ y: Float) -> SDL_FPoint {
        SDL_FPoint(x: a * x + c * y + e, y: b * x + d * y + f)
    }

    var lengthScale: Float {
        (SDL_sqrtf(a * a + b * b) + SDL_sqrtf(c * c + d * d)) / 2
    }
}

// MARK: - Host state

final class Host {
    var renderer: OpaquePointer? = nil
    var mat = Mat()
    var base = Mat()
    var stack: [Mat] = []
    var alpha: Float = 1
    var events: [(Int32, Int32, Int32, Int32, Int32)] = []

    var soundSpecs: [SDL_AudioSpec] = [SDL_AudioSpec()]
    var soundBufs: [UnsafeMutablePointer<UInt8>?] = [nil]
    var soundLens: [UInt32] = [0]
    var soundNames: [String: Int32] = [:]
    var audioDevice: UInt32 = 0
    var voiceStreams: [OpaquePointer] = []
    var voiceLoops: [Int32] = []
    var voiceIds: [Int32] = []
    var voicePans: [Float] = []
    var nextVoice: Int32 = 1
    var storeKeys: [String] = []
    var storeVals: [String] = []
    var assetDir = ""
    var storePath = ""
    var drawCalls = 0

    func cString(_ p: UnsafePointer<CChar>?, _ len: Int32) -> String {
        guard let p else { return "" }
        var bytes = [UInt8]()
        bytes.reserveCapacity(Int(len) + 1)
        for i in 0..<Int(len) { bytes.append(UInt8(bitPattern: p[i])) }
        bytes.append(0)
        return bytes.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    func fcolor(_ rgba: UInt32) -> SDL_FColor {
        SDL_FColor(
            r: Float((rgba >> 24) & 0xFF) / 255,
            g: Float((rgba >> 16) & 0xFF) / 255,
            b: Float((rgba >> 8) & 0xFF) / 255,
            a: Float(rgba & 0xFF) / 255 * alpha
        )
    }

    // Thick polyline: one quad per segment via RenderGeometry.
    func strokePoly(_ pts: [SDL_FPoint], closed: Bool, thickness: Float, rgba: UInt32) {
        drawCalls += 1
        if pts.count < 2 { return }
        let color = fcolor(rgba)
        let w = max(1, thickness * mat.lengthScale) / 2
        var verts = [SDL_Vertex]()
        var idx = [Int32]()
        let segs = closed ? pts.count : pts.count - 1
        for i in 0..<segs {
            let p1 = pts[i]
            let p2 = pts[(i + 1) % pts.count]
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let len = max(SDL_sqrtf(dx * dx + dy * dy), 0.0001)
            let nx = -dy / len * w
            let ny = dx / len * w
            let base = Int32(verts.count)
            verts.append(SDL_Vertex(position: SDL_FPoint(x: p1.x + nx, y: p1.y + ny), color: color, tex_coord: SDL_FPoint(x: 0, y: 0)))
            verts.append(SDL_Vertex(position: SDL_FPoint(x: p2.x + nx, y: p2.y + ny), color: color, tex_coord: SDL_FPoint(x: 0, y: 0)))
            verts.append(SDL_Vertex(position: SDL_FPoint(x: p2.x - nx, y: p2.y - ny), color: color, tex_coord: SDL_FPoint(x: 0, y: 0)))
            verts.append(SDL_Vertex(position: SDL_FPoint(x: p1.x - nx, y: p1.y - ny), color: color, tex_coord: SDL_FPoint(x: 0, y: 0)))
            idx.append(base)
            idx.append(base + 1)
            idx.append(base + 2)
            idx.append(base)
            idx.append(base + 2)
            idx.append(base + 3)
        }
        SDL_RenderGeometry(renderer, nil, verts, Int32(verts.count), idx, Int32(idx.count))
    }

    func fillPoly(_ pts: [SDL_FPoint], rgba: UInt32) {
        drawCalls += 1
        if pts.count < 3 { return }
        let color = fcolor(rgba)
        var verts = [SDL_Vertex]()
        verts.reserveCapacity(pts.count)
        for p in pts {
            verts.append(SDL_Vertex(position: p, color: color, tex_coord: SDL_FPoint(x: 0, y: 0)))
        }
        var idx = [Int32]()
        for i in 1..<(pts.count - 1) {
            idx.append(0)
            idx.append(Int32(i))
            idx.append(Int32(i + 1))
        }
        SDL_RenderGeometry(renderer, nil, verts, Int32(verts.count), idx, Int32(idx.count))
    }

    func circlePts(_ cx: Float, _ cy: Float, _ r: Float) -> [SDL_FPoint] {
        var out = [SDL_FPoint]()
        out.reserveCapacity(32)
        for i in 0..<32 {
            let t = Float(i) / 32 * 2 * Float.pi
            out.append(mat.apply(cx + r * SDL_cosf(t), cy + r * SDL_sinf(t)))
        }
        return out
    }

    func loadSound(_ name: String) -> Int32 {
        var base = name
        var lastSlash = -1
        var i = 0
        for ch in base.utf8 {
            if ch == 47 { lastSlash = i }
            i += 1
        }
        if lastSlash >= 0 {
            var bytes = Array(base.utf8)
            bytes.removeFirst(lastSlash + 1)
            bytes.append(0)
            base = bytes.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        }
        if let id = soundNames[base] { return id }
        let id = Int32(soundSpecs.count)
        soundNames[base] = id
        var spec = SDL_AudioSpec()
        var buf: UnsafeMutablePointer<UInt8>? = nil
        var len: UInt32 = 0
        let path = assetDir + "/" + base
        _ = path.withCString { SDL_LoadWAV($0, &spec, &buf, &len) }
        soundSpecs.append(spec)
        soundBufs.append(buf)
        soundLens.append(len)
        return id
    }

    // One real device; every voice is a stream bound to it and the device
    // mixes. Finished voices are reaped each frame; loops refill on drain.
    @discardableResult
    func play(_ id: Int32, volume: Float, loop: Bool) -> Int32 {
        let i = Int(id)
        guard i > 0, i < soundBufs.count, let buf = soundBufs[i] else { return -1 }
        if audioDevice == 0 {
            audioDevice = SDL_OpenAudioDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, nil)
            guard audioDevice != 0 else { return -1 }
            _ = SDL_ResumeAudioDevice(audioDevice)
        }
        var spec = soundSpecs[i]
        guard let stream = SDL_CreateAudioStream(&spec, nil) else { return -1 }
        // the ABI carries volume as 0-100 (the web runtime divides the same way)
        _ = SDL_SetAudioStreamGain(stream, max(0, min(1, volume / 100)))
        // bind BEFORE queueing: binding re-targets the stream's output format
        // to the device and discards any already-converted data, so data put
        // first simply evaporates (verified: queued drops to 0 instantly)
        _ = SDL_BindAudioStream(audioDevice, stream)
        _ = SDL_PutAudioStreamData(stream, buf, Int32(soundLens[i]))
        if !loop { _ = SDL_FlushAudioStream(stream) }
        let voice = nextVoice
        nextVoice += 1
        voiceStreams.append(stream)
        voiceLoops.append(loop ? id : 0)
        voiceIds.append(voice)
        voicePans.append(0)
        return voice
    }

    func stopVoice(_ voice: Int32) {
        for i in 0..<voiceIds.count where voiceIds[i] == voice {
            SDL_UnbindAudioStream(voiceStreams[i])
            SDL_DestroyAudioStream(voiceStreams[i])
            voiceStreams.remove(at: i)
            voiceLoops.remove(at: i)
            voiceIds.remove(at: i)
            voicePans.remove(at: i)
            return
        }
    }

    func setVoiceVolume(_ voice: Int32, _ volume: Float) {
        for i in 0..<voiceIds.count where voiceIds[i] == voice {
            _ = SDL_SetAudioStreamGain(voiceStreams[i], max(0, min(1, volume / 100)))
            return
        }
    }

    func setVoicePan(_ voice: Int32, _ pan: Float) {
        for i in 0..<voiceIds.count where voiceIds[i] == voice {
            voicePans[i] = max(-1, min(1, pan))
            return
        }
    }

    func reapVoices() {
        var i = 0
        while i < voiceStreams.count {
            let stream = voiceStreams[i]
            let queued = SDL_GetAudioStreamQueued(stream)
            let loopId = voiceLoops[i]
            if loopId > 0 {
                let li = Int(loopId)
                if queued < Int32(soundLens[li]) / 2, let buf = soundBufs[li] {
                    _ = SDL_PutAudioStreamData(stream, buf, Int32(soundLens[li]))
                }
                i += 1
            } else if queued <= 0, SDL_GetAudioStreamAvailable(stream) <= 0 {
                SDL_UnbindAudioStream(stream)
                SDL_DestroyAudioStream(stream)
                voiceStreams.remove(at: i)
                voiceLoops.remove(at: i)
                voiceIds.remove(at: i)
                voicePans.remove(at: i)
            } else {
                i += 1
            }
        }
    }

    // Store: "key\tvalue\n" lines through SDL's file API (no Foundation).
    func storeGet(_ key: String) -> String? {
        for i in 0..<storeKeys.count where storeKeys[i] == key { return storeVals[i] }
        return nil
    }

    func storeSet(_ key: String, _ val: String) {
        for i in 0..<storeKeys.count where storeKeys[i] == key {
            storeVals[i] = val
            saveStore()
            return
        }
        storeKeys.append(key)
        storeVals.append(val)
        saveStore()
    }

    func saveStore() {
        var out = [UInt8]()
        for i in 0..<storeKeys.count {
            out.append(contentsOf: Array(storeKeys[i].utf8))
            out.append(9)
            out.append(contentsOf: Array(storeVals[i].utf8))
            out.append(10)
        }
        _ = storePath.withCString { path in
            out.withUnsafeBufferPointer { SDL_SaveFile(path, $0.baseAddress, $0.count) }
        }
    }

    func loadStore() {
        var size = 0
        let data = storePath.withCString { SDL_LoadFile($0, &size) }
        guard let data else { return }
        let bytes = UnsafeRawPointer(data).bindMemory(to: UInt8.self, capacity: size)
        var field = [UInt8]()
        var key = ""
        for i in 0..<size {
            let ch = bytes[i]
            if ch == 9 {
                field.append(0)
                key = field.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
                field = []
            } else if ch == 10 {
                field.append(0)
                let val = field.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
                field = []
                storeKeys.append(key)
                storeVals.append(val)
            } else {
                field.append(ch)
            }
        }
        SDL_free(data)
    }
}

let host = Host()

// Two-thread console: the OS may block the MAIN thread in modal loops
// (macOS menu tracking, Windows window drags), so the GAME thread owns the
// simulation and rendering and never stops. SDL threads/mutexes keep this
// portable everywhere.
nonisolated(unsafe) var evtMutex: OpaquePointer? = nil
nonisolated(unsafe) var runFlag = SDL_AtomicInt(value: 1)

func pushEvent(_ e: (Int32, Int32, Int32, Int32, Int32)) {
    SDL_LockMutex(evtMutex)
    host.events.append(e)
    SDL_UnlockMutex(evtMutex)
}

func popEvent() -> (Int32, Int32, Int32, Int32, Int32)? {
    SDL_LockMutex(evtMutex)
    let e = host.events.isEmpty ? nil : host.events.removeFirst()
    SDL_UnlockMutex(evtMutex)
    return e
}

// MARK: - WAMR natives: typed Swift functions, registered from natives.c.
// Pointer parameters arrive ALREADY converted to native addresses by WAMR's
// signature system - no manual wasm-memory arithmetic anywhere.

@_silgen_name("kit_register_natives")
func kitRegisterNatives() -> Bool

@_cdecl("wamr_js_log")
func wamr_js_log(_ e: OpaquePointer?, _ p: UnsafePointer<CChar>?, _ len: Int32) {
    print(host.cString(p, len))
}

@_cdecl("wamr_gfx_clear")
func wamr_gfx_clear(_ e: OpaquePointer?, _ rgba: UInt32) {
    var pw: Int32 = 0
    var ph: Int32 = 0
    _ = SDL_GetRenderOutputSize(host.renderer, &pw, &ph)
    let sc = min(Float(pw) / LOGICAL_W, Float(ph) / LOGICAL_H)
    host.mat = Mat(a: sc, b: 0, c: 0, d: sc,
                   e: (Float(pw) - LOGICAL_W * sc) / 2,
                   f: (Float(ph) - LOGICAL_H * sc) / 2)
    host.stack = []
    host.alpha = 1
    let c = host.fcolor(rgba)
    _ = SDL_SetRenderDrawColorFloat(host.renderer, c.r, c.g, c.b, 1)
    _ = SDL_RenderClear(host.renderer)
}

@_cdecl("wamr_gfx_save")
func wamr_gfx_save(_ e: OpaquePointer?) { host.stack.append(host.mat) }

@_cdecl("wamr_gfx_restore")
func wamr_gfx_restore(_ e: OpaquePointer?) {
    if let m = host.stack.popLast() { host.mat = m }
}

@_cdecl("wamr_gfx_translate")
func wamr_gfx_translate(_ e: OpaquePointer?, _ x: Float, _ y: Float) {
    host.mat.mul(Mat(a: 1, b: 0, c: 0, d: 1, e: x, f: y))
}

@_cdecl("wamr_gfx_rotate")
func wamr_gfx_rotate(_ e: OpaquePointer?, _ degrees: Float) {
    let r = degrees * Float.pi / 180
    host.mat.mul(Mat(a: SDL_cosf(r), b: SDL_sinf(r), c: -SDL_sinf(r), d: SDL_cosf(r), e: 0, f: 0))
}

@_cdecl("wamr_gfx_scale")
func wamr_gfx_scale(_ e: OpaquePointer?, _ sx: Float, _ sy: Float) {
    host.mat.mul(Mat(a: sx, b: 0, c: 0, d: sy, e: 0, f: 0))
}

@_cdecl("wamr_gfx_set_alpha")
func wamr_gfx_set_alpha(_ e: OpaquePointer?, _ a: Float) { host.alpha = a }

@_cdecl("wamr_gfx_set_blend")
func wamr_gfx_set_blend(_ e: OpaquePointer?, _ mode: Int32) {}

@_cdecl("wamr_gfx_stroke_poly")
func wamr_gfx_stroke_poly(_ e: OpaquePointer?, _ xy: UnsafePointer<Float>?, _ n: Int32,
                          _ closed: Int32, _ t: Float, _ rgba: UInt32) {
    guard let xy, n >= 2 else { return }
    var pts = [SDL_FPoint]()
    pts.reserveCapacity(Int(n))
    for i in 0..<Int(n) { pts.append(host.mat.apply(xy[i * 2], xy[i * 2 + 1])) }
    host.strokePoly(pts, closed: closed != 0, thickness: t, rgba: rgba)
}

@_cdecl("wamr_gfx_fill_poly")
func wamr_gfx_fill_poly(_ e: OpaquePointer?, _ xy: UnsafePointer<Float>?, _ n: Int32, _ rgba: UInt32) {
    guard let xy, n >= 3 else { return }
    var pts = [SDL_FPoint]()
    pts.reserveCapacity(Int(n))
    for i in 0..<Int(n) { pts.append(host.mat.apply(xy[i * 2], xy[i * 2 + 1])) }
    host.fillPoly(pts, rgba: rgba)
}

@_cdecl("wamr_gfx_fill_circle")
func wamr_gfx_fill_circle(_ e: OpaquePointer?, _ cx: Float, _ cy: Float, _ r: Float, _ rgba: UInt32) {
    host.fillPoly(host.circlePts(cx, cy, r), rgba: rgba)
}

@_cdecl("wamr_gfx_stroke_circle")
func wamr_gfx_stroke_circle(_ e: OpaquePointer?, _ cx: Float, _ cy: Float, _ r: Float,
                            _ t: Float, _ rgba: UInt32) {
    host.strokePoly(host.circlePts(cx, cy, r), closed: true, thickness: t, rgba: rgba)
}

@_cdecl("wamr_gfx_fill_rect")
func wamr_gfx_fill_rect(_ e: OpaquePointer?, _ x: Float, _ y: Float, _ w: Float, _ h: Float, _ rgba: UInt32) {
    host.fillPoly([host.mat.apply(x, y), host.mat.apply(x + w, y),
                   host.mat.apply(x + w, y + h), host.mat.apply(x, y + h)], rgba: rgba)
}

@_cdecl("wamr_gfx_stroke_rect")
func wamr_gfx_stroke_rect(_ e: OpaquePointer?, _ x: Float, _ y: Float, _ w: Float, _ h: Float,
                          _ t: Float, _ rgba: UInt32) {
    host.strokePoly([host.mat.apply(x, y), host.mat.apply(x + w, y),
                     host.mat.apply(x + w, y + h), host.mat.apply(x, y + h)],
                    closed: true, thickness: t, rgba: rgba)
}

@_cdecl("wamr_evt_poll")
func wamr_evt_poll(_ e: OpaquePointer?,
                   _ type: UnsafeMutablePointer<Int32>?, _ a: UnsafeMutablePointer<Int32>?,
                   _ b: UnsafeMutablePointer<Int32>?, _ c: UnsafeMutablePointer<Int32>?,
                   _ d: UnsafeMutablePointer<Int32>?) -> Int32 {
    guard let ev = popEvent() else { return 0 }
    type?.pointee = ev.0
    a?.pointee = ev.1
    b?.pointee = ev.2
    c?.pointee = ev.3
    d?.pointee = ev.4
    return 1
}

@_cdecl("wamr_snd_by_name")
func wamr_snd_by_name(_ e: OpaquePointer?, _ name: UnsafePointer<CChar>?, _ len: Int32) -> Int32 {
    host.loadSound(host.cString(name, len))
}

@_cdecl("wamr_snd_play")
func wamr_snd_play(_ e: OpaquePointer?, _ buffer: Int32, _ volume: Float, _ loop: Int32) -> Int32 {
    host.play(buffer, volume: volume, loop: loop != 0)
}

@_cdecl("wamr_snd_stop")
func wamr_snd_stop(_ e: OpaquePointer?, _ voice: Int32) { host.stopVoice(voice) }

@_cdecl("wamr_snd_set_volume")
func wamr_snd_set_volume(_ e: OpaquePointer?, _ voice: Int32, _ volume: Float) {
    host.setVoiceVolume(voice, volume)
}

@_cdecl("wamr_snd_set_pan")
func wamr_snd_set_pan(_ e: OpaquePointer?, _ voice: Int32, _ pan: Float) {
    host.setVoicePan(voice, pan)
}

@_cdecl("wamr_store_get")
func wamr_store_get(_ e: OpaquePointer?, _ key: UnsafePointer<CChar>?, _ klen: Int32,
                    _ buf: UnsafeMutablePointer<CChar>?, _ cap: Int32) -> Int32 {
    guard let v = host.storeGet(host.cString(key, klen)) else { return -1 }
    let bytes = Array(v.utf8)
    let n = min(bytes.count, Int(cap))
    if let buf {
        for i in 0..<n { buf[i] = CChar(bitPattern: bytes[i]) }
    }
    return Int32(n)
}

@_cdecl("wamr_store_set")
func wamr_store_set(_ e: OpaquePointer?, _ key: UnsafePointer<CChar>?, _ klen: Int32,
                    _ val: UnsafePointer<CChar>?, _ vlen: Int32) {
    host.storeSet(host.cString(key, klen), host.cString(val, vlen))
}

@_cdecl("wamr_gp_connected")
func wamr_gp_connected(_ e: OpaquePointer?, _ pad: Int32) -> Int32 { 0 }


// SDL scancode -> SFML key code (the ABI's event vocabulary)
func sfKey(_ scancode: UInt32) -> Int32 {
    switch scancode {
    case UInt32(SDL_SCANCODE_LEFT.rawValue): return 71
    case UInt32(SDL_SCANCODE_RIGHT.rawValue): return 72
    case UInt32(SDL_SCANCODE_UP.rawValue): return 73
    case UInt32(SDL_SCANCODE_DOWN.rawValue): return 74
    case UInt32(SDL_SCANCODE_SPACE.rawValue): return 57
    case UInt32(SDL_SCANCODE_ESCAPE.rawValue): return 36
    case UInt32(SDL_SCANCODE_RETURN.rawValue): return 58
    case UInt32(SDL_SCANCODE_BACKSPACE.rawValue): return 59
    case UInt32(SDL_SCANCODE_TAB.rawValue): return 60
    case UInt32(SDL_SCANCODE_A.rawValue)...UInt32(SDL_SCANCODE_Z.rawValue):
        return Int32(scancode - UInt32(SDL_SCANCODE_A.rawValue))
    case UInt32(SDL_SCANCODE_1.rawValue)...UInt32(SDL_SCANCODE_9.rawValue):
        return Int32(27 + scancode - UInt32(SDL_SCANCODE_1.rawValue))
    case UInt32(SDL_SCANCODE_0.rawValue): return 26
    default: return -1
    }
}

func toLogical(_ window: OpaquePointer?, _ x: Float, _ y: Float) -> (Int32, Int32) {
    var w: Int32 = 0
    var h: Int32 = 0
    _ = SDL_GetWindowSize(window, &w, &h)
    let sc = min(Float(w) / LOGICAL_W, Float(h) / LOGICAL_H)
    let ox = (Float(w) - LOGICAL_W * sc) / 2
    let oy = (Float(h) - LOGICAL_H * sc) / 2
    return (Int32((x - ox) / sc), Int32((y - oy) / sc))
}

let windowResizable: UInt64 = 0x20
let windowHighPixelDensity: UInt64 = 0x2000

// MARK: - main

@main
enum Main {
    static func main() {
        var wasmPath = "game.wasm"
        if let p = ("CARTRIDGE_WASM".withCString { SDL_getenv($0) }) { wasmPath = String(cString: p) }
        var selftest: Float = 0
        if let s = ("CARTRIDGE_SELFTEST".withCString { SDL_getenv($0) }) { selftest = Float(SDL_strtod(s, nil)) }

        var dirBytes = Array(wasmPath.utf8)
        var slash = -1
        for (i, ch) in dirBytes.enumerated() where ch == 47 { slash = i }
        if slash >= 0 {
            dirBytes.removeSubrange((slash + 1)...)
        } else {
            dirBytes = []
        }
        dirBytes.append(0)
        let wasmDir = dirBytes.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        host.assetDir = wasmDir + "assets/sfx"
        host.storePath = wasmDir + ".native-store.tsv"
        host.loadStore()

        guard SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) else { fatalError("SDL_Init failed") }
        var window: OpaquePointer? = nil
        var renderer: OpaquePointer? = nil
        let ok = "WasmCart".withCString {
            SDL_CreateWindowAndRenderer($0, 1920, 1080,
                                        windowResizable | windowHighPixelDensity,
                                        &window, &renderer)
        }
        guard ok else { fatalError("SDL_CreateWindowAndRenderer failed") }
        _ = SDL_SetRenderVSync(renderer, 1)
        _ = SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)
        host.renderer = renderer

        // WAMR: init, register the env natives, load the cart, instantiate
        guard wasm_runtime_init() else { fatalError("wamr init failed") }
        guard kitRegisterNatives() else { fatalError("native registration failed") }

        var size = 0
        let wasmData = wasmPath.withCString { SDL_LoadFile($0, &size) }
        guard let wasmData else { fatalError("cartridge wasm not found") }
        var errBuf = [CChar](repeating: 0, count: 128)
        let module = errBuf.withUnsafeMutableBufferPointer { eb in
            wasm_runtime_load(wasmData.bindMemory(to: UInt8.self, capacity: size),
                              UInt32(size), eb.baseAddress, UInt32(eb.count))
        }
        guard let module else { fatalError("wasm load failed") }

        wasm_runtime_set_wasi_args(module, nil, 0, nil, 0, nil, 0, nil, 0)

        let instance = errBuf.withUnsafeMutableBufferPointer { eb in
            wasm_runtime_instantiate(module, 256 * 1024, 0, eb.baseAddress, UInt32(eb.count))
        }
        guard let instance else { fatalError("wasm instantiate failed") }

        let bound = 24
        let stubbed = 99 - bound
        print("WasmCart: \(bound) env fns live, \(stubbed) auto-stubbed")

        evtMutex = SDL_CreateMutex()

        // everything the game thread needs, hoisted
        struct GameCtx {
            var instance: wasm_module_inst_t?
            var renderer: OpaquePointer?
            var selftest: Float
        }
        let ctxBox = UnsafeMutablePointer<GameCtx>.allocate(capacity: 1)
        ctxBox.initialize(to: GameCtx(instance: instance, renderer: renderer,
                                      selftest: selftest))

        let gameThread = SDL_CreateThreadRuntime({ raw in
            let ctx = raw!.assumingMemoryBound(to: GameCtx.self)
            // WAMR requires explicit thread-env registration off the main thread
            _ = wasm_runtime_init_thread_env()
            let inst = ctx.pointee.instance
            guard let exec = wasm_runtime_create_exec_env(inst, 256 * 1024) else {
                SDL_SetAtomicInt(&runFlag, 0)
                return 1
            }
            // reactor start: _initialize then boot, on THIS thread
            if let initFn = "_initialize".withCString({ wasm_runtime_lookup_function(inst, $0) }) {
                _ = wasm_runtime_call_wasm(exec, initFn, 0, nil)
            }
            guard let bootFn = "boot".withCString({ wasm_runtime_lookup_function(inst, $0) }),
                  let frameFn = "frame".withCString({ wasm_runtime_lookup_function(inst, $0) }) else {
                SDL_SetAtomicInt(&runFlag, 0)
                return 1
            }
            _ = wasm_runtime_call_wasm(exec, bootFn, 0, nil)
            if let ex = wasm_runtime_get_exception(inst) {
                print("boot trapped: " + String(cString: ex))
                SDL_SetAtomicInt(&runFlag, 0)
            }

            var last = SDL_GetTicksNS()
            var elapsedMs: Float = 0
            var frames = 0
            var sentStart = false
            var sentThrust = false
            while SDL_GetAtomicInt(&runFlag) == 1 {
                let now = SDL_GetTicksNS()
                var dt = Float(now - last) / 1_000_000
                last = now
                if dt > 50 { dt = 50 }

                var arg = wasm_val_t()
                arg.kind = wasm_valkind_t(WASM_F64.rawValue)
                arg.of.f64 = Double(dt)
                _ = wasm_runtime_call_wasm_a(exec, frameFn, 0, nil, 1, &arg)
                if let ex = wasm_runtime_get_exception(inst) {
                    print("frame trapped: " + String(cString: ex))
                    SDL_SetAtomicInt(&runFlag, 0)
                }
                host.reapVoices()
                _ = SDL_RenderPresent(ctx.pointee.renderer)

                frames += 1
                elapsedMs += dt
                let st = ctx.pointee.selftest
                if st > 0 {
                    if elapsedMs >= 1000, !sentStart {
                        sentStart = true
                        pushEvent((5, 57, 0, 0, 0))
                        pushEvent((6, 57, 0, 0, 0))
                    }
                    if elapsedMs >= 2000, !sentThrust {
                        sentThrust = true
                        pushEvent((5, 73, 0, 0, 0))
                    }
                    if elapsedMs >= st * 1000 {
                        if let surf = SDL_RenderReadPixels(ctx.pointee.renderer, nil) {
                            _ = "native-selftest.bmp".withCString { SDL_SaveBMP(surf, $0) }
                            SDL_DestroySurface(surf)
                        }
                        print("selftest: \(frames) frames, \(host.drawCalls) draw calls -> native-selftest.bmp")
                        SDL_SetAtomicInt(&runFlag, 0)
                    }
                }

                let used = SDL_GetTicksNS() - now
                if used < 16_666_666 { SDL_DelayNS(16_666_666 - used) }
            }
            wasm_runtime_destroy_exec_env(exec)
            wasm_runtime_destroy_thread_env()
            return 0
                }, "game", UnsafeMutableRawPointer(ctxBox), nil, nil)

        // main thread: nothing but the OS event pump. Menus and drags can
        // block here all they like; the game thread never notices.
        var fullscreen = false
        while SDL_GetAtomicInt(&runFlag) == 1 {
            var e = SDL_Event()
            while SDL_WaitEventTimeout(&e, 100) {
                if e.type == SDL_EVENT_QUIT.rawValue {
                    SDL_SetAtomicInt(&runFlag, 0)
                } else if e.type == SDL_EVENT_KEY_DOWN.rawValue, e.key.scancode == SDL_SCANCODE_F, !e.key.`repeat` {
                    fullscreen = !fullscreen
                    _ = SDL_SetWindowFullscreen(window, fullscreen)
                } else if e.type == SDL_EVENT_KEY_DOWN.rawValue || e.type == SDL_EVENT_KEY_UP.rawValue {
                    let sf = sfKey(e.key.scancode.rawValue)
                    if sf >= 0, !e.key.`repeat` {
                        let t: Int32 = e.type == SDL_EVENT_KEY_DOWN.rawValue ? 5 : 6
                        let shift: Int32 = (UInt32(e.key.mod) & SDL_KMOD_SHIFT) != 0 ? 1 : 0
                        pushEvent((t, sf, shift, 0, 0))
                    }
                } else if e.type == SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue || e.type == SDL_EVENT_MOUSE_BUTTON_UP.rawValue {
                    let t: Int32 = e.type == SDL_EVENT_MOUSE_BUTTON_DOWN.rawValue ? 9 : 10
                    let (lx, ly) = toLogical(window, e.button.x, e.button.y)
                    pushEvent((t, 0, lx, ly, 0))
                } else if e.type == SDL_EVENT_MOUSE_MOTION.rawValue {
                    let (lx, ly) = toLogical(window, e.motion.x, e.motion.y)
                    pushEvent((11, lx, ly, 0, 0))
                }
                if SDL_GetAtomicInt(&runFlag) == 0 { break }
            }
        }

        var threadStatus: Int32 = 0
        SDL_WaitThread(gameThread, &threadStatus)
        ctxBox.deallocate()

        SDL_Quit()
    }
}
