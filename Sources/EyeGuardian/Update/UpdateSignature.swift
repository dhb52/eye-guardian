import CryptoKit
import Foundation

enum UpdateSignature {
    static func publicKey(from base64: String) -> Curve25519.Signing.PublicKey? {
        guard let data = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return try? Curve25519.Signing.PublicKey(rawRepresentation: data)
    }

    static func verify(fileURL: URL, signatureBase64: String, publicKeyBase64: String) throws {
        guard let key = publicKey(from: publicKeyBase64) else {
            throw UpdateError.invalidPublicKey
        }
        guard let signature = Data(base64Encoded: signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw UpdateError.invalidSignature
        }
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        guard key.isValidSignature(signature, for: data) else {
            throw UpdateError.signatureMismatch
        }
    }

    static func sha256(fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return sha256(data: data)
    }

    static func sha256(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
