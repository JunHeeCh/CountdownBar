import Foundation
import AppKit

enum AnimationEngine {
    private static let defaultFrameNames = ["default1", "default2"]
    private static let sfFallbackFrames  = ["cat", "cat.fill"]

    static func interval(for remaining: TimeInterval) -> TimeInterval {
        switch remaining {
        case ..<0:       return 1.0
        case 0..<300:    return 0.15
        case 300..<3600: return 0.4
        default:         return 0.8
        }
    }

    static func frame(at index: Int, customNames: [String]) -> NSImage? {
        let image: NSImage?

        if !customNames.isEmpty {
            // 사용자가 등록한 커스텀 이미지
            let name = customNames[index % customNames.count]
            image = ImageImportService.loadImage(named: name)
        } else {
            // 앱 번들에 포함된 기본 이미지 (image/default1.png, image/default2.png)
            let name = defaultFrameNames[index % defaultFrameNames.count]
            image = bundledImage(named: name)
                ?? sfFallback(at: index)
        }

        return image
    }

    private static func bundledImage(named name: String) -> NSImage? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let inSubdir = resourceURL.appendingPathComponent("image/\(name).png")
        if let image = NSImage(contentsOf: inSubdir) { return image }
        let atRoot = resourceURL.appendingPathComponent("\(name).png")
        return NSImage(contentsOf: atRoot)
    }

    private static func sfFallback(at index: Int) -> NSImage? {
        let name = sfFallbackFrames[index % sfFallbackFrames.count]
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }
}
