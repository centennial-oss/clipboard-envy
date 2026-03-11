import Foundation

extension ClipboardTransform {
    // MARK: - Database CLI

    nonisolated static func mysqlCliTableToCsv(_ s: String) throws -> String {
        let rows = try mysqlCliTableRows(s)
        return csvString(from: rows, nullsAsEmpty: true)
    }

    nonisolated static func mysqlCliTableToJson(_ s: String) throws -> String {
        let rows = try mysqlCliTableRows(s)
        let csv = csvString(from: rows, nullsAsEmpty: true)
        return try csvToJson(csv)
    }

    nonisolated static func psqlCliTableToCsv(_ s: String) throws -> String {
        let rows = try psqlCliTableRows(s)
        return csvString(from: rows, nullsAsEmpty: true)
    }

    nonisolated static func psqlCliTableToJson(_ s: String) throws -> String {
        let rows = try psqlCliTableRows(s)
        let csv = csvString(from: rows, nullsAsEmpty: true)
        return try csvToJson(csv)
    }

    nonisolated static func sqlite3TableToCsv(_ s: String) throws -> String {
        let rows = try sqlite3TableRows(s)
        return csvString(from: rows, nullsAsEmpty: true)
    }

    nonisolated static func sqlite3TableToJson(_ s: String) throws -> String {
        let rows = try sqlite3TableRows(s)
        let csv = csvString(from: rows, nullsAsEmpty: true)
        return try csvToJson(csv)
    }

    private nonisolated static func mysqlCliTableRows(_ s: String) throws -> [[String]] {
        let lines = windowsNewlinesToUnix(s).components(separatedBy: .newlines)
        let borderIndices = lines.indices.filter { isMySQLCliTableBorder(lines[$0]) }
        guard let firstBorder = borderIndices.first,
              let lastBorder = borderIndices.last,
              firstBorder < lastBorder else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: could not find a complete +--- table border block.")
        }

        let tableLines = lines[firstBorder...lastBorder]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard tableLines.allSatisfy({ isMySQLCliTableBorder($0) || isMySQLCliTableRow($0) }) else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: found non-table text inside the detected table block.")
        }

        let rows = tableLines
            .filter(isMySQLCliTableRow)
            .map(parseMySQLCliTableRow)

        guard let headers = rows.first, !headers.isEmpty, rows.count >= 2 else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: expected a header row plus at least one data row.")
        }
        guard rows.allSatisfy({ $0.count == headers.count }) else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: one or more rows have a different number of columns than the header.")
        }
        return rows
    }

    private nonisolated static func psqlCliTableRows(_ s: String) throws -> [[String]] {
        let lines = windowsNewlinesToUnix(s)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let separatorIndex = lines.firstIndex(where: isPsqlCliTableSeparator),
              separatorIndex > 0 else {
            throw TransformError(description: "psql Table → CSV failed: could not find the dashed separator line under the header.")
        }

        let headerLine = lines[separatorIndex - 1]
        let dataLines = lines[(separatorIndex + 1)...]
            .filter { !isPsqlCliTableFooter($0) }
        guard !dataLines.isEmpty else {
            throw TransformError(description: "psql Table → CSV failed: found the header, but no data rows below it.")
        }

        let headers = parsePsqlCliTableRow(headerLine)
        guard !headers.isEmpty else {
            throw TransformError(description: "psql Table → CSV failed: header row did not contain any columns.")
        }

        let parsedDataRows = dataLines.map { line in
            normalizePsqlCliTableRow(parsePsqlCliTableRow(line), headerCount: headers.count)
        }
        guard parsedDataRows.allSatisfy({ !$0.isEmpty && $0.count == headers.count }) else {
            throw TransformError(description: "psql Table → CSV failed: one or more rows could not be aligned to the header column count.")
        }

        return [headers] + parsedDataRows
    }

    private nonisolated static func sqlite3TableRows(_ s: String) throws -> [[String]] {
        let lines = windowsNewlinesToUnix(s)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard lines.count >= 3 else {
            throw TransformError(description: "sqlite3 Table → CSV failed: expected a header row, a dashed separator row, and at least one data row.")
        }
        let headerLine = lines[0]
        let separatorLine = lines[1]
        let dataLines = Array(lines.dropFirst(2))

        let columnStarts = sqlite3ColumnStarts(from: separatorLine)
        guard !columnStarts.isEmpty else {
            throw TransformError(description: "sqlite3 Table → CSV failed: could not infer fixed-width columns from the dashed separator row.")
        }

        let headers = parseSQLite3FixedWidthRow(headerLine, columnStarts: columnStarts)
        guard !headers.isEmpty, headers.contains(where: { !$0.isEmpty }) else {
            throw TransformError(description: "sqlite3 Table → CSV failed: header row did not contain any columns.")
        }

        return [headers] + dataLines.map { parseSQLite3FixedWidthRow($0, columnStarts: columnStarts) }
    }

    private nonisolated static func isMySQLCliTableBorder(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("+"), trimmed.hasSuffix("+") else { return false }
        let body = trimmed.dropFirst().dropLast()
        guard !body.isEmpty else { return false }
        return body.contains("+") && body.allSatisfy { $0 == "+" || $0 == "-" }
    }

    private nonisolated static func isMySQLCliTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
    }

    private nonisolated static func parseMySQLCliTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return [] }
        return parts.dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private nonisolated static func isPsqlCliTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "+", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0 == "-" }
        }
    }

    private nonisolated static func isPsqlCliTableFooter(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("("), trimmed.hasSuffix(")") else { return false }
        let body = trimmed.dropFirst().dropLast()
        return body.range(of: #"^\d+\s+rows?$"#, options: .regularExpression) != nil
    }

    private nonisolated static func parsePsqlCliTableRow(_ line: String) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private nonisolated static func normalizePsqlCliTableRow(_ row: [String], headerCount: Int) -> [String] {
        guard !row.isEmpty, row.count <= headerCount else { return [] }
        if row.count == headerCount { return row }
        return row + Array(repeating: "", count: headerCount - row.count)
    }

    private nonisolated static func sqlite3ColumnStarts(from separatorLine: String) -> [Int] {
        let chars = Array(separatorLine)
        var starts: [Int] = []
        var i = 0
        while i < chars.count {
            if chars[i] == "-" {
                starts.append(i)
                while i < chars.count, chars[i] == "-" {
                    i += 1
                }
            } else if chars[i] == " " {
                i += 1
            } else {
                return []
            }
        }
        return starts
    }

    private nonisolated static func parseSQLite3FixedWidthRow(_ line: String, columnStarts: [Int]) -> [String] {
        let chars = Array(line)
        return columnStarts.enumerated().map { index, start in
            let end = index + 1 < columnStarts.count ? columnStarts[index + 1] : chars.count
            guard start < chars.count else { return "" }
            let upperBound = min(end, chars.count)
            return String(chars[start..<upperBound]).trimmingCharacters(in: .whitespaces)
        }
    }
}
