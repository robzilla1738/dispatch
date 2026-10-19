import Foundation

public struct CalculatorResult: Equatable, Sendable {
    public let value: Double
    public let formatted: String
    public let expression: String

    public init(value: Double, formatted: String, expression: String) {
        self.value = value
        self.formatted = formatted
        self.expression = expression
    }
}

public enum CalculatorError: Error, Equatable {
    case invalidExpression
    case unknownIdentifier(String)
    case divisionByZero
    case domainError
}

/// Recursive-descent arithmetic evaluator with a calculator-friendly feature
/// set: percentages, factorial, functions, constants, and common unit
/// conversions. It intentionally avoids NSExpression so malformed input can
/// never execute anything.
public enum Calculator {
    public static func evaluate(_ input: String) -> CalculatorResult? {
        let cleaned = normalize(input)
        guard !cleaned.isEmpty else { return nil }

        let original = String(input).trimmingCharacters(in: .whitespacesAndNewlines)

        if let conversion = evaluateConversion(cleaned) {
            return CalculatorResult(
                value: conversion.value,
                formatted: conversion.formatted,
                expression: original
            )
        }

        do {
            var parser = Parser(tokens: try tokenize(cleaned))
            let value = try parser.parseExpression()
            try parser.expectEnd()
            guard value.isFinite else { return nil }
            return CalculatorResult(
                value: value,
                formatted: format(value),
                expression: original
            )
        } catch {
            return nil
        }
    }

    public static func looksLikeExpression(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 160 else { return false }
        if trimmed.range(
            of: #"(?i)\d\s*[a-zA-Z°]*\s+(?:in|to)\s+[a-zA-Z°]+"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        let hasOperator = trimmed.range(
            of: #"[+\-*/^%!()]"#,
            options: .regularExpression
        ) != nil
        let hasFunction = trimmed.range(
            of: #"(?i)\b(?:sqrt|cbrt|sin|cos|tan|asin|acos|atan|log|ln|exp|abs|floor|ceil|round)\s*\("#,
            options: .regularExpression
        ) != nil
        let hasDigit = trimmed.range(of: #"\d"#, options: .regularExpression) != nil
        return hasDigit && (hasOperator || hasFunction)
    }

    public static func format(_ value: Double) -> String {
        if value == 0 { return "0" }
        if abs(value) >= 1e15 || abs(value) < 1e-9 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .scientific
            formatter.maximumFractionDigits = 8
            formatter.locale = Locale(identifier: "en_US")
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."

        // Strip floating point dust such as 0.30000000000000004.
        let rounded = (value * 1_000_000_000_000).rounded() / 1_000_000_000_000
        return formatter.string(from: NSNumber(value: rounded)) ?? String(rounded)
    }

    // MARK: - Normalization

    private static func normalize(_ input: String) -> String {
        var value = input
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "π", with: "pi")
            .replacingOccurrences(of: "√", with: "sqrt")
        value = value.replacingOccurrences(of: #"(?<=\d),(?=\d{3}\b)"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(
            of: #"(?i)(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)"#,
            with: "($1/100)*$2",
            options: .regularExpression
        )
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Tokenizer

    private enum Token: Equatable {
        case number(Double)
        case identifier(String)
        case plus
        case minus
        case star
        case slash
        case caret
        case percent
        case bang
        case leftParen
        case rightParen
        case comma
    }

    private static func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        let characters = Array(input)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                index += 1
                continue
            }
            if character.isNumber || (character == "." && index + 1 < characters.count && characters[index + 1].isNumber) {
                var text = String(character)
                index += 1
                while index < characters.count, characters[index].isNumber || characters[index] == "." {
                    text.append(characters[index])
                    index += 1
                }
                if index < characters.count, characters[index] == "e" || characters[index] == "E" {
                    var exponent = String(characters[index])
                    var cursor = index + 1
                    if cursor < characters.count, characters[cursor] == "+" || characters[cursor] == "-" {
                        exponent.append(characters[cursor])
                        cursor += 1
                    }
                    var digits = ""
                    while cursor < characters.count, characters[cursor].isNumber {
                        digits.append(characters[cursor])
                        cursor += 1
                    }
                    if !digits.isEmpty {
                        text += exponent + digits
                        index = cursor
                    }
                }
                guard let number = Double(text) else { throw CalculatorError.invalidExpression }
                tokens.append(.number(number))
                continue
            }
            if character.isLetter {
                var text = ""
                while index < characters.count, characters[index].isLetter {
                    text.append(characters[index])
                    index += 1
                }
                tokens.append(.identifier(text.lowercased()))
                continue
            }
            switch character {
            case "+": tokens.append(.plus)
            case "-": tokens.append(.minus)
            case "*": tokens.append(.star)
            case "/": tokens.append(.slash)
            case "^": tokens.append(.caret)
            case "%": tokens.append(.percent)
            case "!": tokens.append(.bang)
            case "(": tokens.append(.leftParen)
            case ")": tokens.append(.rightParen)
            case ",": tokens.append(.comma)
            default: throw CalculatorError.invalidExpression
            }
            index += 1
        }
        return tokens
    }

    private struct Parser {
        let tokens: [Token]
        var index = 0

        mutating func parseExpression() throws -> Double {
            var value = try parseTerm()
            while let token = peek() {
                if token == .plus {
                    index += 1
                    value += try parseTerm()
                } else if token == .minus {
                    index += 1
                    value -= try parseTerm()
                } else {
                    break
                }
            }
            return value
        }

        mutating func parseTerm() throws -> Double {
            var value = try parsePower()
            while let token = peek() {
                if token == .star {
                    index += 1
                    value *= try parsePower()
                } else if token == .slash {
                    index += 1
                    let divisor = try parsePower()
                    if divisor == 0 { throw CalculatorError.divisionByZero }
                    value /= divisor
                } else if token == .identifier("mod") {
                    index += 1
                    let divisor = try parsePower()
                    if divisor == 0 { throw CalculatorError.divisionByZero }
                    value = value.truncatingRemainder(dividingBy: divisor)
                } else {
                    break
                }
            }
            return value
        }

        mutating func parsePower() throws -> Double {
            let base = try parseUnary()
            if peek() == .caret {
                index += 1
                let exponent = try parsePower()
                return pow(base, exponent)
            }
            return base
        }

        mutating func parseUnary() throws -> Double {
            if peek() == .plus {
                index += 1
                return try parseUnary()
            }
            if peek() == .minus {
                index += 1
                return -(try parseUnary())
            }
            return try parsePostfix()
        }

        mutating func parsePostfix() throws -> Double {
            var value = try parsePrimary()
            while let token = peek() {
                if token == .percent {
                    index += 1
                    value /= 100
                } else if token == .bang {
                    index += 1
                    guard value >= 0, value <= 170, value.rounded() == value else {
                        throw CalculatorError.domainError
                    }
                    value = (1...max(Int(value), 1)).reduce(1.0) { $0 * Double($1) }
                } else {
                    break
                }
            }
            return value
        }

        mutating func parsePrimary() throws -> Double {
            guard let token = peek() else { throw CalculatorError.invalidExpression }
            switch token {
            case .number(let value):
                index += 1
                return value
            case .leftParen:
                index += 1
                let value = try parseExpression()
                guard peek() == .rightParen else { throw CalculatorError.invalidExpression }
                index += 1
                return value
            case .identifier(let name):
                index += 1
                if let constant = constants[name] {
                    return constant
                }
                guard peek() == .leftParen else { throw CalculatorError.unknownIdentifier(name) }
                index += 1
                var arguments: [Double] = []
                if peek() != .rightParen {
                    arguments.append(try parseExpression())
                    while peek() == .comma {
                        index += 1
                        arguments.append(try parseExpression())
                    }
                }
                guard peek() == .rightParen else { throw CalculatorError.invalidExpression }
                index += 1
                return try apply(function: name, arguments: arguments)
            default:
                throw CalculatorError.invalidExpression
            }
        }

        func peek() -> Token? {
            index < tokens.count ? tokens[index] : nil
        }

        mutating func expectEnd() throws {
            guard index == tokens.count else { throw CalculatorError.invalidExpression }
        }
    }

    private static let constants: [String: Double] = [
        "pi": .pi,
        "tau": .pi * 2,
        "e": M_E,
    ]

    private static func apply(function: String, arguments: [Double]) throws -> Double {
        func unary(_ operation: (Double) -> Double) throws -> Double {
            guard arguments.count == 1 else { throw CalculatorError.invalidExpression }
            let result = operation(arguments[0])
            guard result.isFinite else { throw CalculatorError.domainError }
            return result
        }

        switch function {
        case "sqrt": return try unary { $0 < 0 ? .nan : sqrt($0) }
        case "cbrt": return try unary(cbrt)
        case "sin": return try unary(sin)
        case "cos": return try unary(cos)
        case "tan": return try unary(tan)
        case "asin": return try unary(asin)
        case "acos": return try unary(acos)
        case "atan": return try unary(atan)
        case "log": return try unary(log10)
        case "ln": return try unary(log)
        case "exp": return try unary(exp)
        case "abs": return try unary(abs)
        case "floor": return try unary(floor)
        case "ceil": return try unary(ceil)
        case "round": return try unary { $0.rounded() }
        case "min":
            guard !arguments.isEmpty else { throw CalculatorError.invalidExpression }
            return arguments.min()!
        case "max":
            guard !arguments.isEmpty else { throw CalculatorError.invalidExpression }
            return arguments.max()!
        case "pow":
            guard arguments.count == 2 else { throw CalculatorError.invalidExpression }
            return pow(arguments[0], arguments[1])
        default:
            throw CalculatorError.unknownIdentifier(function)
        }
    }

    // MARK: - Unit conversions

    private struct Unit {
        let dimension: String
        let factor: Double
        let offset: Double
    }

    private static let units: [String: Unit] = [
        // Length, base meter
        "mm": Unit(dimension: "length", factor: 0.001, offset: 0),
        "cm": Unit(dimension: "length", factor: 0.01, offset: 0),
        "m": Unit(dimension: "length", factor: 1, offset: 0),
        "km": Unit(dimension: "length", factor: 1_000, offset: 0),
        "in": Unit(dimension: "length", factor: 0.0254, offset: 0),
        "ft": Unit(dimension: "length", factor: 0.3048, offset: 0),
        "yd": Unit(dimension: "length", factor: 0.9144, offset: 0),
        "mi": Unit(dimension: "length", factor: 1_609.344, offset: 0),
        "nmi": Unit(dimension: "length", factor: 1_852, offset: 0),
        // Mass, base kilogram
        "mg": Unit(dimension: "mass", factor: 0.000_001, offset: 0),
        "g": Unit(dimension: "mass", factor: 0.001, offset: 0),
        "kg": Unit(dimension: "mass", factor: 1, offset: 0),
        "oz": Unit(dimension: "mass", factor: 0.028_349_523_125, offset: 0),
        "lb": Unit(dimension: "mass", factor: 0.453_592_37, offset: 0),
        "st": Unit(dimension: "mass", factor: 6.350_293_18, offset: 0),
        // Temperature uses offsets.
        "c": Unit(dimension: "temperature", factor: 1, offset: 273.15),
        "f": Unit(dimension: "temperature", factor: 5.0 / 9.0, offset: 255.372_222_222),
        "k": Unit(dimension: "temperature", factor: 1, offset: 0),
        // Time, base second
        "ms": Unit(dimension: "time", factor: 0.001, offset: 0),
        "s": Unit(dimension: "time", factor: 1, offset: 0),
        "min": Unit(dimension: "time", factor: 60, offset: 0),
        "h": Unit(dimension: "time", factor: 3_600, offset: 0),
        "day": Unit(dimension: "time", factor: 86_400, offset: 0),
        "week": Unit(dimension: "time", factor: 604_800, offset: 0),
        "year": Unit(dimension: "time", factor: 31_557_600, offset: 0),
        // Data, base byte (binary interpretation, matching Finder)
        "b": Unit(dimension: "data", factor: 1, offset: 0),
        "kb": Unit(dimension: "data", factor: 1_024, offset: 0),
        "mb": Unit(dimension: "data", factor: 1_048_576, offset: 0),
        "gb": Unit(dimension: "data", factor: 1_073_741_824, offset: 0),
        "tb": Unit(dimension: "data", factor: 1_099_511_627_776, offset: 0),
        // Speed, base m/s
        "mph": Unit(dimension: "speed", factor: 0.447_04, offset: 0),
        "kmh": Unit(dimension: "speed", factor: 1.0 / 3.6, offset: 0),
        "kph": Unit(dimension: "speed", factor: 1.0 / 3.6, offset: 0),
        "m/s": Unit(dimension: "speed", factor: 1, offset: 0),
        "knot": Unit(dimension: "speed", factor: 0.514_444, offset: 0),
    ]

    private static func evaluateConversion(_ input: String) -> CalculatorResult? {
        guard let match = input.range(
            of: #"(?i)^\s*([+-]?\d+(?:[.,]\d+)?)\s*([a-z°/]+)\s*(?:in|to|as)\s*([a-z°/]+)\s*$"#,
            options: .regularExpression
        ) else { return nil }

        let text = String(input[match])
        let pattern = try? NSRegularExpression(
            pattern: #"(?i)^\s*([+-]?\d+(?:[.,]\d+)?)\s*([a-z°/]+)\s*(?:in|to|as)\s*([a-z°/]+)\s*$"#
        )
        guard let regex = pattern,
              let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              result.numberOfRanges == 4,
              let valueRange = Range(result.range(at: 1), in: text),
              let fromRange = Range(result.range(at: 2), in: text),
              let toRange = Range(result.range(at: 3), in: text)
        else { return nil }

        let rawValue = String(text[valueRange]).replacingOccurrences(of: ",", with: ".")
        var from = String(text[fromRange]).lowercased()
        var to = String(text[toRange]).lowercased()
        from = from.replacingOccurrences(of: "°", with: "")
        to = to.replacingOccurrences(of: "°", with: "")
        if from == "celsius" { from = "c" }
        if from == "fahrenheit" { from = "f" }
        if from == "kelvin" { to = to == "kelvin" ? "k" : to }
        if to == "celsius" { to = "c" }
        if to == "fahrenheit" { to = "f" }
        if to == "kelvin" { to = "k" }

        guard let number = Double(rawValue),
              let source = units[from],
              let target = units[to],
              source.dimension == target.dimension
        else { return nil }

        let baseValue = number * source.factor + source.offset
        let converted = (baseValue - target.offset) / target.factor
        guard converted.isFinite else { return nil }

        let formatted = "\(format(converted)) \(displayUnit(to, dimension: source.dimension))"
        return CalculatorResult(
            value: converted,
            formatted: formatted,
            expression: "\(format(number)) \(from) → \(displayUnit(to, dimension: source.dimension))"
        )
    }

    private static func displayUnit(_ unit: String, dimension: String) -> String {
        if dimension == "temperature" {
            switch unit {
            case "c": return "°C"
            case "f": return "°F"
            case "k": return "K"
            default: break
            }
        }
        return unit
    }
}
