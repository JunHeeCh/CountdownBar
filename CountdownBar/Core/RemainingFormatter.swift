import Foundation
import SwiftUI

enum DisplayMode: String, CaseIterable {
    case dday = "D-day"
    case duration = "시:분:초"
}

enum RemainingFormatter {
    static func format(_ remaining: TimeInterval, mode: DisplayMode) -> String {
        guard remaining > 0 else { return "종료됨" }
        
        let totalSeconds = Int(remaining)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        switch mode {
        case .dday:
            if days > 0 {
                return String(format: "D-%d %02d:%02d:%02d", days, hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
        case .duration:
            // 항상 총 시간 기준으로만 표시 (일수를 시간에 합산)
            let totalHours = totalSeconds / 3600
            return String(format: "%02d:%02d:%02d", totalHours, minutes, seconds)
        }
    }
    
    static func color(
        for remaining: TimeInterval,
        urgentThreshold: TimeInterval,
        warningThreshold: TimeInterval
    ) -> Color {
        if remaining <= 0 { return .gray }
        if remaining < urgentThreshold { return .red }
        if remaining < warningThreshold { return .orange }
        return .primary
    }
}
