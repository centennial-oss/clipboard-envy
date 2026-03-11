import Foundation

extension ClipboardTransform {
    // MARK: - Time Transformations

    static func timeToEpochSeconds(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.epochSeconds(from: date)
    }

    static func timeToEpochMilliseconds(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.epochMilliseconds(from: date)
    }

    static func timeToSQLDateTimeLocal(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.sqlDateTimeLocal(from: date)
    }

    static func timeToSQLDateTimeUTC(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.sqlDateTimeUTC(from: date)
    }

    static func timeToRFC3339Z(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.rfc3339Z(from: date)
    }

    static func timeToRFC3339WithOffset(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.rfc3339WithOffset(from: date)
    }

    static func timeToRFC3339WithAbbreviation(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.rfc3339WithAbbreviation(from: date)
    }

    static func timeToRFC1123Local(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.rfc1123Local(from: date)
    }

    static func timeToRFC1123UTC(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.rfc1123UTC(from: date)
    }

    static func timeToYYYYMMDDHHmmssLocal(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyyyMMddHHmmssLocal(from: date)
    }

    static func timeToYYYYMMDDHHmmssUTC(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyyyMMddHHmmssUTC(from: date)
    }

    static func timeToYYMMDDHHmmssLocal(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyMMddHHmmssLocal(from: date)
    }

    static func timeToYYMMDDHHmmssUTC(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyMMddHHmmssUTC(from: date)
    }

    static func timeToYYYYMMDDLocal(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyyyMMddLocal(from: date)
    }

    static func timeToYYYYMMDDUTC(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyyyMMddUTC(from: date)
    }

    static func timeToYYYYMMDDHHLocal(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyyyMMddHHLocal(from: date)
    }

    static func timeToYYYYMMDDHHUTC(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyyyMMddHHUTC(from: date)
    }

    static func timeToYYMMDDLocal(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyMMddLocal(from: date)
    }

    static func timeToYYMMDDUTC(_ s: String) -> String? {
        guard let date = TimeFormat.parseAnyFormat(s) else { return nil }
        return TimeOutput.yyMMddUTC(from: date)
    }
}

enum TimeFormat {
    static func parseAnyFormat(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let date = parseEpochSeconds(trimmed) { return date }
        if let date = parseEpochMilliseconds(trimmed) { return date }
        if let date = parseRFC3339(trimmed) { return date }
        if let date = parseSQLDateTime(trimmed) { return date }
        if let date = parseRFC1123(trimmed) { return date }
        if let date = parseSlashDateTime(trimmed) { return date }

        return nil
    }

    static func parseEpochSeconds(_ s: String) -> Date? {
        guard let value = Double(s),
              value >= -62135596800,
              value <= 253402300799,
              !s.contains(".") || s.split(separator: ".").count == 2 else { return nil }
        if s.count > 10 && !s.contains(".") { return nil }
        return Date(timeIntervalSince1970: value)
    }

    static func parseEpochMilliseconds(_ s: String) -> Date? {
        guard let value = Int64(s),
              s.count >= 13, s.count <= 14,
              !s.contains(".") else { return nil }
        let seconds = Double(value) / 1000.0
        guard seconds >= -62135596800, seconds <= 253402300799 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static let rfc3339Formatters: [ISO8601DateFormatter] = {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFrac = ISO8601DateFormatter()
        withoutFrac.formatOptions = [.withInternetDateTime]

        return [withFrac, withoutFrac]
    }()

    static func parseRFC3339(_ s: String) -> Date? {
        for formatter in rfc3339Formatters {
            if let date = formatter.date(from: s) {
                return date
            }
        }
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXX",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSzzz",
            "yyyy-MM-dd'T'HH:mm:sszzz",
        ]
        for pattern in patterns {
            let f = DateFormatter()
            f.dateFormat = pattern
            f.locale = Locale(identifier: "en_US_POSIX")
            if let date = f.date(from: s) {
                return date
            }
        }
        return nil
    }

    private static let sqlDateTimeFormatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
        ]
        return patterns.map { pattern in
            let f = DateFormatter()
            f.dateFormat = pattern
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone.current
            return f
        }
    }()

    static func parseSQLDateTime(_ s: String) -> Date? {
        guard s.contains("-") && !s.contains("/") else { return nil }
        for formatter in sqlDateTimeFormatters {
            if let date = formatter.date(from: s) {
                return date
            }
        }
        return nil
    }

    private static let rfc1123Formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let rfc1123FormatterGMT: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        return f
    }()

    static func parseRFC1123(_ s: String) -> Date? {
        if let date = rfc1123Formatter.date(from: s) { return date }
        if let date = rfc1123FormatterGMT.date(from: s) { return date }
        return nil
    }

    static func parseSlashDateTime(_ s: String) -> Date? {
        guard let firstSlash = s.firstIndex(of: "/") else { return nil }
        let yearPart = s[s.startIndex..<firstSlash]

        if yearPart.count == 4 {
            let fourDigitYearPatterns = [
                "yyyy/MM/dd HH:mm:ss",
                "yyyy/MM/dd/HH",
                "yyyy/MM/dd",
            ]
            for pattern in fourDigitYearPatterns {
                let f = DateFormatter()
                f.dateFormat = pattern
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone.current
                if let date = f.date(from: s) {
                    return date
                }
            }
        } else if yearPart.count == 2 {
            return parseTwoDigitYearSlashFormat(s)
        }

        return nil
    }

    private static func parseTwoDigitYearSlashFormat(_ s: String) -> Date? {
        let parts = s.split(separator: "/", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        guard let twoDigitYear = Int(parts[0]), twoDigitYear >= 0, twoDigitYear <= 99 else { return nil }
        guard let month = Int(parts[1]), month >= 1, month <= 12 else { return nil }

        let dayAndTime = String(parts[2])
        let dayTimeParts = dayAndTime.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        guard let day = Int(dayTimeParts[0]), day >= 1, day <= 31 else { return nil }

        let fullYear = twoDigitYear < 70 ? 2000 + twoDigitYear : 1900 + twoDigitYear

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        var components = DateComponents()
        components.year = fullYear
        components.month = month
        components.day = day

        if dayTimeParts.count > 1 {
            let timeParts = dayTimeParts[1].split(separator: ":")
            if timeParts.count >= 2 {
                components.hour = Int(timeParts[0])
                components.minute = Int(timeParts[1])
                if timeParts.count >= 3 {
                    components.second = Int(timeParts[2])
                }
            }
        }

        return calendar.date(from: components)
    }
}

enum TimeOutput {
    static func epochSeconds(from date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
    }

    static func epochMilliseconds(from date: Date) -> String {
        String(Int64(date.timeIntervalSince1970 * 1000))
    }

    private static let sqlLocalFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    private static let sqlUTCFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static func sqlDateTimeLocal(from date: Date) -> String {
        sqlLocalFormatter.string(from: date)
    }

    static func sqlDateTimeUTC(from date: Date) -> String {
        sqlUTCFormatter.string(from: date)
    }

    private static let rfc3339ZFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let rfc3339OffsetFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func rfc3339Z(from date: Date) -> String {
        rfc3339ZFormatter.string(from: date)
    }

    static func rfc3339WithOffset(from date: Date) -> String {
        rfc3339OffsetFormatter.string(from: date)
    }

    static func rfc3339WithAbbreviation(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSzzz"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    private static let rfc1123Formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    private static let rfc1123UTCFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        return f
    }()

    static func rfc1123Local(from date: Date) -> String {
        rfc1123Formatter.string(from: date)
    }

    static func rfc1123UTC(from date: Date) -> String {
        rfc1123UTCFormatter.string(from: date)
    }

    private static func makeFormatter(_ format: String, utc: Bool) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = utc ? TimeZone(identifier: "UTC") : TimeZone.current
        return f
    }

    private static let yyyyMMddHHmmssLocalFormatter = makeFormatter("yyyy/MM/dd HH:mm:ss", utc: false)
    private static let yyyyMMddHHmmssUTCFormatter = makeFormatter("yyyy/MM/dd HH:mm:ss", utc: true)
    private static let yyMMddHHmmssLocalFormatter = makeFormatter("yy/MM/dd HH:mm:ss", utc: false)
    private static let yyMMddHHmmssUTCFormatter = makeFormatter("yy/MM/dd HH:mm:ss", utc: true)
    private static let yyyyMMddLocalFormatter = makeFormatter("yyyy/MM/dd", utc: false)
    private static let yyyyMMddUTCFormatter = makeFormatter("yyyy/MM/dd", utc: true)
    private static let yyyyMMddHHLocalFormatter = makeFormatter("yyyy/MM/dd/HH", utc: false)
    private static let yyyyMMddHHUTCFormatter = makeFormatter("yyyy/MM/dd/HH", utc: true)
    private static let yyMMddLocalFormatter = makeFormatter("yy/MM/dd", utc: false)
    private static let yyMMddUTCFormatter = makeFormatter("yy/MM/dd", utc: true)

    static func yyyyMMddHHmmssLocal(from date: Date) -> String {
        yyyyMMddHHmmssLocalFormatter.string(from: date)
    }

    static func yyyyMMddHHmmssUTC(from date: Date) -> String {
        yyyyMMddHHmmssUTCFormatter.string(from: date)
    }

    static func yyMMddHHmmssLocal(from date: Date) -> String {
        yyMMddHHmmssLocalFormatter.string(from: date)
    }

    static func yyMMddHHmmssUTC(from date: Date) -> String {
        yyMMddHHmmssUTCFormatter.string(from: date)
    }

    static func yyyyMMddLocal(from date: Date) -> String {
        yyyyMMddLocalFormatter.string(from: date)
    }

    static func yyyyMMddUTC(from date: Date) -> String {
        yyyyMMddUTCFormatter.string(from: date)
    }

    static func yyyyMMddHHLocal(from date: Date) -> String {
        yyyyMMddHHLocalFormatter.string(from: date)
    }

    static func yyyyMMddHHUTC(from date: Date) -> String {
        yyyyMMddHHUTCFormatter.string(from: date)
    }

    static func yyMMddLocal(from date: Date) -> String {
        yyMMddLocalFormatter.string(from: date)
    }

    static func yyMMddUTC(from date: Date) -> String {
        yyMMddUTCFormatter.string(from: date)
    }
}
