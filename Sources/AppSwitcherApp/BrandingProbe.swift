import AppKit

/// Checks the actual resource loader without starting tracking, accounts or global shortcuts.
@MainActor
enum BrandingProbe {
    static func run() -> Int {
        guard let app = AppBranding.appIcon, app.isValid else {
            print("FAIL branding: approved application icon missing")
            return 1
        }
        guard let menu = AppBranding.menuBarIcon, menu.isTemplate,
              menu.size == NSSize(width: 18, height: 18), menu.accessibilityDescription == "AppSwitcher" else {
            print("FAIL branding: menu template or accessible name invalid")
            return 1
        }
        let reps = menu.representations.compactMap { $0 as? NSBitmapImageRep }
        guard Set(reps.map(\.pixelsWide)) == [18, 36], reps.allSatisfy({ $0.hasAlpha && $0.size == menu.size }) else {
            print("FAIL branding: missing transparent 1x / 2x representations")
            return 1
        }
        if Bundle.main.bundleIdentifier == "com.appswitcher.app" {
            guard Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String == "AppIcon",
                  Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil,
                  app.representations.contains(where: { $0.pixelsWide == 1024 }) else {
                print("FAIL branding: bundled Finder icon or 1024px representation missing")
                return 1
            }
        }
        print("PASS branding: approved app artwork loads; menu uses 18pt template, 1x/2x alpha and accessible name")
        return 0
    }
}
