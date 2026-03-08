// Swift wrapper around phc-winner-argon2 (https://github.com/P-H-C/phc-winner-argon2).
// Uses the reference C implementation for fast, well-tested Argon2id hashing.
// Configuration (memory, iterations, parallelism) is applied by callers; see README.

import Foundation
import argon2

enum Argon2PHC {
    /// Hash password with Argon2id using phc-winner-argon2. Salt is random 16 bytes unless provided.
    /// Returns PHC-format encoded string or nil on failure.
    /// Parameters should be sanitized (e.g. via Argon2Params.sanitized) and match README defaults.
    nonisolated static func hash(
        password: Data,
        salt: Data? = nil,
        memoryKiB: Int = 65535,
        iterations: Int = 3,
        parallelism: Int = 1,
        tagLength: Int = 32
    ) -> String? {
        let saltBytes = salt ?? randomSalt16()
        guard saltBytes.count >= 8, memoryKiB >= 8 * parallelism else { return nil }

        let tCost = UInt32(iterations)
        let mCost = UInt32(memoryKiB)
        let p = UInt32(parallelism)
        let hashLen = tagLength

        let encodedLen = argon2_encodedlen(
            tCost, mCost, p,
            UInt32(saltBytes.count),
            UInt32(hashLen),
            Argon2_id
        )
        guard encodedLen > 0 else { return nil }

        return password.withUnsafeBytes { pwdBuf in
            saltBytes.withUnsafeBytes { saltBuf in
                guard let pwdPtr = pwdBuf.baseAddress, let saltPtr = saltBuf.baseAddress else { return nil }
                let pwdLen = pwdBuf.count
                let saltLen = saltBuf.count

                let encodedBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: encodedLen)
                defer { encodedBuffer.deallocate() }
                encodedBuffer.initialize(repeating: 0, count: encodedLen)

                let result = argon2id_hash_encoded(
                    tCost, mCost, p,
                    pwdPtr, pwdLen,
                    saltPtr, saltLen,
                    hashLen,
                    encodedBuffer, encodedLen
                )

                guard result == ARGON2_OK.rawValue else { return nil }
                return String(cString: encodedBuffer)
            }
        }
    }

    private nonisolated static func randomSalt16() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, 16, &bytes)
        return Data(bytes)
    }
}
