import Foundation
public enum TextNormalization {
    public static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
    public static func matches(_ text: String, target: String, full: Bool) -> Bool {
        let value = normalize(text), query = normalize(target)
        guard !query.isEmpty else { return false }
        return full ? value == query : value.contains(query)
    }
}
