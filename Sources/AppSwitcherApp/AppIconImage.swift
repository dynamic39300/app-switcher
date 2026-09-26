import AppKit

enum AppIconImage {
    /// 保留系统图标的多分辨率表示，避免 SwiftUI 按默认 32pt 图像尺寸取图后再放大。
    static func prepared(_ image: NSImage) -> NSImage {
        guard image.size.width > 0, image.size.height > 0,
              let copy = image.copy() as? NSImage else { return image }
        let scale = max(1, 256 / max(image.size.width, image.size.height))
        copy.size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        return copy
    }
}
