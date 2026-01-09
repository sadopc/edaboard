import Foundation

extension String {

    /// Case-insensitive contains check with localized comparison
    func localizedCaseInsensitiveContains(_ other: String) -> Bool {
        return self.range(of: other, options: .caseInsensitive, locale: .current) != nil
    }

    /// Fuzzy search matching - checks if all characters of query appear in order
    func fuzzyMatches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }

        var searchIndex = self.startIndex
        for char in query.lowercased() {
            guard let foundIndex = self[searchIndex...].lowercased().firstIndex(of: char) else {
                return false
            }
            searchIndex = self.index(after: foundIndex)
        }
        return true
    }

    /// Returns a fuzzy match score (higher is better match)
    func fuzzyMatchScore(_ query: String) -> Int {
        guard !query.isEmpty else { return 100 }
        guard self.fuzzyMatches(query) else { return 0 }

        let lowercasedSelf = self.lowercased()
        let lowercasedQuery = query.lowercased()

        var score = 0

        // Bonus for exact contains
        if lowercasedSelf.contains(lowercasedQuery) {
            score += 50
        }

        // Bonus for prefix match
        if lowercasedSelf.hasPrefix(lowercasedQuery) {
            score += 30
        }

        // Bonus for word boundary matches
        let words = lowercasedSelf.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        for word in words {
            if String(word).hasPrefix(lowercasedQuery) {
                score += 20
                break
            }
        }

        // Penalty for length difference (prefer shorter matches)
        let lengthDiff = self.count - query.count
        score -= min(lengthDiff, 10)

        // Base score for matching
        score += 10

        return max(score, 1)
    }

    /// Highlights search matches in the string (returns attributed string ranges)
    func highlightRanges(for query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        var searchStart = self.startIndex

        while searchStart < self.endIndex {
            if let range = self.range(of: query, options: .caseInsensitive, range: searchStart..<self.endIndex) {
                ranges.append(range)
                searchStart = range.upperBound
            } else {
                break
            }
        }

        return ranges
    }

    /// Truncates string to specified length with ellipsis
    func truncated(to length: Int, trailing: String = "…") -> String {
        guard self.count > length else { return self }
        return String(self.prefix(length)) + trailing
    }

    /// Removes excessive whitespace and newlines
    var normalizedWhitespace: String {
        return self
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Computes SHA256 hash of the string
    var sha256Hash: String {
        guard let data = self.data(using: .utf8) else { return "" }
        return data.sha256Hash
    }
}

extension Data {

    /// Computes SHA256 hash of the data
    var sha256Hash: String {
        var hash = [UInt8](repeating: 0, count: 32)

        self.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            CC_SHA256(baseAddress, CC_LONG(self.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
