import Foundation
import Combine
import SwiftUI

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case failed

    var label: String {
        switch self {
        case .idle:    return "동기화 필요"
        case .syncing: return "동기화 중..."
        case .synced:  return "동기화 완료"
        case .failed:  return "실패 · 로컬 시간 사용"
        }
    }

    var color: Color {
        switch self {
        case .idle:    return .secondary
        case .syncing: return .orange
        case .synced:  return .green
        case .failed:  return .red
        }
    }
}

class AppState: ObservableObject {
    @Published var displayText: String = "설정 필요"
    @Published var remaining: TimeInterval = 0
    
    @Published var targetDate: Date {
        didSet { PersistenceService.saveTargetDate(targetDate) }
    }
    
    @Published var displayMode: DisplayMode {
        didSet { PersistenceService.saveDisplayMode(displayMode) }
    }
    
    @Published var urgentThresholdMinutes: Double {
        didSet { PersistenceService.saveUrgentThreshold(urgentThresholdMinutes) }
    }
    
    @Published var warningThresholdMinutes: Double {
        didSet { PersistenceService.saveWarningThreshold(warningThresholdMinutes) }
    }
    
    @Published var showIcon: Bool {
        didSet { PersistenceService.saveShowIcon(showIcon) }
    }

    @Published var customFrameNames: [String] {
        didSet { PersistenceService.saveCustomFrameNames(customFrameNames) }
    }

    @Published var memo: String {
        didSet { PersistenceService.saveMemo(memo) }
    }

    @Published var useServerTime: Bool {
        didSet {
            PersistenceService.saveUseServerTime(useServerTime)
            if !useServerTime {
                serverTimeOffset = 0
                syncStatus = .idle
            }
        }
    }

    @Published var serverTimeURL: String {
        didSet {
            PersistenceService.saveServerTimeURL(serverTimeURL)
            // URL이 바뀌면 기존 동기화 무효화
            syncStatus = .idle
            serverTimeOffset = 0
        }
    }

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncTime: Date? = nil
    var serverTimeOffset: TimeInterval = 0

    private var timer: Timer?
    private static let httpDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()
    
    init() {
        self.targetDate = PersistenceService.loadTargetDate() ?? Date().addingTimeInterval(3600)
        self.displayMode = PersistenceService.loadDisplayMode() ?? .dday
        self.urgentThresholdMinutes = PersistenceService.loadUrgentThreshold() ?? 5
        self.warningThresholdMinutes = PersistenceService.loadWarningThreshold() ?? 60
        self.showIcon = PersistenceService.loadShowIcon() ?? true
        self.customFrameNames = PersistenceService.loadCustomFrameNames() ?? []
        self.memo = PersistenceService.loadMemo() ?? ""
        self.useServerTime = PersistenceService.loadUseServerTime() ?? false
        self.serverTimeURL = PersistenceService.loadServerTimeURL() ?? ""
        start()
        if useServerTime && !serverTimeURL.isEmpty {
            Task { await self.syncServerTime() }
        }
    }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        let now = Date().addingTimeInterval(serverTimeOffset)
        let newRemaining = targetDate.timeIntervalSince(now)
        if newRemaining <= 0 && remaining <= 0 { return }
        remaining = newRemaining
        displayText = RemainingFormatter.format(remaining, mode: displayMode)
    }

    @MainActor
    func syncServerTime() async {
        guard useServerTime, !serverTimeURL.isEmpty, let url = URL(string: serverTimeURL) else {
            syncStatus = .idle
            serverTimeOffset = 0
            return
        }

        syncStatus = .syncing

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        let t1 = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let t2 = Date()

            guard let httpResponse = response as? HTTPURLResponse,
                  let dateString = httpResponse.value(forHTTPHeaderField: "Date"),
                  let serverDate = parseHTTPDate(dateString) else {
                syncStatus = .failed
                return
            }

            let oneWayDelay = t2.timeIntervalSince(t1) / 2
            serverTimeOffset = serverDate.addingTimeInterval(oneWayDelay).timeIntervalSince(t2)
            lastSyncTime = t2
            syncStatus = .synced
        } catch {
            syncStatus = .failed
            serverTimeOffset = 0
        }
    }

    private func parseHTTPDate(_ string: String) -> Date? {
        Self.httpDateFormatter.date(from: string)
    }
    
    var color: Color {
        RemainingFormatter.color(
            for: remaining,
            urgentThreshold: urgentThresholdMinutes * 60,
            warningThreshold: warningThresholdMinutes * 60
        )
    }
}
