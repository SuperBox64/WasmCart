import SpriteKit
import CSDL3
import CWamr
import CZip
import KitABI

public struct WasmCart {
    public init() {
    }
}

public func loadAssetFromZip(_ archive: OpaquePointer, _ name: String) -> [UInt8]? {
    guard let file = zip_fopen(archive, name) else { return nil }
    defer { zip_fclose(file) }

    var data = [UInt8]()
    var buf = [UInt8](repeating: 0, count: 65536)
    while true {
        let read = zip_fread(&buf, buf.count, file)
        if read == 0 { break }
        data.append(contentsOf: buf[0..<read])
    }
    return data.isEmpty ? nil : data
}
