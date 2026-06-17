// The console shell, built with SuperBox64Kit itself: a real SKScene with
// vector lettering, exactly like the games it hosts (permutation 3).
// Lists the carts folder (WASMCART_CARTS env, else carts/ beside the binary,
// else carts/ under the working directory) as a pick-and-play menu.
import SpriteKit
import CSDL3

final class ShellScene: SKScene {
    private let lines = SKNode()
    private var pulse: CGFloat = 0
    private var carts: [String] = []
    private var cartNames: [String] = []
    private var selected = 0
    private var rowRects: [CGRect] = []
    private var dialogRect = CGRect.zero
    private var emojiRect = CGRect.zero
    private var rescanCountdown = 0

    private let emojiModeNames = ["APPLE", "PNG", "NOTO"]
    private var emojiMode: Int32 {
        get { Kit.shared.emojiMode }
        set {
            Kit.shared.setEmojiMode(newValue)
            Kit.shared.storeSet("WasmCart.emojiMode", "\(newValue)")
            Kit.shared.saveStore()
        }
    }
    private func cycleEmojiMode() {
        emojiMode = (emojiMode + 1) % Int32(emojiModeNames.count)
        buildUI()
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        addChild(lines)
        scanCarts()
        buildUI()
    }

    // Vector text in one solid color (frog-green by default) at the given
    // brightness — solid, bright and readable. The WASMCART hero label and its
    // slot border are the exception: they get a Cylon rainbow sweep recolored
    // per-frame in update(), not a static hue.
    private func vectorText(_ text: String, at pos: CGPoint, scale: CGFloat, alpha: CGFloat,
                            color: SKColor = .green) {
        let node = ShellFont.draw(text, lineWidth: 1 / scale, color: color)
        node.position = pos
        node.setScale(scale)
        node.alpha = alpha
        lines.addChild(node)
    }

    // Full-saturation, full-brightness SKColor at the given hue (0..1 around the
    // wheel) — the palette for the WASMCART Cylon rainbow sweep. The kit's
    // SKColor is a plain RGBA value type with no HSV init, so fold hue → RGB.
    private func rainbowColor(_ hue: CGFloat, alpha: CGFloat) -> SKColor {
        let h = hue.truncatingRemainder(dividingBy: 1.0)
        let sector = h * 6.0
        var i = Int(sector)
        if i < 0 { i = 0 } else if i > 5 { i = 5 }
        let f = sector - CGFloat(i)
        switch i {
        case 0:  return SKColor(red: 1.0,      green: f,        blue: 0.0,      alpha: alpha)
        case 1:  return SKColor(red: 1.0 - f,  green: 1.0,      blue: 0.0,      alpha: alpha)
        case 2:  return SKColor(red: 0.0,      green: 1.0,      blue: f,        alpha: alpha)
        case 3:  return SKColor(red: 0.0,      green: 1.0 - f,  blue: 1.0,      alpha: alpha)
        case 4:  return SKColor(red: f,        green: 0.0,      blue: 1.0,      alpha: alpha)
        default: return SKColor(red: 1.0,      green: 0.0,      blue: 1.0 - f,  alpha: alpha)
        }
    }

    private func cartsDirectory() -> String? {
        if let env = ("WASMCART_CARTS".withCString { SDL_getenv($0) }) {
            return String(cString: env)
        }
        var info = SDL_PathInfo()
        if let base = SDL_GetBasePath() {
            let p = String(cString: base) + "carts"
            if p.withCString({ SDL_GetPathInfo($0, &info) }) { return p }
        }
        if let cwd = SDL_GetCurrentDirectory() {
            var p = String(cString: cwd)
            SDL_free(cwd)
            if !p.hasSuffix("/") { p += "/" }
            p += "carts"
            if p.withCString({ SDL_GetPathInfo($0, &info) }) { return p }
        }
        return nil
    }

    private func scanCarts() {
        carts = []
        cartNames = []
        guard let dir = cartsDirectory() else { return }
        var count: Int32 = 0
        guard let list = dir.withCString({ SDL_GlobDirectory($0, nil, 0, &count) }) else { return }
        for i in 0..<Int(count) {
            guard let entry = list[i] else { continue }
            let name = String(cString: entry)
            guard name.hasSuffix(".zip") || name.hasSuffix(".wasm") || name.hasSuffix(".aot") else { continue }
            guard !name.hasPrefix(".") else { continue }
            carts.append(dir + "/" + name)
            cartNames.append(ShellFont.displayName(name))
        }
        SDL_free(UnsafeMutableRawPointer(list))
        for i in 1..<max(1, carts.count) {
            var j = i
            while j > 0, cartNames[j - 1] > cartNames[j] {
                cartNames.swapAt(j - 1, j)
                carts.swapAt(j - 1, j)
                j -= 1
            }
        }
        if selected >= carts.count { selected = max(0, carts.count - 1) }
    }

    private func buildUI() {
        lines.removeAllChildren()
        rowRects = []

        // the slot, wearing the console's name as its cartridge label. Its border
        // is recolored each frame by the Cylon rainbow sweep (update()).
        let slotY = size.height * 0.72
        let slot = SKShapeNode(rect: CGRect(x: size.width / 2 - 280, y: slotY, width: 560, height: 100))
        slot.strokeColor = SKColor.green
        slot.lineWidth = 1
        slot.name = "slot"
        lines.addChild(slot)
        // the hero label: recolored each frame by the Cylon rainbow sweep (update()).
        let slotLabel = ShellFont.draw("WASMCART", lineWidth: 1 / 3.4, color: .green)
        slotLabel.position = CGPoint(x: size.width / 2, y: slotY + 50)
        slotLabel.setScale(3.4)
        slotLabel.alpha = 0.625
        slotLabel.name = "slotlabel"
        lines.addChild(slotLabel)

        let rowH = size.height * 0.045
        var y = size.height * 0.58
        if carts.isEmpty {
            vectorText("NO CARTS FOUND", at: CGPoint(x: size.width / 2, y: y), scale: 1.2, alpha: 0.7)
            y -= rowH
        } else {
            vectorText("CARTS", at: CGPoint(x: size.width / 2, y: y), scale: 1.2, alpha: 0.6)
            y -= rowH
            for (i, name) in cartNames.enumerated() {
                let alpha: CGFloat = i == selected ? 1.0 : 0.6
                vectorText(name, at: CGPoint(x: size.width / 2, y: y), scale: 1.2, alpha: alpha)
                let rect = CGRect(x: size.width / 2 - 480, y: y - rowH / 2, width: 960, height: rowH)
                rowRects.append(rect)
                if i == selected {
                    let box = SKShapeNode(rect: CGRect(x: size.width / 2 - 360, y: y - rowH / 2 + 4,
                                                       width: 720, height: rowH - 8))
                    // a brighter lime-green frame so the pick stands out from the
                    // green text without leaving the green family.
                    box.strokeColor = SKColor(red: 0.55, green: 1.0, blue: 0.3, alpha: 0.9)
                    box.lineWidth = 1
                    lines.addChild(box)
                }
                y -= rowH
            }
        }

        y -= rowH * 0.4
        vectorText("OPEN FILE", at: CGPoint(x: size.width / 2, y: y), scale: 1.0, alpha: 0.7)
        dialogRect = CGRect(x: size.width / 2 - 240, y: y - rowH / 2, width: 480, height: rowH)

        y -= rowH
        let mode = emojiModeNames[Int(emojiMode) % emojiModeNames.count]
        vectorText("EMOJI: " + mode, at: CGPoint(x: size.width / 2, y: y), scale: 1.0, alpha: 0.7)
        emojiRect = CGRect(x: size.width / 2 - 240, y: y - rowH / 2, width: 480, height: rowH)

        vectorText("ARROWS SELECT  ENTER OR DOUBLE CLICK LOADS  DROP A WASM ANYTIME",
                   at: CGPoint(x: size.width / 2, y: size.height * 0.10), scale: 0.9, alpha: 0.55)
        vectorText("CLICK EMOJI TO SWITCH MODE   CTRL ESC EJECTS",
                   at: CGPoint(x: size.width / 2, y: size.height * 0.06), scale: 0.9, alpha: 0.55)
    }

    private func loadSelected() {
        guard selected >= 0, selected < carts.count else { return }
        insertCart(carts[selected])
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 126:
            if !carts.isEmpty {
                selected = (selected + carts.count - 1) % carts.count
                buildUI()
            }
        case 125:
            if !carts.isEmpty {
                selected = (selected + 1) % carts.count
                buildUI()
            }
        case 36, 49:
            if carts.isEmpty {
                SDL_SetAtomicInt(&wantDialog, 1)
            } else {
                loadSelected()
            }
        case 14:                       // E cycles the emoji mode
            cycleEmojiMode()
        default:
            break
        }
    }

    // single click selects, a real OS double click loads (rows and OPEN FILE)
    override func mouseDown(with event: NSEvent) {
        let p = event.location(in: self)
        if emojiRect.contains(p) {
            cycleEmojiMode()
            return
        }
        for (i, rect) in rowRects.enumerated() where rect.contains(p) {
            if event.clickCount >= 2, selected == i {
                loadSelected()
            } else {
                selected = i
                buildUI()
            }
            return
        }
        if dialogRect.contains(p) || carts.isEmpty {
            if event.clickCount >= 2 {
                SDL_SetAtomicInt(&wantDialog, 1)
            }
        }
    }

    override func update(_ currentTime: TimeInterval) {
        pulse += 0.03
        // Cylon/KITT rainbow sweep across the WASMCART border and its letters.
        // `sweep` is a triangle wave 0→1→0 (~2s per back-and-forth at 60fps), so the
        // color scan reverses at each end like a Cylon scanner.
        let saw = (pulse * 0.5).truncatingRemainder(dividingBy: 2.0)
        let sweep = 1.0 - abs(saw - 1.0)
        // the slot border rides the leading edge of the scan through the hue wheel,
        // glowing a little as it goes.
        let borderGlow = 0.7 + 0.25 * abs(CGFloat(SDL_sinf(Float(pulse))))
        for child in lines.children where child.name == "slot" {
            (child as? SKShapeNode)?.strokeColor = rainbowColor(sweep, alpha: borderGlow)
        }
        // each letter holds its own hue, offset by its place in the word, so the
        // whole rainbow travels across WASMCART and bounces back; the word keeps a
        // gentle brightness shimmer so it stays readable.
        let shimmer = 0.82 + 0.13 * abs(CGFloat(SDL_sinf(Float(pulse))))
        for child in lines.children where child.name == "slotlabel" {
            child.alpha = shimmer
            let glyphs = child.children
            let n = CGFloat(max(1, glyphs.count))
            for (i, g) in glyphs.enumerated() {
                let frac = CGFloat(i) / n
                let hue = (frac + sweep).truncatingRemainder(dividingBy: 1.0)
                (g as? SKShapeNode)?.strokeColor = rainbowColor(hue, alpha: 1.0)
            }
        }
        rescanCountdown -= 1
        if rescanCountdown <= 0 {
            rescanCountdown = 180
            let before = carts
            scanCarts()
            if before != carts { buildUI() }
        }
    }
}

// A tiny segment font for the shell (A-Z, 0-9, space, dash, dot). Each glyph
// is a set of line segments in a 10x14 box.
enum ShellFont {
    static let strokes: [Character: [[CGFloat]]] = [
        "A": [[0,0,5,14],[5,14,10,0],[2,5,8,5]],
        "B": [[0,0,0,14],[0,14,8,14],[8,14,8,8],[8,8,0,8],[0,8,9,8],[9,8,9,0],[9,0,0,0]],
        "C": [[10,0,0,0],[0,0,0,14],[0,14,10,14]],
        "D": [[0,0,0,14],[0,14,7,14],[7,14,10,10],[10,10,10,4],[10,4,7,0],[7,0,0,0]],
        "E": [[10,0,0,0],[0,0,0,14],[0,14,10,14],[0,7,7,7]],
        "F": [[0,0,0,14],[0,14,10,14],[0,7,7,7]],
        "G": [[10,14,0,14],[0,14,0,0],[0,0,10,0],[10,0,10,6],[10,6,5,6]],
        "H": [[0,0,0,14],[10,0,10,14],[0,7,10,7]],
        "I": [[5,0,5,14],[2,0,8,0],[2,14,8,14]],
        "J": [[10,14,10,3],[10,3,7,0],[7,0,3,0],[3,0,0,3]],
        "K": [[0,0,0,14],[10,14,0,7],[0,7,10,0]],
        "L": [[0,14,0,0],[0,0,10,0]],
        "M": [[0,0,0,14],[0,14,5,8],[5,8,10,14],[10,14,10,0]],
        "N": [[0,0,0,14],[0,14,10,0],[10,0,10,14]],
        "O": [[0,0,0,14],[0,14,10,14],[10,14,10,0],[10,0,0,0]],
        "P": [[0,0,0,14],[0,14,10,14],[10,14,10,8],[10,8,0,8]],
        "Q": [[0,0,0,14],[0,14,10,14],[10,14,10,3],[10,3,7,0],[7,0,0,0],[6,4,10,0]],
        "R": [[0,0,0,14],[0,14,10,14],[10,14,10,8],[10,8,0,8],[3,8,10,0]],
        "S": [[10,14,0,14],[0,14,0,8],[0,8,10,8],[10,8,10,0],[10,0,0,0]],
        "T": [[0,14,10,14],[5,14,5,0]],
        "U": [[0,14,0,0],[0,0,10,0],[10,0,10,14]],
        "V": [[0,14,5,0],[5,0,10,14]],
        "W": [[0,14,2,0],[2,0,5,6],[5,6,8,0],[8,0,10,14]],
        "X": [[0,0,10,14],[0,14,10,0]],
        "Y": [[0,14,5,7],[10,14,5,7],[5,7,5,0]],
        "Z": [[0,14,10,14],[10,14,0,0],[0,0,10,0]],
        "0": [[0,0,0,14],[0,14,10,14],[10,14,10,0],[10,0,0,0],[0,0,10,14]],
        "1": [[3,11,5,14],[5,14,5,0],[2,0,8,0]],
        "2": [[0,14,10,14],[10,14,10,8],[10,8,0,8],[0,8,0,0],[0,0,10,0]],
        "3": [[0,14,10,14],[10,14,10,0],[10,0,0,0],[2,8,10,8]],
        "4": [[0,14,0,8],[0,8,10,8],[10,14,10,0]],
        "5": [[10,14,0,14],[0,14,0,8],[0,8,10,8],[10,8,10,0],[10,0,0,0]],
        "6": [[10,14,0,14],[0,14,0,0],[0,0,10,0],[10,0,10,8],[10,8,0,8]],
        "7": [[0,14,10,14],[10,14,5,0]],
        "8": [[0,0,0,14],[0,14,10,14],[10,14,10,0],[10,0,0,0],[0,8,10,8]],
        "9": [[10,0,10,14],[10,14,0,14],[0,14,0,8],[0,8,10,8]],
        "-": [[2,7,8,7]],
        ".": [[4,0,6,0],[6,0,6,2],[6,2,4,2],[4,2,4,0]],
    ]

    // Filename -> menu label: extension dropped, uppercased, characters the
    // segment font lacks become spaces
    static func displayName(_ file: String) -> String {
        var bytes = Array(file.utf8)
        if let dot = bytes.lastIndex(of: 46) { bytes.removeSubrange(dot...) }
        var out = [UInt8]()
        out.reserveCapacity(bytes.count + 1)
        for b in bytes {
            if b >= 97, b <= 122 {
                out.append(b - 32)
            } else if (b >= 65 && b <= 90) || (b >= 48 && b <= 57) || b == 45 || b == 46 || b == 32 {
                out.append(b)
            } else {
                out.append(32)
            }
        }
        out.append(0)
        return out.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    // lineWidth is in the glyph's own (unscaled) space; callers that scale the
    // returned node pass 1/scale so every stroke renders a true 1px on screen.
    static func draw(_ text: String, lineWidth: CGFloat = 1, color: SKColor = .white) -> SKNode {
        let node = SKNode()
        let advance: CGFloat = 14
        let width = CGFloat(text.count) * advance
        var x = -width / 2
        for ch in text {
            if let segs = strokes[ch] {
                let path = CGMutablePath()
                for s in segs {
                    path.move(to: CGPoint(x: s[0], y: s[1]))
                    path.addLine(to: CGPoint(x: s[2], y: s[3]))
                }
                let glyph = SKShapeNode(path: path)
                glyph.strokeColor = color
                glyph.lineWidth = lineWidth
                glyph.position = CGPoint(x: x, y: -7)
                node.addChild(glyph)
            }
            x += advance
        }
        return node
    }
}
