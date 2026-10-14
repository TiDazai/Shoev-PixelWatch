import Foundation

/// One translation resource also feeds the native SwiftUI string catalog.
/// Language is explicit so capture/rule tasks never depend on mutable global locale.
public enum L10n {
    public static let supportedLanguages = ["ru", "en"]
    private static let russian: [String: String] = {
        #if PACKAGE_CORE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "Translations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String:String].self, from: data) else { return [:] }
        return values
    }()
    public static var translatedKeys: Set<String> { Set(russian.keys) }
    public static func text(_ key: String, language: String) -> String {
        guard let translation = russian[key] else { return key }
        if language.hasPrefix("ru") { return translation }
        // Style only known interface templates, before inserting user text.
        return key.replacingOccurrences(of: "\\.(?=\\s|$)", with: "", options: .regularExpression)
    }
    public static func format(_ key: String, _ arguments: CVarArg..., language: String) -> String {
        format(key, arguments: arguments, language: language)
    }
    public static func format(_ key: String, arguments: [CVarArg], language: String) -> String {
        String(format: text(key, language: language), locale: Locale(identifier: language), arguments: arguments)
    }
}
public enum EventPresentation {
    public static func reason(_ event: WatchEvent, language: String) -> String {
        switch event.mode {
        case .visualChange: return L10n.text("The selected area has changed.", language: language)
        case .changeAfterStability: return L10n.text("The area changed after a stable period.", language: language)
        case .textAppears: return L10n.format("\"%@\" appeared in your watched area.", event.target ?? "", language: language)
        case .textDisappears: return L10n.format("\"%@\" disappeared from your watched area.", event.target ?? "", language: language)
        case .textChanges: return L10n.format("Text changed from \"%@\" to \"%@\".", event.previous ?? "", event.current ?? "", language: language)
        case nil:
            // Existing 0.1.0 events predate structured localization metadata.
            for (suffix, key) in [("\" appeared in your watched area.", "\"%@\" appeared in your watched area."), ("\" disappeared from your watched area.", "\"%@\" disappeared from your watched area.")] {
                if event.reason.hasPrefix("\""), event.reason.hasSuffix(suffix) {
                    let target = String(event.reason.dropFirst().dropLast(suffix.count))
                    return L10n.format(key, target, language: language)
                }
            }
            if event.reason.hasPrefix("Text changed from "), let previous = event.previous, let current = event.current {
                return L10n.format("Text changed from \"%@\" to \"%@\".", previous, current, language: language)
            }
            return L10n.text(event.reason, language: language)
        }
    }
    public static func previous(_ event: WatchEvent, language: String) -> String? {
        if event.mode == .visualChange || event.mode == .changeAfterStability {
            return event.previous.map { L10n.text($0, language: language) }
        }
        if event.mode == .textAppears { return L10n.text("Target text not detected", language: language) }
        return event.previous
    }
    public static func current(_ event: WatchEvent, language: String) -> String? {
        if let difference = event.visualDifference {
            return L10n.format("Visual difference: %.1f%%", difference * 100, language: language)
        }
        return event.current
    }
}
