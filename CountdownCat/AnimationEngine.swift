import Foundation
import AppKit

enum AnimationEngine {
    private static let fallbackFrames = ["cat", "cat.fill"]
    
    static func interval(for remaining: TimeInterval) -> TimeInterval {
        switch remaining {
        case ..<0: return 1.0
        case 0..<300: return 0.15
        case 300..<3600: return 0.4
        default: return 0.8
        }
    }
    
    static func frame(at index: Int, customNames: [String]) -> NSImage? {
        if !customNames.isEmpty {
            let name = customNames[index % customNames.count]
            let image = ImageImportService.loadImage(named: name)
            image?.size = NSSize(width: 18, height: 18)
            return image
        }
        let name = fallbackFrames[index % fallbackFrames.count]
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        return image
    }
}
