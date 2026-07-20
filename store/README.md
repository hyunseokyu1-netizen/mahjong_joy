# Play Store 등록 자료

## 폴더 구조

```
store/
  ko/  en/  zh/  ja/
    title.txt              앱 이름 (≤30자)
    short_description.txt  짧은 설명 (≤80자)
    full_description.txt   전체 설명 (≤4000자)
    release_notes.txt      버전별 변경 이력 (개인 백업용, 전체 버전 누적)
    screenshots/            휴대전화 스크린샷 (RGB PNG)
```

## release_notes.txt는 백업용이지 업로드용이 아니다

`release_notes.txt`는 **Play Console에 그대로 붙여넣는 파일이 아니다.** 모든 버전의 변경 이력을 계속 누적해서 개인적으로 기록해두는 용도다. 그래서 500자 제한을 넘어도 상관없다.

실제로 Play Console의 "이 버전의 새로운 기능"란에 올릴 때는, 이 파일에서 **가장 최신 버전 항목 하나만** 잘라서 붙여넣고 500자 제한(로케일별로 표시)을 그때 확인할 것.

## Play Console 업로드 시 참고

- title/short_description/full_description은 각 언어 폴더의 텍스트를 해당 로케일(한국어 / English (US) / 中文（简体） / 日本語)에 그대로 붙여넣으면 된다.
- 스크린샷은 세로 1080×2115 (1080×2340 폰 캡처에서 상단 상태바 100px, 하단 내비게이션바 125px을 잘라낸 것). Play Console 요건(최소 320px, 최대 3840px, 2장 이상)을 충족한다.
- ko/en/ja는 3장(홈·게임플레이·설명서), zh는 4장(홈·게임플레이·클레임 타이머·설명서)이다. 필요하면 서로 섞어서 4장씩 맞춰도 된다.
- 앱 아이콘은 `assets/icon/icon.png` (1024×1024), 이미 `flutter_launcher_icons`로 앱에 적용되어 있다.
- 그래픽 자산이 하나 더 필요할 수 있다: **피처 그래픽(1024×500)**. 아직 만들지 않았다 — 필요하면 요청.

## 릴리즈 서명

- 릴리즈 키스토어: `android/app/upload-keystore.jks`
- 설정 파일: `android/key.properties` (비밀번호 포함, **git에 커밋되지 않음** — `android/.gitignore`에 등록됨)
- **이 두 파일은 앱을 업데이트할 때마다 계속 필요하다. 반드시 별도로 백업해둘 것** (분실 시 같은 서명으로 업데이트 불가).

## 빌드된 AAB

`/Users/hs/Documents/workspace/apk_build_files/mahjongHanpan/`

- `mahjong-hanpan-1.0.0+1.aab` — 첫 출시 (마작한판으로 리브랜딩 후 첫 빌드)
- `mahjong-hanpan-1.1.0+4.aab` — 내 차례 타이머 표시
- `mahjong-hanpan-1.2.0+5.aab` — 일본어 지원 + 설정 화면 분리

옛 `mahjongJoy/` 폴더의 1.0.0~1.0.2 AAB는 리브랜딩 전 패키지(`com.backdev.mahjongjoy`)로 만든 로컬 테스트 빌드로, 스토어에 업로드된 적 없음. 참고용으로만 남겨둠.

applicationId: `com.backdev.mahjonghanpan`
