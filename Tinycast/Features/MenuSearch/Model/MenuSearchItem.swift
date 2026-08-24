import Foundation

struct MenuSearchTarget: Equatable, Sendable {
    let processIdentifier: Int32
    let appName: String
}

struct MenuSearchItem: Identifiable, Equatable, Sendable {
    let title: String
    let menuPath: [String]
    let elementPath: [Int]

    var id: String { elementPath.map(String.init).joined(separator: ".") }
    var parentPath: String { menuPath.joined(separator: " › ") }
    var fullPath: String { (menuPath + [title]).joined(separator: " › ") }

    static func excludingAppleMenu(from items: [Self]) -> [Self] {
        items.filter { $0.elementPath.first != 0 }
    }

    static func matching(_ items: [Self], query rawQuery: String, limit: Int = 200) -> [Self] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Array(items.prefix(limit)) }
        return items.compactMap { item -> (Self, Int)? in
            let titleScore = FuzzyMatch.score(query: query, candidate: item.title)
            let pathScore = FuzzyMatch.score(query: query, candidate: item.fullPath).map { $0 - 1 }
            guard let score = [titleScore, pathScore].compactMap({ $0 }).max() else { return nil }
            return (item, score)
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0.fullPath.localizedCaseInsensitiveCompare($1.0.fullPath) == .orderedAscending
        }
        .prefix(limit)
        .map(\.0)
    }
}
