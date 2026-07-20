import CryptoKit
import Foundation

public enum CredentialEnvelope6026732dc416 {
    public static func reveal() throws -> String {
        let nonce = try AES.GCM.Nonce(data: Data([48, 95, 77, 93, 108, 50, 35, 132, 18, 240, 38, 174]))
        let box = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: Data([93, 94, 157, 239, 126, 194, 78, 9, 66, 62, 138, 162, 98, 17, 86, 97, 72, 235, 61, 145, 233, 197, 206, 224, 147, 140, 232, 184, 68, 56, 188, 249, 41, 225, 137, 17, 253, 135, 189, 189, 223, 220, 151, 82, 116, 231, 19, 234, 140, 173, 82, 35, 252, 100, 139, 224, 15, 1, 26, 166, 164, 33, 218, 251, 162, 93, 150, 91, 51, 127, 117, 139]),
            tag: Data([76, 220, 222, 50, 112, 154, 214, 142, 26, 2, 49, 126, 215, 210, 170, 221]))
        let clear = try AES.GCM.open(box, using: EncodedMaterialc6be593b652c.key())
        guard let value = String(data: clear, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return value
    }
}
