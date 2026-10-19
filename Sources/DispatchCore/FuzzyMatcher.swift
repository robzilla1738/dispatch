import Foundation

public struct FuzzyMatch: Equatable, Sendable {
    public let score: Double
    public let ranges: [Range<Int>]

    public init(score: Double, ranges: [Range<Int>]) {
        self.score = score
        self.ranges = ranges
    }
}

/// A small, fast fuzzy matcher tuned for command palettes.
///
/// Ranking order: exact match, prefix, word-boundary prefix, substring,
/// then subsequence. Subsequence matches reward consecutive characters and
/// word boundaries so "gc" finds "Google Chrome" and "vs" finds "Visual Studio Code".
public enum FuzzyMatcher {
    public static func match(query: String, candidate: String) -> FuzzyMatch? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return FuzzyMatch(score: 0, ranges: []) }

        let foldedQuery = fold(query)
        let foldedCandidate = fold(candidate)
        guard !foldedQuery.isEmpty else { return FuzzyMatch(score: 0, ranges: []) }

        if foldedQuery == foldedCandidate {
            return FuzzyMatch(score: 10_000, ranges: [0..<candidate.count])
        }

        if foldedCandidate.hasPrefix(foldedQuery) {
            let ratio = Double(foldedQuery.count) / Double(max(foldedCandidate.count, 1))
            return FuzzyMatch(score: 8_500 + ratio * 500, ranges: [0..<foldedQuery.count])
        }

        let candidateChars = Array(foldedCandidate)
        let queryChars = Array(foldedQuery)
        let originalCount = candidate.count

        if candidateChars.count >= queryChars.count {
            for start in 0...(candidateChars.count - queryChars.count) {
                var matched = true
                for offset in 0..<queryChars.count where candidateChars[start + offset] != queryChars[offset] {
                    matched = false
                    break
                }
                if matched {
                    let boundary = start == 0 || isBoundary(candidateChars[start - 1])
                    let score = (boundary ? 6_600.0 : 5_200.0)
                        - Double(start) * 4.0
                        + Double(queryChars.count) / Double(max(candidateChars.count, 1)) * 400.0
                    return FuzzyMatch(score: score, ranges: [start..<(start + queryChars.count)])
                }
            }
        }

        // Subsequence matching. Greedily walk the candidate and then compress
        // the result so the highlight ranges look clean.
        var matchedIndices: [Int] = []
        var queryIndex = 0
        for (index, character) in candidateChars.enumerated() {
            guard queryIndex < queryChars.count else { break }
            if character == queryChars[queryIndex] {
                matchedIndices.append(index)
                queryIndex += 1
            }
        }
        guard queryIndex == queryChars.count else { return nil }

        var score = 1_000.0
        var previous = -1
        for index in matchedIndices {
            score += 110
            if previous >= 0 {
                if index == previous + 1 {
                    score += 55
                } else {
                    score -= Double(min(index - previous - 1, 12)) * 3
                }
            }
            if index == 0 || isBoundary(candidateChars[index - 1]) {
                score += 45
            }
            if index < originalCount, Character(String(candidateChars[index])).isUppercase {
                score += 8
            }
            previous = index
        }
        score += Double(queryChars.count) / Double(max(candidateChars.count, 1)) * 300.0

        return FuzzyMatch(score: score, ranges: compress(matchedIndices))
    }

    public static func score(item: CommandItem, query: String) -> FuzzyMatch? {
        let titleMatch = match(query: query, candidate: item.title)
        let subtitleMatch = match(query: query, candidate: item.subtitle).map {
            FuzzyMatch(score: $0.score * 0.38, ranges: $0.ranges)
        }
        let keywordMatches = item.keywords.compactMap { match(query: query, candidate: $0) }

        let bestKeyword = keywordMatches.max { $0.score < $1.score }.map {
            FuzzyMatch(score: $0.score * 0.72, ranges: [])
        }

        let candidates = [titleMatch, subtitleMatch, bestKeyword].compactMap { $0 }
        guard var best = candidates.max(by: { $0.score < $1.score }) else { return nil }

        // If the title only barely matched but the subtitle matched strongly,
        // keep the title's ranges for display purposes.
        if let titleMatch, titleMatch.score >= best.score * 0.5 {
            best = FuzzyMatch(score: best.score, ranges: titleMatch.ranges)
        }
        return best
    }

    private static func fold(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static func isBoundary(_ character: Character) -> Bool {
        character == " " || character == "-" || character == "_" || character == "." ||
            character == "/" || character == ":" || character == "(" || character == "["
    }

    private static func compress(_ indices: [Int]) -> [Range<Int>] {
        guard let first = indices.first else { return [] }
        var ranges: [Range<Int>] = []
        var start = first
        var previous = first
        for index in indices.dropFirst() {
            if index == previous + 1 {
                previous = index
            } else {
                ranges.append(start..<(previous + 1))
                start = index
                previous = index
            }
        }
        ranges.append(start..<(previous + 1))
        return ranges
    }
}

public enum SearchRanking {
    /// Rank a collection of items. `usage` is a score keyed by item id, normally
    /// combining launch count and recency.
    public static func rank(
        items: [CommandItem],
        query: String,
        usage: [String: Double] = [:],
        limit: Int = 80
    ) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return items
                .map { item in
                    SearchResult(
                        item: item,
                        score: (usage[item.id] ?? 0) - Double(item.kind.sortOrder) * 0.001,
                        matchedRanges: []
                    )
                }
                .sorted { lhs, rhs in
                    if abs(lhs.score - rhs.score) > 0.0001 { return lhs.score > rhs.score }
                    return lhs.item.title.localizedStandardCompare(rhs.item.title) == .orderedAscending
                }
                .prefix(limit)
                .map { $0 }
        }

        return items.compactMap { item -> SearchResult? in
            guard let match = FuzzyMatcher.score(item: item, query: trimmed) else { return nil }
            let boost = min(usage[item.id] ?? 0, 40) * 2.2
            return SearchResult(item: item, score: match.score + boost, matchedRanges: match.ranges)
        }
        .sorted { lhs, rhs in
            if abs(lhs.score - rhs.score) > 0.001 { return lhs.score > rhs.score }
            if lhs.item.kind.sortOrder != rhs.item.kind.sortOrder {
                return lhs.item.kind.sortOrder < rhs.item.kind.sortOrder
            }
            return lhs.item.title.localizedStandardCompare(rhs.item.title) == .orderedAscending
        }
        .prefix(limit)
        .map { $0 }
    }
}
