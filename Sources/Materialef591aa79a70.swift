import CryptoKit
import Foundation

enum EncodedMaterialc6be593b652c {
    static let pieces: [[UInt8]] = [[40, 236, 23, 75], [233, 117, 103, 120, 77, 240], [192, 255, 53, 201, 153, 21, 166, 219, 38, 65, 234, 242, 39, 12, 194, 169, 28, 189, 7, 157, 228, 46]]
    static let layout: [Int] = [0, 2, 1]

    static func key() -> SymmetricKey {
        let ordered = zip(layout, pieces).sorted { $0.0 < $1.0 }
        var bytes = ordered.flatMap { $0.1 }
        for index in bytes.indices { bytes[index] = bytes[index] ^ 98 }
        for index in bytes.indices { bytes[index] = (bytes[index] >> 4) | (bytes[index] << 4) }
        for index in bytes.indices { bytes[index] = bytes[index] &- 148 }
        return SymmetricKey(data: Data(bytes))
    }
}
