import CryptoKit
import Darwin
import Foundation

private func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

private func readFile(_ path: String) -> Data {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) else {
        fail("cannot read \(path)")
    }
    return data
}

private func keyFromEnvironment() -> Curve25519.Signing.PrivateKey {
    guard let value = ProcessInfo.processInfo.environment["UPDATE_SIGNING_KEY"],
          let data = Data(base64Encoded: value.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) else {
        fail("UPDATE_SIGNING_KEY is missing or invalid")
    }
    return key
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    fail("usage: update-key.swift <generate|sign|verify> ...")
}

switch arguments[1] {
case "generate":
    let key = Curve25519.Signing.PrivateKey()
    print("private=\(key.rawRepresentation.base64EncodedString())")
    print("public=\(key.publicKey.rawRepresentation.base64EncodedString())")

case "sign":
    guard arguments.count == 3 else {
        fail("usage: update-key.swift sign <file>")
    }
    let data = readFile(arguments[2])
    let signature = try! keyFromEnvironment().signature(for: data)
    print(signature.base64EncodedString())

case "verify":
    guard arguments.count == 5 else {
        fail("usage: update-key.swift verify <file> <signature-base64> <public-key-base64>")
    }
    guard let signature = Data(base64Encoded: arguments[3].trimmingCharacters(in: .whitespacesAndNewlines)) else {
        fail("invalid signature")
    }
    guard let publicData = Data(base64Encoded: arguments[4].trimmingCharacters(in: .whitespacesAndNewlines)),
          let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicData) else {
        fail("invalid public key")
    }
    guard publicKey.isValidSignature(signature, for: readFile(arguments[2])) else {
        fail("signature mismatch")
    }
    print("ok")

default:
    fail("usage: update-key.swift <generate|sign|verify> ...")
}
