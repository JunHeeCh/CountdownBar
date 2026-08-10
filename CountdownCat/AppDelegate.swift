import AppKit
import SwiftUI
import Combine

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    private var settingsPanel: NSPanel?
    private var eventMonitor: Any?
    let appState = AppState()
    private var cancellables = Set<AnyCancellable>()

    private var animationTimer: Timer?
    private var frameIndex = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.target = self

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 320),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        let contentView = SettingsView(appState: appState)
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        panel.contentViewController = NSHostingController(rootView: contentView)
        settingsPanel = panel
        
        Publishers.CombineLatest4(
            appState.$displayText,
            appState.$remaining,
            appState.$showIcon,
            appState.$customFrameNames
        )
        .sink { [weak self] text, remaining, showIcon, _ in
            guard let self = self else { return }
            self.render()
            self.rescheduleAnimation(for: remaining)
        }
        .store(in: &cancellables)
        
        render()
    }
    
    /// 텍스트 + 아이콘을 하나의 attributedTitle로 합쳐서 AppKit이 폭 계산을 전담하게 함
    private func render() {
        let fullString = NSMutableAttributedString()
        
        if appState.showIcon {
            let image = AnimationEngine.frame(at: frameIndex, customNames: appState.customFrameNames)
            image?.size = NSSize(width: 16, height: 16)
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: -3, width: 16, height: 16)
            fullString.append(NSAttributedString(attachment: attachment))
            fullString.append(NSAttributedString(string: " "))
        }
        
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor(appState.color)
        ]
        fullString.append(NSAttributedString(string: appState.displayText, attributes: textAttrs))
        
        statusItem.button?.attributedTitle = fullString
        statusItem.button?.image = nil  // 이미지가 title에 이미 포함되어 있으니 별도 image 속성은 비움
    }
    
    private func rescheduleAnimation(for remaining: TimeInterval) {
        guard appState.showIcon else {
            animationTimer?.invalidate()
            animationTimer = nil
            return
        }

        // 종료 후엔 첫 프레임에서 정지
        if remaining <= 0 {
            animationTimer?.invalidate()
            animationTimer = nil
            frameIndex = 0
            render()
            return
        }

        let newInterval = AnimationEngine.interval(for: remaining)
        guard animationTimer == nil || animationTimer!.timeInterval != newInterval else { return }

        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: newInterval, repeats: true) { [weak self] _ in
            self?.frameIndex += 1
            self?.render()
        }
    }
    
    @objc private func togglePanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let panel = settingsPanel else { return }

        if panel.isVisible {
            closePanel()
            return
        }

        // 버튼의 실제 screen 좌표를 구함
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonScreenRect = buttonWindow.convertToScreen(buttonRectInWindow)

        // 패널 크기를 콘텐츠에 맞게 조정
        panel.contentViewController?.view.layout()
        let fittingSize = panel.contentViewController?.view.fittingSize ?? NSSize(width: 260, height: 320)
        panel.setContentSize(fittingSize)

        // 오른쪽 끝 정렬: 패널 우측 = 버튼 우측 (screen 기준으로 항상 고정)
        let x = buttonScreenRect.maxX - panel.frame.width
        let y = buttonScreenRect.minY - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 패널 바깥 클릭 시 닫기
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        settingsPanel?.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}


