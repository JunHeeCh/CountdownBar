# CountdownCat — 프로젝트 컨텍스트

## 개요
macOS 메뉴바 상주형 카운트다운 타이머 앱. RunCat(https://github.com/Kyome22/menubar_runcat)의 구조를 참고해 만들고 있음. 목적은 설정한 목표 시각까지 남은 시간을 메뉴바에서 실시간으로 보여주는 것.

## 기술 스택
- Swift + AppKit (일부 SwiftUI 병행)
- 최소 배포 대상: macOS 13+ (MenuBarExtra 사용 이력 있었으나 현재는 순수 AppKit 기반으로 전환)
- 외부 의존성 없음, 순수 네이티브

## 아키텍처

```
CountdownCat/
├── App/
│   ├── CountdownCatApp.swift   # @main, Settings{EmptyView()}만 갖는 껍데기 Scene
│   └── AppDelegate.swift       # 메뉴바 아이템, 설정 패널, 애니메이션 타이머를 전부 소유하는 핵심 컨트롤러
├── Core/
│   ├── AppState.swift          # ObservableObject. 전체 상태의 단일 출처. SyncStatus enum 포함
│   ├── RemainingFormatter.swift # 남은 시간 → 문자열/색상 변환 (순수 함수)
│   └── AnimationEngine.swift   # 남은 시간 → 프레임 전환 간격, 프레임 이미지 계산
├── Features/
│   └── SettingsView.swift      # 설정 패널 내부 SwiftUI 뷰
├── Services/
│   ├── PersistenceService.swift   # UserDefaults 저장/복원
│   └── ImageImportService.swift   # NSOpenPanel로 사용자 이미지를 선택해 Application Support 폴더에 복사·로드
└── CountdownCat.entitlements   # App Sandbox + 네트워크 클라이언트 권한
```

## 핵심 설계 결정 및 이유

1. **MenuBarExtra(SwiftUI) → NSStatusItem(AppKit) 직접 제어로 전환**
   SwiftUI의 `MenuBarExtra`는 메뉴바 텍스트 색상을 커스터마이징할 수 없는 제약이 있어 포기. `NSStatusItem.button.attributedTitle`에 `NSAttributedString`을 직접 넣는 방식으로 전환. 이 방식이 RunCat이 실제로 쓰는 방식과 동일.

2. **목표 시각은 절대 `Date` 하나만 저장, 매 tick마다 재계산**
   `remainingSeconds -= 1` 같은 누적 감산 방식은 절전/일시정지 시 오차가 생기므로 채택하지 않음. `tick()`에서 `Date().addingTimeInterval(serverTimeOffset)`을 기준으로 계산.

3. **메뉴바 텍스트+아이콘은 `attributedTitle` + `NSTextAttachment` 인라인 삽입 방식**
   커스텀 NSView 서브뷰로 폭을 직접 계산하는 방식을 시도했으나 레이스 컨디션 발생으로 폐기. AppKit이 폭 계산을 전담하도록 `.variableLength` 유지.

4. **설정창은 NSPopover → KeyablePanel(NSPanel 서브클래스)로 교체**
   NSPopover는 표시 모드(D-day ↔ 시:분:초) 전환 시 버튼 너비 변화에 따라 위치가 흔들리고, 타 앱 위나 허공에 뜨는 문제가 있었음. NSPanel을 사용해 screen 좌표로 직접 위치를 계산:
   - `button.convert(button.bounds, to: nil)` → `window.convertToScreen()` 으로 실제 screen 좌표 획득
   - `panelX = buttonScreenRect.maxX - panel.frame.width` 로 오른쪽 끝 정렬 (버튼 너비와 무관하게 고정)
   - `.borderless` styleMask + `canBecomeKey = true` override → 텍스트 필드 입력 가능
   - `NSApp.activate(ignoringOtherApps: true)` 로 키보드 이벤트 수신 보장
   - `NSEvent.addGlobalMonitorForEvents` 로 외부 클릭 시 닫기

5. **설정 패널 배경: `panel.backgroundColor = .clear` + SwiftUI `clipShape(RoundedRectangle(cornerRadius: 12))`**
   NSPanel 자체 배경 대신 SwiftUI 레이어에서 둥근 모서리 처리.

6. **표시 형식은 `DisplayMode` enum (dday / duration)으로 분리**, 사용자가 세그먼트 Picker로 전환 가능.

7. **임박도에 따른 색상 변화**: `urgentThresholdMinutes`(기본 5분, 빨강), `warningThresholdMinutes`(기본 60분, 주황). `RemainingFormatter.color(for:urgentThreshold:warningThreshold:)`가 순수 함수로 계산.

8. **애니메이션은 커스텀 이미지 우선, 없으면 SF Symbol(`cat`/`cat.fill`) 폴백**.
   - 남은 시간에 따라 속도 변화 (임박할수록 빠르게)
   - `remaining <= 0` 이면 타이머 정지 + `frameIndex = 0` 고정 (첫 프레임 정지)

9. **서버 시간 동기화 (선택적 기능)**
   - 매 앱 실행 시 1회 동기화, 이후 오프셋을 메모리에만 보관 (UserDefaults에 저장하지 않음 — macOS 자체 NTP가 로컬 시계를 수정하면 저장된 오프셋이 틀려지기 때문)
   - HTTP HEAD 요청 → 응답 `Date` 헤더 파싱 → 왕복 지연의 절반을 보정해 오프셋 계산
   - 실패 시 `serverTimeOffset = 0` 으로 폴백 (로컬 시간 그대로 사용)
   - URL, on/off 토글은 UserDefaults에 영속화
   - App Sandbox 환경에서 네트워크를 사용하려면 `CountdownCat.entitlements`에 `com.apple.security.network.client = true` 필수

10. **DatePicker 로케일: `Locale.Components(identifier: "ko_KR")` + `hourCycle = .zeroToTwentyThree`**
    한국식 년/월/일 순서 + 24시간제 강제 적용. 시스템 설정과 무관하게 항상 24시간으로 표시.

## 현재 구현 완료 상태
- [x] 목표 시각 설정 (DatePicker, 한국식 년월일 + 24시간제)
- [x] 실시간 카운트다운 (1초 tick)
- [x] D-day / 시:분:초 표시 전환
- [x] UserDefaults 기반 영속화 (목표 시각, 표시모드, 임계값, 아이콘 표시여부, 커스텀 프레임, 서버시간 설정)
- [x] 임박도별 메뉴바 텍스트 색상 변화 (임계값 슬라이더로 조절 가능)
- [x] 아이콘 표시 on/off 토글
- [x] 사용자 커스텀 이미지 등록 (NSOpenPanel, .image 타입 전체 허용)
- [x] 커스텀/기본 이미지 애니메이션 (남은 시간에 따라 속도 변화, 종료 후 정지)
- [x] 설정창 위치 안정화 (NSPanel + screen 좌표 기반 오른쪽 끝 정렬)
- [x] 설정창 둥근 모서리
- [x] 서버 시간 동기화 (URL 입력, 토글, 수동 재동기화, 동기화 시각/오프셋 표시)

## 알려진 미해결/보류 이슈
- `RemainingFormatter.color`에서 `urgentThreshold >= warningThreshold`로 슬라이더를 설정할 경우 `switch` 구간이 역전되어 런타임 이슈 가능성 있음. 방어 로직(min/max 클램핑 또는 UI 레벨 제약) 미적용.

## 다음 단계 후보 (미정, 우선순위 논의 필요)
- 앱 아이콘 설정
- 로그인 시 자동 실행
- 임계값 역전 방어 로직
- 코드 정리 및 불필요 파일(`StatusBarContentView.swift` 등 이전 시도의 잔재) 정리

## 개발자 배경 참고
- 백엔드(Java/Spring) 개발자, macOS 네이티브 개발은 이번이 처음
- Swift/AppKit 개념을 백엔드 유사 개념에 빗대어 설명받는 방식으로 학습 중
