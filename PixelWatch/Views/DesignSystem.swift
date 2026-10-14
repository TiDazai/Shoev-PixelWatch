import SwiftUI

@MainActor enum AppBrand {
    static let logo: NSImage = {
        guard let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("Missing packaged BrandMark.png")
        }
        image.accessibilityDescription = "SHOEV PixelWatch"
        return image
    }()
    static let menuLogo: NSImage = {
        let image = logo.copy() as! NSImage
        image.size = NSSize(width: 20, height: 20)
        image.isTemplate = true
        return image
    }()
}

struct BrandLogo: View {
    var body: some View {
        Image(nsImage: AppBrand.logo).resizable().interpolation(.high).scaledToFit()
            .accessibilityLabel("SHOEV PixelWatch")
    }
}

enum Design {
    // SHOEV SYSTEMS: website palette + a contrast-adjusted gold for native controls.
    static let platinum = Color(nsColor: colour(0xE6E6EC))
    static let silver = adaptive(0x969AA8, 0xB4B5C0)
    static let gold = adaptive(0xA98C57, 0xC2A366)
    static let accent = adaptive(0x856B3F, 0xC2A366)
    static let actionText = adaptive(0xFFFFFF, 0x202128)
    static let background = adaptive(0xF8F8FA, 0x202128)
    static let surface = adaptive(0xEFF0F4, 0x2A2C35)
    static let edge = adaptive(0xD8DAE1, 0x41434E)
    private static func colour(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, alpha: 1)
    }
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            colour(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        })
    }
    static func statusColor(_ status: WatchStatus) -> Color {
        switch status {
        case .active: return .green
        case .triggered: return accent
        case .paused: return .secondary
        case .waitingForSource, .permissionRequired: return .orange
        case .error: return .red
        }
    }
}
struct PreviewImage: View {
    var image: CGImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Design.surface)
            if let image { Image(decorative: image, scale: 1).resizable().scaledToFit().padding(3) }
            else { Image(systemName: "viewfinder").font(.title).foregroundStyle(.tertiary) }
        }.clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Design.edge,lineWidth:1))
    }
}
struct StatusBadge: View {
    let status: WatchStatus
    var body: some View {
        HStack(spacing: 5) { Circle().fill(Design.statusColor(status)).frame(width: 6,height: 6); Text(LocalizedStringKey(status.rawValue)).font(.caption) }
            .foregroundStyle(.secondary)
    }
}
struct RuleFields: View {
    @Binding var rule: WatchRule
    @Environment(\.locale) private var locale
    private var language: String { locale.language.languageCode?.identifier ?? "ru" }
    var body: some View {
        Picker("Watch for", selection: $rule.mode) { ForEach(WatchMode.allCases) { Text(LocalizedStringKey($0.title)).tag($0) } }
        if [.textAppears, .textDisappears].contains(rule.mode) {
            TextField("Text to watch for", text: $rule.text)
            Toggle("Match the entire recognized text", isOn: $rule.fullMatch)
            Text("Case-insensitive. English and Russian text are recognized locally.").font(.caption).foregroundStyle(.secondary)
        }
        if !rule.mode.usesText {
            HStack { Text("Sensitivity"); Slider(value: $rule.sensitivity, in: 0...1); Text("\(Int(rule.sensitivity*100))%").monospacedDigit().frame(width: 42) }
            Picker("Compare with", selection: $rule.compareOriginal) { Text("Last stable state").tag(false); Text("Original frame").tag(true) }
        }
        if rule.mode == .changeAfterStability { Stepper(L10n.format("Stable for %ld seconds", Int(rule.stabilityDuration), language: language), value: $rule.stabilityDuration, in: 2...600, step: 1) }
        Stepper(L10n.format("Check every %.1f seconds", rule.interval, language: language), value: $rule.interval, in: 0.5...300, step: 0.5)
        Stepper(L10n.format("Confirm with %ld checks", rule.confirmations, language: language), value: $rule.confirmations, in: 2...20)
        Stepper(L10n.format("Cooldown: %ld seconds", Int(rule.cooldown), language: language), value: $rule.cooldown, in: 0...86400, step: 5)
        Toggle("Stop after the first event", isOn: $rule.oneShot)
    }
}

/// Observes the store so existing windows update their locale without losing editor state.
struct LocalizedRoot<Content: View>: View {
    @ObservedObject var store: WatchStore
    let content: Content
    var body: some View {
        content.environment(\.locale, Locale(identifier: store.data.settings.language))
            .tint(Design.accent).accentColor(Design.accent)
    }
}
