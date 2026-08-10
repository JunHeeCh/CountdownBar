import SwiftUI

private let syncTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M월 d일 HH:mm:ss"
    return f
}()

private let koreanLocale24h: Locale = {
    var components = Locale.Components(identifier: "ko_KR")
    components.hourCycle = .zeroToTwentyThree
    return Locale(components: components)
}()

private func offsetLabel(_ offset: TimeInterval) -> String {
    if abs(offset) < 0.05 { return "오차 없음" }
    return String(format: "%+.2f초 보정", offset)
}

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var isEditingMemo = false
    @FocusState private var memoFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isEditingMemo {
                TextField("메모 (예: 콘서트, 지원서 마감)", text: $appState.memo)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .focused($memoFocused)
                    .onSubmit { isEditingMemo = false }
                    .onAppear { memoFocused = true }
                    .onChange(of: appState.memo) { newValue in
                        if newValue.count > 20 {
                            appState.memo = String(newValue.prefix(20))
                        }
                    }
            } else {
                Button {
                    isEditingMemo = true
                } label: {
                    HStack(spacing: 4) {
                        Text(appState.memo.isEmpty ? "메모 추가..." : appState.memo)
                            .font(.caption)
                            .foregroundColor(appState.memo.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Text("목표 시각 설정")
                .font(.headline)

            DatePicker(
                "",
                selection: $appState.targetDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.field)
            .labelsHidden()
            .environment(\.locale, koreanLocale24h)

            Picker("표시 방식", selection: $appState.displayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("빨강 기준: \(Int(appState.urgentThresholdMinutes))분 이내")
                    .font(.caption)
                Slider(value: $appState.urgentThresholdMinutes, in: 1...30, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("주황 기준: \(Int(appState.warningThresholdMinutes))분 이내")
                    .font(.caption)
                Slider(value: $appState.warningThresholdMinutes, in: 10...180, step: 5)
            }
            
            Toggle("아이콘 표시", isOn: $appState.showIcon)

            Button(appState.customFrameNames.isEmpty ? "애니메이션 이미지 등록" : "이미지 다시 등록 (\(appState.customFrameNames.count)장)") {
                if let names = ImageImportService.pickImages() {
                    appState.customFrameNames = names
                }
            }
            
            Divider()

            Toggle("서버 시간 기준", isOn: $appState.useServerTime)
                .onChange(of: appState.useServerTime) { enabled in
                    if enabled && !appState.serverTimeURL.isEmpty {
                        Task { await appState.syncServerTime() }
                    }
                }

            if appState.useServerTime {
                TextField("https://naver.com", text: $appState.serverTimeURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.syncStatus.label)
                            .font(.caption)
                            .foregroundColor(appState.syncStatus.color)
                        if appState.syncStatus == .synced, let syncTime = appState.lastSyncTime {
                            Text("\(syncTime, formatter: syncTimeFormatter)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(offsetLabel(appState.serverTimeOffset))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button("지금 동기화") {
                        Task { await appState.syncServerTime() }
                    }
                    .font(.caption)
                    .disabled(appState.syncStatus == .syncing || appState.serverTimeURL.isEmpty)
                }
            }

            Divider()

            Button("종료") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 240)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    isEditingMemo = false
                }
        )
    }
}
