---
name: store-screenshot
description: 마작한판(mahjong_joy) 앱의 스토어 등록용 스크린샷을 실기기에서 캡처한다. "스크린샷 만들어줘", "스토어 스크린샷 찍어줘", "홈/게임플레이/설명서 화면 캡처해줘" 등의 요청에 사용. adb로 캡처한 원본에서 상태바(위)와 내비게이션 바(아래)를 크롭해 store/<lang>/screenshots/ 규격(1080x2115)에 맞춰 저장한다.
---

# 스토어 스크린샷 캡처

USB로 연결된 안드로이드 실기기에서 마작한판 앱을 조작해 `store/<lang>/screenshots/`에
쓸 스크린샷을 찍는다. 상태바·내비게이션 바가 전혀 안 보이는 순수 앱 화면만 남긴다.

## 핵심 정보

- 패키지: `com.backdev.mahjonghanpan`
- 기준 기기: SM-S731N, 물리 해상도 1080×2340 (`adb shell wm size`로 매번 확인)
- 최종 규격: **1080×2115** — 원본에서 위 100px(상태바), 아래 125px(제스처 바) 제거
- 크롭 스크립트: `.claude/skills/store-screenshot/crop.py` (시스템 `python3`에 Pillow 이미 설치돼 있음, venv 불필요)
- 저장 위치: `store/<lang>/screenshots/<번호>_<이름>_<lang>.png`
  - 언어 폴더: `ko`, `en`, `zh`, `ja`
  - 기존 파일명 예: `01_home_ko.png`, `02_gameplay_ko.png`, `03_howto_ko.png` (ko/en/ja는 3장, zh는 클레임 타이머 장면이 추가로 있어 4장)

## 0. 기기 확인

```bash
flutter devices   # 또는: adb devices -l
```

여러 기기가 잡힐 수 있으므로 이후 **모든 adb 명령에 `-s <serial>`을 명시**한다.
아래 예시는 `$DEV`로 표기.

```bash
DEV=R5KYA01JSXA   # 실제 시리얼로 교체
adb -s $DEV shell wm size    # Physical size가 1080x2340이 아니면 top/bottom 값 재계산 필요
```

## 1. 화면 꺼짐 방지 + 앱을 깨끗한 상태로 재실행

```bash
adb -s $DEV shell svc power stayon true
adb -s $DEV shell input keyevent KEYCODE_WAKEUP
adb -s $DEV shell am force-stop com.backdev.mahjonghanpan
adb -s $DEV shell monkey -p com.backdev.mahjonghanpan -c android.intent.category.LAUNCHER 1
sleep 3
```

작업이 다 끝나면 반드시 `adb -s $DEV shell svc power stayon false`로 되돌린다.

## 2. 화면 안의 요소를 정확히 탭하기 — 스크린샷 눈대중 금지

**실패 사례**: 스크린샷을 보고 텍스트가 보이는 y좌표를 눈대중으로 찍어 탭하면
글자 두께(한글/한자는 두껍고 영문은 얇음)에 따라 어두운 픽셀 분포가 달라서
좌표 추정이 매번 틀린다. 리스트의 마지막 항목(English)을 노렸는데 그 위 항목(中文)이
계속 선택되는 식으로, 최대 140px까지 어긋났었다. **반드시 uiautomator dump로 실제
tappable 영역의 bounds를 가져와 그 중심을 탭한다:**

```bash
adb -s $DEV shell uiautomator dump /sdcard/ui.xml
adb -s $DEV pull /sdcard/ui.xml /tmp/ui.xml
grep -o 'content-desc="[^"]*"[^>]*bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' /tmp/ui.xml
```

`content-desc`에 Flutter의 Semantics 라벨(버튼/텍스트 문구)이 그대로 노출되므로,
원하는 라벨을 찾아 `bounds="[x1,y1][x2,y2]"`의 중심 `((x1+x2)/2, (y1+y2)/2)`를 탭한다.

```bash
adb -s $DEV shell input tap <cx> <cy>
```

예외: 홈 화면 우측 상단 ⚙️ 아이콘, 뒤로가기 버튼처럼 고정 위치인 요소는 기존에
확인된 좌표(`(990,185)` 등)를 재사용해도 무방하다. 리스트 항목처럼 위치가 헷갈리는
곳만 uiautomator dump를 쓴다.

## 3. 전화/알림 상태바는 신경 쓰지 않아도 된다

크롭이 상단 100px을 통째로 잘라내므로, 통화 중 표시나 알림 아이콘이 상태바에 떠 있어도
최종 이미지에는 나오지 않는다. 통화가 끝날 때까지 기다릴 필요 없음.

## 4. 캡처 + 크롭

```bash
SC=<스크래치패드 디렉토리>   # 임시 원본 저장용
adb -s $DEV exec-out screencap -p > $SC/raw.png
python3 .claude/skills/store-screenshot/crop.py $SC/raw.png store/<lang>/screenshots/<번호>_<이름>_<lang>.png
```

기기 물리 해상도가 1080×2340이 아니면 `crop.py raw.png dst.png <top> <bottom>`처럼
top/bottom을 직접 넘긴다.

## 5. 저장 후 반드시 눈으로 검증

`Read` 도구로 저장된 PNG를 열어 다음을 확인한다:
- 상태바/내비게이션 바가 완전히 잘렸는지 (시계, 배터리, 하단 제스처 바 등 안 보여야 함)
- 의도한 화면·언어·상태(초보자 모드 on/off 등)가 맞는지
- 텍스트 오버플로우나 깨진 렌더링이 없는지

## 6. 촬영 대상별 진입 방법 (참고)

- **01_home**: 앱 재실행 직후 홈 화면. 스토어 스크린샷 관례상 초보자 모드는 OFF로
  찍는다 (기존 파일 기준). 언어 전환은 ⚙️ 설정 화면(우측 상단 톱니) → 언어 목록에서
  uiautomator dump로 정확한 좌표를 찾아 탭.
- **02_gameplay**: "AI와 하기"로 게임 시작 후 몇 턴 진행해 클레임 프롬프트("이 패,
  가져갈까요?" 등)가 뜬 장면을 잡는다. AI 턴은 자동 진행되므로 사람 차례마다 아무
  패나 버리며 몇 번 캡처를 시도하면 된다.
- **03_howto**: 홈 → "게임 설명서" 버튼.
- **zh 전용 04번**: 클레임 응답 제한시간 카운트다운이 보이는 장면 (기존 파일 참고).

## 7. 마무리

- 언어를 원래 상태(한국어)로, 초보자 모드를 기존 스토어 스크린샷 관례(OFF)로 되돌린다.
- `adb -s $DEV shell svc power stayon false`
- `git status`로 어떤 스크린샷 파일이 바뀌었는지 확인 후, 커밋은 사용자가 요청할 때만
  (전역 커밋 프로토콜을 따를 것 — `git add`는 변경된 파일만 명시적으로).
