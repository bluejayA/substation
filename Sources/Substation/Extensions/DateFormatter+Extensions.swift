import Foundation

extension DateFormatter {
    /// ISO8601 formatter for API dates
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Standard date-time formatter for general UI display
    /// Format: yyyy-MM-dd HH:mm:ss
    static let standard: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale.current
        return formatter
    }()

    /// Logging formatter with millisecond precision
    /// Format: yyyy-MM-dd HH:mm:ss.SSS
    static let logging: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()

    /// Compact date-time formatter for tables and lists
    /// Format: yyyy-MM-dd HH:mm
    static let compact: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale.current
        return formatter
    }()

    /// Short date time formatter using system locale preferences
    /// Format: MM/dd/yy HH:mm
    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Medium date time formatter for detailed views
    /// Format: MMM dd, yyyy HH:mm
    static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Date only formatter
    /// Format: MMM dd, yyyy
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Time only formatter
    /// Format: HH:mm:ss
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

extension Date {
    /// Format date using the standard formatter
    func formatted() -> String {
        DateFormatter.standard.string(from: self)
    }

    /// Format date using the compact formatter
    func compactFormatted() -> String {
        DateFormatter.compact.string(from: self)
    }

    /// Format date using the short date-time formatter
    func shortFormatted() -> String {
        DateFormatter.shortDateTime.string(from: self)
    }

    /// Format date using the medium date-time formatter
    func mediumFormatted() -> String {
        DateFormatter.mediumDateTime.string(from: self)
    }

    /// Format date with only the date component
    func dateOnlyFormatted() -> String {
        DateFormatter.dateOnly.string(from: self)
    }

    /// Format date with only the time component
    func timeOnlyFormatted() -> String {
        DateFormatter.timeOnly.string(from: self)
    }

    /// Format date using ISO8601 formatter for API calls
    func iso8601Formatted() -> String {
        DateFormatter.iso8601.string(from: self)
    }

    /// Format date using the logging formatter with millisecond precision
    func loggingFormatted() -> String {
        DateFormatter.logging.string(from: self)
    }
}