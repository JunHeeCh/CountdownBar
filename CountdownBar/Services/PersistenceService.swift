import Foundation

enum PersistenceService {
    private static let targetDateKey = "targetDate"
    private static let displayModeKey = "displayMode"
    private static let urgentThresholdKey = "urgentThresholdMinutes"
    private static let warningThresholdKey = "warningThresholdMinutes"
    private static let showIconKey = "showIcon"
    private static let customFrameNamesKey = "customFrameNames"
    private static let useServerTimeKey = "useServerTime"
    private static let serverTimeURLKey = "serverTimeURL"
    private static let memoKey = "memo"
    
    static func saveTargetDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: targetDateKey)
    }
    
    static func loadTargetDate() -> Date? {
        UserDefaults.standard.object(forKey: targetDateKey) as? Date
    }
    
    static func saveDisplayMode(_ mode: DisplayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey)
    }
    
    static func loadDisplayMode() -> DisplayMode? {
        guard let raw = UserDefaults.standard.string(forKey: displayModeKey) else { return nil }
        return DisplayMode(rawValue: raw)
    }
    
    static func saveUrgentThreshold(_ minutes: Double) {
        UserDefaults.standard.set(minutes, forKey: urgentThresholdKey)
    }
    
    static func loadUrgentThreshold() -> Double? {
        UserDefaults.standard.object(forKey: urgentThresholdKey) as? Double
    }

    static func saveWarningThreshold(_ minutes: Double) {
        UserDefaults.standard.set(minutes, forKey: warningThresholdKey)
    }

    static func loadWarningThreshold() -> Double? {
        UserDefaults.standard.object(forKey: warningThresholdKey) as? Double
    }
    
    static func saveShowIcon(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: showIconKey)
    }

    static func loadShowIcon() -> Bool? {
        UserDefaults.standard.object(forKey: showIconKey) as? Bool
    }

    static func saveCustomFrameNames(_ names: [String]) {
        UserDefaults.standard.set(names, forKey: customFrameNamesKey)
    }

    static func loadCustomFrameNames() -> [String]? {
        UserDefaults.standard.stringArray(forKey: customFrameNamesKey)
    }

    static func saveUseServerTime(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: useServerTimeKey)
    }

    static func loadUseServerTime() -> Bool? {
        UserDefaults.standard.object(forKey: useServerTimeKey) as? Bool
    }

    static func saveServerTimeURL(_ value: String) {
        UserDefaults.standard.set(value, forKey: serverTimeURLKey)
    }

    static func loadServerTimeURL() -> String? {
        UserDefaults.standard.string(forKey: serverTimeURLKey)
    }

    static func saveMemo(_ value: String) {
        UserDefaults.standard.set(value, forKey: memoKey)
    }

    static func loadMemo() -> String? {
        UserDefaults.standard.string(forKey: memoKey)
    }
}
