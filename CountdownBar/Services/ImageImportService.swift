import AppKit
import UniformTypeIdentifiers

enum ImageImportService {
    private static var framesDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("CountdownBar/Frames", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    /// 파일 선택 창을 띄우고, 선택한 이미지들을 앱 전용 폴더로 복사한 뒤 파일명 배열을 반환
    static func pickImages() -> [String]? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "애니메이션 프레임으로 쓸 이미지를 순서대로 선택하세요"
        
        guard panel.runModal() == .OK else { return nil }
        
        var savedNames: [String] = []
        for (index, url) in panel.urls.enumerated() {
            let fileName = "frame_\(index)_\(UUID().uuidString).png"
            let destination = framesDirectory.appendingPathComponent(fileName)
            if let data = try? Data(contentsOf: url) {
                try? data.write(to: destination)
                savedNames.append(fileName)
            }
        }
        return savedNames.isEmpty ? nil : savedNames
    }
    
    static func loadImage(named fileName: String) -> NSImage? {
        let url = framesDirectory.appendingPathComponent(fileName)
        return NSImage(contentsOf: url)
    }
}
