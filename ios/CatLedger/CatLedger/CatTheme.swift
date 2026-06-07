import Foundation
import SwiftUI

extension Color {
    static let catBackground = Color(hex: "#FFF4F8")
    static let catCard = Color(hex: "#FFFDF9")
    static let catRose = Color(hex: "#F178A6")
    static let catPeach = Color(hex: "#FFD0BD")
    static let catCream = Color(hex: "#FFF7DE")
    static let catMint = Color(hex: "#BDEEDB")
    static let catInk = Color(hex: "#473642")
    static let catSubtext = Color(hex: "#8A7582")

    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch clean.count {
        case 3:
            red = (value >> 8) * 17
            green = (value >> 4 & 0xF) * 17
            blue = (value & 0xF) * 17
            alpha = 255
        case 6:
            red = value >> 16
            green = value >> 8 & 0xFF
            blue = value & 0xFF
            alpha = 255
        case 8:
            red = value >> 24
            green = value >> 16 & 0xFF
            blue = value >> 8 & 0xFF
            alpha = value & 0xFF
        default:
            red = 241
            green = 120
            blue = 166
            alpha = 255
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

extension Date {
    var monthKey: String {
        Self.monthFormatter.string(from: self)
    }

    var dayKey: String {
        Self.dayFormatter.string(from: self)
    }

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

func cents(from text: String) -> Int? {
    let normalized = text
        .replacingOccurrences(of: "￥", with: "")
        .replacingOccurrences(of: "¥", with: "")
        .replacingOccurrences(of: ",", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let value = Double(normalized), value > 0 else {
        return nil
    }
    return Int((value * 100).rounded())
}

func moneyText(_ cents: Int, signed: Bool = false) -> String {
    let prefix: String
    if signed {
        prefix = cents >= 0 ? "+" : "-"
    } else {
        prefix = cents < 0 ? "-" : ""
    }
    return "\(prefix)¥\(String(format: "%.2f", abs(Double(cents) / 100)))"
}

func amountText(_ cents: Int) -> String {
    String(format: "%.2f", Double(cents) / 100)
}

func parseTags(_ text: String) -> [String] {
    text
        .split { character in
            character == "," || character == "，" || character == " " || character == "#"
        }
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

func extractLargestAmount(from text: String) -> String {
    let pattern = #"(?<!\d)(?:¥|￥)?\s?([0-9]{1,6}(?:\.[0-9]{1,2})?)(?!\d)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return ""
    }

    let nsText = text as NSString
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
    let values = matches.compactMap { match -> Double? in
        guard match.numberOfRanges > 1 else { return nil }
        return Double(nsText.substring(with: match.range(at: 1)))
    }

    guard let max = values.max(), max > 0 else {
        return ""
    }
    return String(format: "%.2f", max)
}
