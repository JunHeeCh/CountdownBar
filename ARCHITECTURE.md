# CountdownBar — 아키텍처 문서

## 파일 구조

```
CountdownBar/
├── App/
│   ├── CountdownBarApp.swift   # 앱 진입점 (@main). AppDelegate를 연결하는 껍데기
│   └── AppDelegate.swift       # 메뉴바 아이템, 설정 패널, 애니메이션 타이머 소유
├── Core/
│   ├── AppState.swift          # 전체 상태의 단일 출처 (ObservableObject)
│   ├── RemainingFormatter.swift # 남은 시간 → 문자열/색상 변환 (순수 함수)
│   └── AnimationEngine.swift   # 남은 시간 → 프레임 이미지/전환 간격 계산 (순수 함수)
├── Features/
│   └── SettingsView.swift      # 설정 패널 SwiftUI 뷰
└── Services/
    ├── PersistenceService.swift   # UserDefaults 저장/복원
    └── ImageImportService.swift   # 사용자 이미지 선택 및 Application Support 저장
```

---

## 전체 데이터 흐름 (큰 그림)

```
앱 시작
  └─▶ CountdownBarApp (@main)
        └─▶ AppDelegate.applicationDidFinishLaunching()
              ├─▶ NSStatusItem 생성 (메뉴바 아이템)
              ├─▶ KeyablePanel 생성 (설정 패널)
              ├─▶ AppState 초기화
              │     └─▶ PersistenceService에서 이전 설정 복원
              │     └─▶ Timer 시작 (1초 tick)
              └─▶ AppState 구독 (Combine)
                    └─▶ remaining 변경 시 → render() + rescheduleAnimation()

매 1초 (tick 사이클)
  AppState.tick()
    ├─▶ Date() + serverTimeOffset → 현재 시각 계산
    ├─▶ targetDate - now → remaining 갱신
    └─▶ RemainingFormatter.format() → displayText 갱신
          └─▶ @Published 변경 감지 → AppDelegate.render() 호출
                └─▶ NSStatusItem.button.attributedTitle 갱신 (메뉴바 표시)
```

---

## 기능별 동작 흐름

### 1. 카운트다운 타이머

```
AppState.init()
  └─▶ start() → Timer(interval: 1초, repeats: true)
        └─▶ tick() 매 1초 실행
              ├─▶ remaining = targetDate.timeIntervalSince(Date() + offset)
              ├─▶ remaining <= 0 && 이미 종료 상태? → return (불필요한 업데이트 차단)
              └─▶ displayText = RemainingFormatter.format(remaining, mode)
```

**DisplayMode 별 포맷:**
| 모드 | 예시 |
|------|------|
| D-day | `D-3 14:22:05` / `00:22:05` (당일) |
| 시:분:초 | `86:22:05` (총 시간 기준) |
| 종료 | `종료됨` |

---

### 2. 메뉴바 렌더링

```
AppState.$remaining 변경
  └─▶ AppDelegate (Combine CombineLatest3 구독)
        └─▶ render()
              ├─▶ showIcon == true?
              │     └─▶ AnimationEngine.frame(at: frameIndex, customNames:)
              │           ├─▶ customFrameNames 있으면 → Application Support에서 이미지 로드
              │           └─▶ 없으면 → SF Symbol (cat / cat.fill) 폴백
              │     └─▶ NSTextAttachment로 이미지를 텍스트 앞에 인라인 삽입
              ├─▶ RemainingFormatter.color() → NSColor 결정
              │     ├─▶ remaining < 0        → gray
              │     ├─▶ < urgentThreshold    → red
              │     ├─▶ < warningThreshold   → orange
              │     └─▶ 그 외               → primary
              └─▶ NSAttributedString 조합 → statusItem.button.attributedTitle 갱신
```

텍스트와 아이콘을 `NSAttributedString` 하나로 합쳐 AppKit이 버튼 폭 계산을 전담하게 함 → 메뉴바 위치 안정.

---

### 3. 아이콘 애니메이션

```
AppDelegate.rescheduleAnimation(remaining:)
  ├─▶ showIcon == false → 타이머 중단
  ├─▶ remaining <= 0   → 타이머 중단, frameIndex = 0 고정 (첫 프레임 정지)
  └─▶ remaining > 0    → AnimationEngine.interval(remaining) 으로 간격 계산
        ├─▶ < 5분  → 0.15초 (빠르게)
        ├─▶ < 1시간 → 0.40초
        └─▶ 그 외  → 0.80초 (느리게)
        └─▶ 간격이 바뀐 경우만 Timer 재생성
              └─▶ 매 interval마다 frameIndex++ → render() → 다음 프레임 표시
```

---

### 4. 설정 패널 열기/닫기

```
사용자가 메뉴바 아이템 클릭
  └─▶ AppDelegate.togglePanel()
        ├─▶ panel.isVisible == true → closePanel() (패널 닫기 + eventMonitor 해제)
        └─▶ panel.isVisible == false → 열기
              ├─▶ button.convert(bounds, to: nil) + window.convertToScreen()
              │     → 버튼의 실제 screen 좌표 획득
              ├─▶ panel.contentViewController.view.layout() → fittingSize 계산
              ├─▶ panelX = buttonScreenRect.maxX - panel.width  (오른쪽 끝 정렬)
              │     * 버튼 텍스트 길이와 무관하게 항상 같은 X 좌표 유지
              ├─▶ panelY = buttonScreenRect.minY - panel.height (메뉴바 바로 아래)
              ├─▶ panel.makeKeyAndOrderFront() + NSApp.activate()
              └─▶ NSEvent.addGlobalMonitorForEvents → 외부 클릭 시 closePanel()
```

**KeyablePanel (NSPanel 서브클래스)**
- `canBecomeKey = true` override → `.borderless` 패널에서도 텍스트 입력 가능

---

### 5. 서버 시간 동기화

```
토글 ON 또는 "지금 동기화" 버튼 클릭
  └─▶ AppState.syncServerTime() [@MainActor async]
        ├─▶ syncStatus = .syncing
        ├─▶ URLRequest(HEAD, timeout: 5초) → 해당 URL로 요청
        ├─▶ t1 = 요청 직전 로컬 시각
        ├─▶ t2 = 응답 수신 직후 로컬 시각
        ├─▶ httpResponse.value("Date") → parseHTTPDate() → serverDate
        ├─▶ oneWayDelay = (t2 - t1) / 2   (편도 네트워크 지연 추정)
        ├─▶ serverTimeOffset = (serverDate + oneWayDelay) - t2
        │     * 이후 tick()에서 Date() + serverTimeOffset = 서버 기준 현재 시각
        ├─▶ lastSyncTime = t2, syncStatus = .synced
        └─▶ 실패 시 → serverTimeOffset = 0 (로컬 시간 폴백), syncStatus = .failed

오프셋 적용 (tick 내부):
  now = Date() + serverTimeOffset
  remaining = targetDate.timeIntervalSince(now)
```

**설계 원칙:**
- 오프셋은 메모리에만 보관, UserDefaults에 저장 안 함
  → macOS 자체 NTP가 로컬 시계를 수정하면 저장된 오프셋이 틀려지기 때문
- 앱 시작 시 자동 동기화 1회, 이후는 수동 또는 URL 변경 시

---

### 6. 설정값 영속화

```
사용자가 설정 변경
  └─▶ AppState @Published 프로퍼티 didSet
        └─▶ PersistenceService.saveXxx() → UserDefaults.standard.set()

앱 재시작
  └─▶ AppState.init()
        └─▶ PersistenceService.loadXxx() → UserDefaults에서 복원

영속화 대상:
  targetDate, displayMode, urgentThresholdMinutes, warningThresholdMinutes,
  showIcon, customFrameNames, memo, useServerTime, serverTimeURL
```

---

### 7. 커스텀 애니메이션 이미지 등록

```
사용자가 "애니메이션 이미지 등록" 버튼 클릭
  └─▶ ImageImportService.pickImages()
        ├─▶ NSOpenPanel (다중 선택, 이미지 파일 전체 허용)
        ├─▶ 선택된 이미지를 Application Support/CountdownBar/Frames/ 에 복사
        └─▶ 파일명 배열 반환
              └─▶ appState.customFrameNames = 파일명 배열
                    └─▶ PersistenceService.saveCustomFrameNames()

이후 AnimationEngine.frame(at: index, customNames:)
  ├─▶ customNames 있으면 → ImageImportService.loadImage(named:) 로 로드
  └─▶ 없으면 → 번들 기본 이미지(default1/2.png) → 없으면 SF Symbol(cat/cat.fill) 폴백
```

---

### 8. 메모

```
사용자가 메모 영역 클릭
  └─▶ isEditingMemo = true → TextField 표시 + 자동 포커스
        ├─▶ Enter 입력 → onSubmit → isEditingMemo = false
        └─▶ 패널 내 다른 곳 클릭
              └─▶ background onTapGesture
                    ├─▶ NSApp.keyWindow?.makeFirstResponder(nil)  (AppKit 포커스 해제)
                    └─▶ isEditingMemo = false

appState.$memo 변경
  └─▶ AppDelegate Combine 구독
        └─▶ statusItem.button?.toolTip 갱신 (빈 문자열이면 nil)

영속화: PersistenceService.saveMemo() → UserDefaults
```

---

## 상태 의존 관계

```
PersistenceService   (저장소, 순수 함수)
        ↑
    AppState         (단일 상태 출처, ObservableObject)
        ↑                          ↑
  AppDelegate        ←——Combine——— AppState.$remaining
  (렌더링, 패널)                   AppState.$showIcon
        ↓                          AppState.$customFrameNames
  AnimationEngine    (순수 함수, 이미지/간격 계산)        AppState.$memo → toolTip 갱신
  RemainingFormatter (순수 함수, 텍스트/색상 계산)
        ↑
  SettingsView       (SwiftUI, @ObservedObject appState)
  ImageImportService (파일 선택/복사, 독립적)
```
