// The console shell, built with SuperBox64Kit itself: a real SKScene with
// vector lettering, exactly like the games it hosts (permutation 3).
import SpriteKit
import CSDL3

final class ShellScene: SKScene {
    private let lines = SKNode()
    private var pulse: CGFloat = 0

    override func didMove(to view: SKView) {
        backgroundColor = .black
        addChild(lines)
        buildUI()
    }

    private func vectorText(_ text: String, at pos: CGPoint, scale: CGFloat, alpha: CGFloat) {
        let node = ShellFont.draw(text)
        node.position = pos
        node.setScale(scale)
        node.alpha = alpha
        lines.addChild(node)
    }

    private func buildUI() {
        lines.removeAllChildren()
        vectorText("WASMCART", at: CGPoint(x: size.width / 2, y: size.height * 0.62), scale: 3.4, alpha: 0.85)

        // the slot
        let slot = SKShapeNode(rect: CGRect(x: size.width / 2 - 240, y: size.height * 0.42, width: 480, height: 90))
        slot.strokeColor = SKColor(white: 1, alpha: 0.6)
        slot.lineWidth = 2
        slot.name = "slot"
        lines.addChild(slot)
        let notch = SKShapeNode(rect: CGRect(x: size.width / 2 - 80, y: size.height * 0.42 + 34, width: 160, height: 22))
        notch.fillColor = SKColor(white: 1, alpha: 0.25)
        notch.strokeColor = .clear
        notch.name = "notch"
        lines.addChild(notch)

        vectorText("INSERT CARTRIDGE", at: CGPoint(x: size.width / 2, y: size.height * 0.33), scale: 1.6, alpha: 0.75)
        vectorText("CLICK OR DROP A WASM TO LOAD", at: CGPoint(x: size.width / 2, y: size.height * 0.26), scale: 1.0, alpha: 0.6)
        vectorText("ESC EJECTS", at: CGPoint(x: size.width / 2, y: size.height * 0.21), scale: 1.0, alpha: 0.6)
    }

    override func mouseDown(with event: NSEvent) {
        print("DEBUG: shellscene click detected")
        SDL_SetAtomicInt(&wantDialog, 1)
    }

    override func update(_ currentTime: TimeInterval) {
        pulse += 0.03
        let glow = 0.45 + 0.25 * abs(CGFloat(SDL_sinf(Float(pulse))))
        for child in lines.children where child.name == "slot" {
            (child as? SKShapeNode)?.strokeColor = SKColor(white: 1, alpha: glow)
        }
    }
}

// A tiny segment font for the shell (A-Z, 0-9, space). Each glyph is a set
// of line segments in a 10x14 box.
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
    ]

    static func draw(_ text: String) -> SKNode {
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
                glyph.strokeColor = .white
                glyph.lineWidth = 1.2
                glyph.position = CGPoint(x: x, y: -7)
                node.addChild(glyph)
            }
            x += advance
        }
        return node
    }
}
