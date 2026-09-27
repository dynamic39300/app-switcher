import AppKit
import SwiftUI

/// The app bundle carries the approved artwork; Debug previews can read the same source assets.
enum AppBranding {
    static let appIcon: NSImage? = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            return NSImage(contentsOf: url)
        }
        #if DEBUG
        return NSImage(contentsOf: sourceDirectory.appendingPathComponent("app-icon-master.png"))
        #else
        return nil
        #endif
    }()

    static let menuBarIcon: NSImage? = {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        for (name, pixels) in [("menu-bar-template", 18), ("menu-bar-template@2x", 36)] {
            guard let url = resource(name), let data = try? Data(contentsOf: url),
                  let rep = NSBitmapImageRep(data: data), rep.pixelsWide == pixels, rep.pixelsHigh == pixels else { return nil }
            rep.size = image.size
            image.addRepresentation(rep)
        }
        image.isTemplate = true
        image.accessibilityDescription = "AppSwitcher"
        return image
    }()

    private static func resource(_ name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") { return url }
        #if DEBUG
        return sourceDirectory.appendingPathComponent(name + ".png")
        #else
        return nil
        #endif
    }

    #if DEBUG
    private static let sourceDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("assets/branding", isDirectory: true)
    #endif
}

struct AppBrandMark: View {
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let icon = AppBranding.appIcon {
                Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
            } else {
                // Keep a damaged development bundle usable; packaged builds verify the assets.
                Image(systemName: "diamond").resizable().scaledToFit().padding(6)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
