import Foundation

extension ClipboardTransform {
    // MARK: - YAML

    nonisolated static func yamlPrettify(_ s: String) -> String {
        if let data = s.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            return jsonPrettify(s)
        }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}"), let parsed = YAMLHelpers.parseMinifiedYAML(trimmed) as? [String: Any] {
            return YAMLHelpers.emitYAML(parsed, indent: 0)
        }
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), let parsed = YAMLHelpers.parseMinifiedYAML(trimmed) as? [Any] {
            return YAMLHelpers.emitYAML(parsed, indent: 0)
        }
        return YAMLHelpers.prettify(s)
    }

    nonisolated static func yamlMinify(_ s: String) -> String {
        if let data = s.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            return jsonMinify(s)
        }
        return YAMLHelpers.minify(s)
    }

    nonisolated static func jsonToYaml(_ s: String) throws -> String {
        let sanitized = sanitizeCommentedJSONInput(s)
        guard let data = sanitized.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            throw TransformError(description: "JSON → YAML failed: clipboard does not contain valid JSON.")
        }
        return YAMLHelpers.emitYAML(json, indent: 0)
    }

    nonisolated static func yamlToJson(_ s: String) throws -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let isMinifiedInput = ((trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))) && !trimmed.contains("\n")

        let obj: Any?
        if isMinifiedInput, let parsed = YAMLHelpers.parseMinifiedYAML(trimmed) {
            obj = parsed
        } else {
            obj = YAMLHelpers.parseYAML(s)
        }
        guard let obj = obj else {
            throw TransformError(description: "YAML → JSON failed: clipboard does not contain parseable YAML.")
        }
        let jsonObj = YAMLHelpers.anyToJSONCompatible(obj)
        let options: JSONSerialization.WritingOptions = isMinifiedInput ? [.sortedKeys] : [.prettyPrinted, .sortedKeys]
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObj, options: options),
              let out = String(data: data, encoding: .utf8) else {
            throw TransformError(description: "YAML → JSON failed: parsed YAML could not be encoded as JSON.")
        }
        return out
    }
}

enum YAMLQuoteStyle {
    case single
    case double
}

struct YAMLQuotedString {
    let value: String
    let style: YAMLQuoteStyle
}

enum YAMLHelpers {
    nonisolated static func prettify(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        var result: [String] = []
        var indentStack: [Int] = [0]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { result.append(""); continue }
            let lead = line.prefix(while: { $0 == " " }).count
            while indentStack.count > 1 && lead < indentStack.last! {
                _ = indentStack.popLast()
            }
            if lead > indentStack.last! {
                indentStack.append(lead)
            }
            let indent = indentStack.last!
            result.append(String(repeating: " ", count: indent) + trimmed)
        }
        return result.joined(separator: "\n")
    }

    nonisolated static func minify(_ s: String) -> String {
        if let parsed = parseYAML(s) {
            return emitYAMLMinified(parsed)
        }
        let lines = s.components(separatedBy: .newlines)
        let nonComment = lines.map { line in
            if let hashIdx = line.firstIndex(of: "#") {
                return String(line[..<hashIdx]).trimmingCharacters(in: .whitespaces)
            }
            return line.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        return nonComment.joined(separator: " ")
    }

    private nonisolated static func emitYAMLMinified(_ value: Any) -> String {
        switch value {
        case let dict as [String: Any]:
            let parts = dict.sorted(by: { $0.key < $1.key }).map { k, v in
                k + ": " + emitYAMLMinified(v)
            }
            return "{" + parts.joined(separator: ", ") + "}"
        case let arr as [Any]:
            let parts = arr.map { emitYAMLMinified($0) }
            return "[" + parts.joined(separator: ", ") + "]"
        default:
            return emitYAMLScalar(value)
        }
    }

    nonisolated static func emitYAML(_ value: Any, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        switch value {
        case let dict as [String: Any]:
            return dict.sorted(by: { $0.key < $1.key }).map { k, v in
                if let sub = v as? [String: Any], !sub.isEmpty {
                    return pad + k + ":\n" + emitYAML(sub, indent: indent + 2)
                }
                if let arr = v as? [Any], !arr.isEmpty {
                    let itemPad = String(repeating: " ", count: indent + 2)
                    return pad + k + ":\n" + arr.map { item in
                        if let sub = item as? [String: Any], !sub.isEmpty {
                            return itemPad + "-\n" + emitYAML(sub, indent: indent + 4).split(separator: "\n").map { itemPad + "  " + $0 }.joined(separator: "\n")
                        }
                        return itemPad + "- " + emitYAMLScalar(item)
                    }.joined(separator: "\n")
                }
                return pad + k + ": " + emitYAMLScalar(v)
            }.joined(separator: "\n")
        case let arr as [Any]:
            return arr.map { item in
                if let sub = item as? [String: Any], !sub.isEmpty {
                    return pad + "-\n" + emitYAML(sub, indent: indent + 2)
                }
                return pad + "- " + emitYAMLScalar(item)
            }.joined(separator: "\n")
        default:
            return pad + emitYAMLScalar(value)
        }
    }

    private nonisolated static func stringLooksLikeYAMLScalar(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        if t == "null" || t == "true" || t == "false" || t == "yes" || t == "no" { return true }
        var i = t.unicodeScalars.startIndex
        if i == t.unicodeScalars.endIndex { return false }
        if t.unicodeScalars[i] == "-" { i = t.unicodeScalars.index(after: i) }
        if i == t.unicodeScalars.endIndex { return false }
        var hasDigit = false
        var hasDot = false
        while i != t.unicodeScalars.endIndex {
            let c = t.unicodeScalars[i]
            if c == "." {
                if hasDot { return false }
                hasDot = true
            } else if c == "e" || c == "E" {
                i = t.unicodeScalars.index(after: i)
                if i != t.unicodeScalars.endIndex && (t.unicodeScalars[i] == "+" || t.unicodeScalars[i] == "-") {
                    i = t.unicodeScalars.index(after: i)
                }
                while i != t.unicodeScalars.endIndex && CharacterSet.decimalDigits.contains(t.unicodeScalars[i]) {
                    hasDigit = true
                    i = t.unicodeScalars.index(after: i)
                }
                return hasDigit && i == t.unicodeScalars.endIndex
            } else if CharacterSet.decimalDigits.contains(c) {
                hasDigit = true
            } else {
                return false
            }
            i = t.unicodeScalars.index(after: i)
        }
        return hasDigit
    }

    private nonisolated static func emitYAMLScalar(_ value: Any) -> String {
        switch value {
        case let q as YAMLQuotedString:
            switch q.style {
            case .single:
                return "'" + q.value.replacingOccurrences(of: "'", with: "''") + "'"
            case .double:
                return "\"" + q.value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
            }
        case is NSNull:
            return "null"
        case let b as Bool:
            return b ? "true" : "false"
        case let n as Int:
            return String(n)
        case let n as Double:
            return String(n)
        case let s as String:
            if s.contains("\n") || s.contains(":") || s.contains("#") { return "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
            if stringLooksLikeYAMLScalar(s) { return "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
            return s
        default:
            return String(describing: value)
        }
    }

    nonisolated static func parseYAML(_ s: String) -> Any? {
        let lines = s.components(separatedBy: .newlines)
        var i = 0
        return parseYAMLBlock(lines, &i, baseIndent: 0, strict: false)
    }

    /// True when the string parses as a block YAML mapping or list under the same rules as ``parseYAML``,
    /// but every non-empty, non-comment line must be structural YAML and mapping keys must look like YAML keys
    /// (not arbitrary `foo: bar` fragments from Swift or other languages).
    nonisolated static func parsesAsStructuredYAMLDocument(_ s: String) -> Bool {
        let lines = s.components(separatedBy: .newlines)
        var i = 0
        guard let value = parseYAMLBlock(lines, &i, baseIndent: 0, strict: true) else { return false }
        return value is [String: Any] || value is [Any]
    }

    nonisolated static func anyToJSONCompatible(_ value: Any) -> Any {
        switch value {
        case let q as YAMLQuotedString:
            return q.value
        case let d as [String: Any]:
            return d.mapValues { anyToJSONCompatible($0) }
        case let a as [Any]:
            return a.map { anyToJSONCompatible($0) }
        default:
            return value
        }
    }

    /// Unquoted mapping keys we accept for clipboard YAML detection (avoids Swift `foo(bar: x, name: y)` false positives).
    private nonisolated static func isStructuredYAMLPlainKey(_ key: String) -> Bool {
        let k = key.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-."))
        return k.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private nonisolated static func isStructuredYAMLMappingKey(_ key: String) -> Bool {
        let k = key.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return false }
        if k.count >= 2, k.first == "\"", k.last == "\"" { return true }
        if k.count >= 2, k.first == "'", k.last == "'" { return true }
        return isStructuredYAMLPlainKey(k)
    }

    /// Document/stream lines that are valid YAML but not mappings or list entries (e.g. ``---``).
    nonisolated static func isYAMLStreamMarkerLine(_ trimmed: String) -> Bool {
        if trimmed == "..." { return true }
        guard trimmed.hasPrefix("---") else { return false }
        let after = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
        return after.isEmpty || after.hasPrefix("#")
    }

    private nonisolated static func parseYAMLBlock(_ lines: [String], _ index: inout Int, baseIndent: Int, strict: Bool) -> Any? {
        var map: [String: Any] = [:]
        var list: [Any] = []
        var isList = false
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { index += 1; continue }
            if isYAMLStreamMarkerLine(trimmed) { index += 1; continue }
            let lead = line.prefix(while: { $0 == " " }).count
            if lead < baseIndent { break }
            let content = String(line.dropFirst(lead))
            let contentTrimmed = content.trimmingCharacters(in: .whitespaces)
            if contentTrimmed == "-" || contentTrimmed.hasPrefix("- ") {
                isList = true
                let itemStr: String
                if contentTrimmed == "-" {
                    itemStr = ""
                } else {
                    itemStr = String(contentTrimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }
                index += 1
                let nextLead = (index < lines.count) ? lines[index].prefix(while: { $0 == " " }).count : 0
                if itemStr.isEmpty, nextLead > lead, index < lines.count {
                    if let sub = parseYAMLBlock(lines, &index, baseIndent: nextLead, strict: strict) {
                        list.append(sub)
                    } else if strict {
                        return nil
                    } else {
                        list.append(parseYAMLScalar(itemStr))
                    }
                } else {
                    list.append(parseYAMLScalar(itemStr))
                }
            } else if let colonIdx = contentTrimmed.firstIndex(of: ":") {
                let key = String(contentTrimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let rest = String(contentTrimmed[contentTrimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                if strict, !isStructuredYAMLMappingKey(key) { return nil }
                index += 1
                if rest.isEmpty {
                    let nextLead = (index < lines.count) ? lines[index].prefix(while: { $0 == " " }).count : 0
                    if nextLead > lead, index < lines.count {
                        if let sub = parseYAMLBlock(lines, &index, baseIndent: nextLead, strict: strict) {
                            map[key] = sub
                        } else if strict {
                            return nil
                        }
                    } else {
                        map[key] = NSNull()
                    }
                } else {
                    map[key] = parseYAMLScalar(rest)
                }
            } else {
                if strict { return nil }
                index += 1
            }
        }
        if isList { return list }
        return map.isEmpty ? nil : map
    }

    private nonisolated static func parseYAMLScalar(_ s: String) -> Any {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("\""), t.hasSuffix("\"") {
            let unescaped = String(t.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
            return YAMLQuotedString(value: unescaped, style: .double)
        }
        if t.hasPrefix("'"), t.hasSuffix("'"), t.count >= 2 {
            let unescaped = String(t.dropFirst().dropLast())
                .replacingOccurrences(of: "''", with: "'")
            return YAMLQuotedString(value: unescaped, style: .single)
        }
        if t == "null" || t == "~" { return NSNull() }
        if t == "true" { return true }
        if t == "false" { return false }
        if let i = Int(t) { return i }
        if let d = Double(t) { return d }
        return t
    }

    nonisolated static func parseMinifiedYAML(_ s: String) -> Any? {
        var i = s.startIndex
        skipMinifiedWS(s, &i)
        guard i < s.endIndex else { return nil }
        if s[i] == "{" { return parseMinifiedObject(s, &i) }
        if s[i] == "[" { return parseMinifiedArray(s, &i) }
        return nil
    }

    private nonisolated static func skipMinifiedWS(_ s: String, _ i: inout String.Index) {
        while i < s.endIndex, s[i].isWhitespace { i = s.index(after: i) }
    }

    private nonisolated static func parseMinifiedObject(_ s: String, _ i: inout String.Index) -> [String: Any]? {
        guard i < s.endIndex, s[i] == "{" else { return nil }
        i = s.index(after: i)
        var result: [String: Any] = [:]
        while true {
            skipMinifiedWS(s, &i)
            guard i < s.endIndex else { return nil }
            if s[i] == "}" { i = s.index(after: i); return result }
            guard let key = parseMinifiedKey(s, &i) else { return nil }
            skipMinifiedWS(s, &i)
            guard i < s.endIndex, s[i] == ":" else { return nil }
            i = s.index(after: i)
            skipMinifiedWS(s, &i)
            guard let value = parseMinifiedValue(s, &i) else { return nil }
            result[key] = value
            skipMinifiedWS(s, &i)
            guard i < s.endIndex else { return result }
            if s[i] == "}" { i = s.index(after: i); return result }
            if s[i] == "," { i = s.index(after: i) } else { return nil }
        }
    }

    private nonisolated static func parseMinifiedArray(_ s: String, _ i: inout String.Index) -> [Any]? {
        guard i < s.endIndex, s[i] == "[" else { return nil }
        i = s.index(after: i)
        var result: [Any] = []
        while true {
            skipMinifiedWS(s, &i)
            guard i < s.endIndex else { return nil }
            if s[i] == "]" { i = s.index(after: i); return result }
            guard let value = parseMinifiedValue(s, &i) else { return nil }
            result.append(value)
            skipMinifiedWS(s, &i)
            guard i < s.endIndex else { return result }
            if s[i] == "]" { i = s.index(after: i); return result }
            if s[i] == "," { i = s.index(after: i) } else { return nil }
        }
    }

    private nonisolated static func parseMinifiedKey(_ s: String, _ i: inout String.Index) -> String? {
        if i < s.endIndex && (s[i] == "'" || s[i] == "\"") {
            guard let any = parseMinifiedQuotedString(s, &i), let q = any as? YAMLQuotedString else { return nil }
            return q.value
        }
        return parseMinifiedUnquoted(s, &i, terminators: ":")
    }

    private nonisolated static func parseMinifiedValue(_ s: String, _ i: inout String.Index) -> Any? {
        guard i < s.endIndex else { return nil }
        let c = s[i]
        if c == "{" { return parseMinifiedObject(s, &i) }
        if c == "[" { return parseMinifiedArray(s, &i) }
        if c == "'" || c == "\"" { return parseMinifiedQuotedString(s, &i) }
        return parseMinifiedUnquotedScalar(s, &i)
    }

    private nonisolated static func parseMinifiedQuotedString(_ s: String, _ i: inout String.Index) -> Any? {
        guard i < s.endIndex else { return nil }
        let quote = s[i]
        guard quote == "'" || quote == "\"" else { return nil }
        i = s.index(after: i)
        var result = ""
        while i < s.endIndex {
            if s[i] == quote {
                if s.index(after: i) < s.endIndex && s[s.index(after: i)] == quote {
                    result.append(quote)
                    i = s.index(i, offsetBy: 2)
                } else {
                    i = s.index(after: i)
                    let style: YAMLQuoteStyle = quote == "'" ? .single : .double
                    return YAMLQuotedString(value: result, style: style)
                }
            } else if quote == "\"" && s[i] == "\\" && s.index(after: i) < s.endIndex {
                let next = s[s.index(after: i)]
                if next == "\"" { result.append("\"") }
                else if next == "\\" { result.append("\\") }
                else { result.append(next) }
                i = s.index(i, offsetBy: 2)
            } else {
                result.append(s[i])
                i = s.index(after: i)
            }
        }
        return nil
    }

    private nonisolated static func parseMinifiedUnquoted(_ s: String, _ i: inout String.Index, terminators: String) -> String? {
        let start = i
        while i < s.endIndex, !terminators.contains(s[i]) {
            i = s.index(after: i)
        }
        return String(s[start..<i]).trimmingCharacters(in: .whitespaces)
    }

    private nonisolated static func parseMinifiedUnquotedScalar(_ s: String, _ i: inout String.Index) -> Any? {
        let start = i
        while i < s.endIndex {
            let c = s[i]
            if c == "," || c == "}" || c == "]" { break }
            i = s.index(after: i)
        }
        let raw = String(s[start..<i]).trimmingCharacters(in: .whitespaces)
        return parseYAMLScalar(raw)
    }
}
