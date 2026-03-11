import CryptoKit
import Darwin
import Foundation

extension ClipboardTransform {
    // MARK: - Base64

    nonisolated static func base64Encode(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
    }

    nonisolated static func base64Decode(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters),
              let decoded = String(data: data, encoding: .utf8) else { return s }
        return decoded
    }

    // MARK: - Checksums

    nonisolated static func md5Checksum(_ s: String) -> String {
        Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    nonisolated static func sha1Checksum(_ s: String) -> String {
        Insecure.SHA1.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    nonisolated static func sha256Checksum(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    nonisolated static func sha512Checksum(_ s: String) -> String {
        SHA512.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    private nonisolated static func argon2ParamsFromUserDefaults() -> (memoryKiB: Int, iterations: Int, parallelism: Int) {
        let ud = UserDefaults.standard
        let m = ud.integer(forKey: "Argon2MemoryKiB")
        let t = ud.integer(forKey: "Argon2Iterations")
        let p = ud.integer(forKey: "Argon2Parallelism")
        return Argon2Params.sanitized(memoryKiB: m, iterations: t, parallelism: p)
    }

    nonisolated static func argon2idHash(_ s: String) -> String? {
        let password = Data(s.utf8)
        let (m, t, p) = argon2ParamsFromUserDefaults()
        return Argon2PHC.hash(password: password, memoryKiB: m, iterations: t, parallelism: p, tagLength: 32)
    }

    nonisolated static func bcryptHash(_ s: String) -> String? {
        let cost = 12
        let salt = "$2b$\(String(format: "%02d", cost))$\(bcryptRandomSaltBody(length: 22))"
        guard let out = crypt(s, salt) else { return nil }
        return String(cString: out)
    }

    private nonisolated static func bcryptRandomSaltBody(length: Int) -> String {
        let alphabet = Array("./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return (0..<length).map { _ in
            let idx = Int(arc4random_uniform(UInt32(alphabet.count)))
            return String(alphabet[idx])
        }.joined()
    }

    // MARK: - Base64URL

    nonisolated static func base64URLEncode(_ s: String) -> String {
        base64URLEncodeData(Data(s.utf8))
    }

    private nonisolated static func base64URLEncodeData(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated static func base64URLDecode(_ s: String) -> String {
        var base64 = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = base64.count % 4
        if pad == 2 { base64 += "==" } else if pad == 3 { base64 += "=" }
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let decoded = String(data: data, encoding: .utf8) else { return s }
        return decoded
    }

    // MARK: - CRC32

    nonisolated static func crc32(_ s: String) -> String {
        String(format: "%08x", CRC32B.hash(Data(s.utf8)))
    }

    // MARK: - JWT

    nonisolated static func jwtEncode(_ s: String) -> String? {
        let header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"
        let payload = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return nil }
        let h = base64URLEncode(header)
        let p = base64URLEncode(payload)
        let unsigned = h + "." + p
        let digest = SHA256.hash(data: Data(unsigned.utf8))
        let sig = base64URLEncodeData(Data(digest))
        return unsigned + "." + sig
    }

    nonisolated static func jwtDecode(_ s: String) -> String? {
        let parts = s.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        let payloadPart = String(parts[1])
        let decoded = base64URLDecode(payloadPart)
        guard let data = decoded.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let out = String(data: pretty, encoding: .utf8) else { return decoded }
        return out
    }
}

enum CRC32B {
    private nonisolated static let table: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) == 1 ? (c >> 1) ^ 0xEDB88320 : (c >> 1)
        }
        return c
    }

    nonisolated static func hash(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}
