import SwiftUI
struct OnboardingView: View {
    @ObservedObject var store: WatchStore
    var finish: (Bool) -> Void
    @State private var step = 0
    let titles = ["Welcome to PixelWatch.","Select any area of your screen.","Tell PixelWatch what to watch for.","Get notified when it happens.","Your screen. Your permission."]
    let descriptions = ["Watch anything. Miss nothing.\nA small utility from SHOEV PRODUCTS.","Choose a screen region or an application window.\nUse a small area for focused, efficient monitoring.","Watch for a visual change, text appearing,\ntext disappearing or a status changing.","Keep working. PixelWatch stays in your menu bar\nand records events even without notification permission.","PixelWatch needs Screen Recording access for saved watches.\nAll analysis is local. No audio is recorded.\nmacOS may require a restart after permission is granted."]
    let symbols = ["viewfinder", "rectangle.dashed", "slider.horizontal.3", "bell.badge", "lock.shield"]
    var body: some View {
        VStack(spacing:24) {
            Image(systemName:symbols[step]).font(.system(size:64,weight:.ultraLight)).foregroundStyle(Design.accent)
            Text(LocalizedStringKey(titles[step])).font(.title2.bold())
            Text(LocalizedStringKey(descriptions[step])).multilineTextAlignment(.center).foregroundStyle(.secondary).lineSpacing(5)
            HStack(spacing:6) { ForEach(0..<5) { i in Circle().fill(i == step ? Design.accent : Color.secondary.opacity(0.2)).frame(width:6,height:6) } }
            if step == 4 {
                HStack { Button("Allow Screen Recording") { PermissionService.requestScreen() }; Button("System Settings") { PermissionService.openScreenSettings() } }
                HStack { Button("Later") { complete(false) }; Button("Create First Watch") { complete(true) }.buttonStyle(.borderedProminent).foregroundStyle(Design.actionText) }
            } else { Button("Continue") { step += 1 }.buttonStyle(.borderedProminent).foregroundStyle(Design.actionText).keyboardShortcut(.defaultAction) }
        }.padding(40).frame(width:560,height:450).tint(Design.accent).background(Design.background)
    }
    private func complete(_ create: Bool) { store.data.settings.onboardingComplete = true; store.persist(); finish(create) }
}
