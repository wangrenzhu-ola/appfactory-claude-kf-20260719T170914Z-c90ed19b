import CryptoKit
import Foundation

public struct CodingServiceClient8aa8c47de832 {
    public struct Completion: Encodable {
        public let requestIdentity: String
        public let content: String
        public let resultSHA256: String

        enum CodingKeys: String, CodingKey {
            case requestIdentity = "request_identity"
            case content
            case resultSHA256 = "result_sha256"
        }
    }

    public init() {}

    public func complete(_ prompt: String) async throws -> String {
        try await completeWithEvidence(prompt).content
    }

    public func completeWithEvidence(_ prompt: String) async throws -> Completion {
        let nonce = try AES.GCM.Nonce(data: Data([1, 42, 162, 224, 96, 21, 159, 129, 60, 98, 233, 12]))
        let box = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: Data([237, 183, 234, 203, 249, 151, 147, 224, 241, 226, 109, 175, 135, 45, 30, 15, 82, 54, 237, 24, 187, 223, 170, 41, 190, 243, 52, 233, 200, 232, 243, 148, 116, 56, 210, 112, 127, 52, 174, 90, 233, 7, 104, 181, 43, 253, 95, 123, 230, 9, 86, 77, 101, 114, 244, 37, 139, 246, 126, 28, 44, 253, 50, 121, 83, 236, 188, 150, 22, 124, 57]),
            tag: Data([157, 254, 79, 131, 246, 125, 198, 175, 203, 164, 162, 233, 164, 213, 221, 219]))
        let clear = try AES.GCM.open(box, using: EncodedMaterialc6be593b652c.key())
        let configuration = try JSONDecoder().decode(Configuration.self, from: clear)
        guard let base = URL(string: configuration.baseURL),
              let url = URL(string: "chat/completions", relativeTo: base) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        let requestIdentity = UUID().uuidString.lowercased()
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(requestIdentity, forHTTPHeaderField: "X-Request-ID")
        request.setValue("Bearer \(try CredentialEnvelope6026732dc416.reveal())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: configuration.model,
            messages: [Message(role: "user", content: prompt)]))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let content = try JSONDecoder().decode(ResponseBody.self, from: data).choices[0].message.content
        let resultSHA256 = SHA256.hash(data: Data(content.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return Completion(
            requestIdentity: requestIdentity,
            content: content,
            resultSHA256: resultSHA256)
    }

    private struct Configuration: Decodable { let baseURL: String; let model: String }
    private struct Message: Codable { let role: String; let content: String }
    private struct RequestBody: Encodable { let model: String; let messages: [Message] }
    private struct ResponseBody: Decodable { let choices: [Choice] }
    private struct ResponseMessage: Decodable { let content: String }
    private struct Choice: Decodable { let message: ResponseMessage }
}
