import Foundation
import DispatchCore

public struct EmojiEntry: Identifiable, Equatable, Sendable {
    public var id: String { "\(character)-\(name)" }
    public let character: String
    public let name: String
    public let category: String
    public let aliases: [String]
    public let keywords: [String]
    public let popularity: Double

    public init(
        character: String,
        name: String,
        category: String,
        aliases: [String],
        keywords: [String],
        popularity: Double
    ) {
        self.character = character
        self.name = name
        self.category = category
        self.aliases = aliases
        self.keywords = keywords
        self.popularity = popularity
    }
}

public final class EmojiCatalog {
    public private(set) var entries: [EmojiEntry] = []

    public init() {
        load()
    }

    private func load() {
        guard let url = ResourceLoader.fileURL("emoji", extension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return
        }
        entries = payload.emoji.map {
            EmojiEntry(
                character: $0.s,
                name: $0.n,
                category: $0.c,
                aliases: $0.a ?? [],
                keywords: $0.k ?? [],
                popularity: $0.u ?? 0
            )
        }
    }

    public func search(_ query: String, limit: Int = 120) -> [EmojiEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Array(
                entries
                    .sorted { $0.popularity > $1.popularity }
                    .prefix(limit)
            )
        }

        return entries.compactMap { entry -> (EmojiEntry, Double)? in
            var best: Double?
            let fields = [entry.name] + entry.aliases + entry.keywords
            for field in fields {
                if let match = FuzzyMatcher.match(query: trimmed, candidate: field) {
                    best = max(best ?? 0, match.score)
                }
            }
            if let characterMatch = FuzzyMatcher.match(query: trimmed, candidate: entry.character) {
                best = max(best ?? 0, characterMatch.score - 500)
            }
            // Emoji names are long and numerous; weak subsequence matches such
            // as "rocket" inside "Open Tortoise Shell Bracket" are noise.
            // Keep prefix, substring, token, and strong keyword matches.
            guard let score = best, score >= 2_500 else { return nil }
            return (entry, score + entry.popularity * 4)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(limit)
        .map(\.0)
    }

    public static func categoryTitle(_ category: String) -> String {
        switch category {
        case "smileys_people": return "Smileys & People"
        case "animals_nature": return "Animals & Nature"
        case "food_drink": return "Food & Drink"
        case "travel_places": return "Travel & Places"
        case "activities": return "Activities"
        case "objects": return "Objects"
        case "symbols": return "Symbols"
        case "flags": return "Flags"
        default: return category.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private struct Payload: Decodable {
        let version: Int?
        let emoji: [Item]
    }

    private struct Item: Decodable {
        let s: String
        let c: String
        let n: String
        let a: [String]?
        let k: [String]?
        let u: Double?
    }
}
