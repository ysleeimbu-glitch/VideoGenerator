---
name: autodesk-demo-video
description: "Autodesk 설치 자동화" 홍보 영상을 앱을 실제로 조작하며 자동 녹화한다. 인트로·툴팁·스포트라이트·안내 캐릭터·자막·진행 연출·엔딩까지 한 스크립트가 만든다. 영상을 다시 찍거나 장면을 고칠 때 읽는다.
---

# Autodesk 설치 자동화 — 홍보 영상 자동 생성

`src/demo.ps1` 하나가 **앱을 UIA 로 실제 조작하면서** 화면 위에 연출 창을 띄우고, OBS 로 녹화한다.
편집 프로그램은 쓰지 않는다 — 모든 장면이 코드고, 다시 돌리면 같은 영상이 나온다.

## 준비물

| 것 | 어디에 | 비고 |
|---|---|---|
| 앱 | `Autodesk 설치 자동화` 가 설치돼 있어야 한다 | `requireAdministrator` 라 **스크립트도 승격**해야 조작된다(UIPI) |
| OBS Studio 32 + obs-websocket | 기본 설치 | `%APPDATA%\obs-studio\plugin_config\obs-websocket\config.json` 의 `server_enabled` 를 스크립트가 켠다 |
| 캐릭터 그림 | `assets/characters/`(원본 JPG) → 실행 PC 의 `C:\Users\<user>\Downloads\캐릭터\`, **`assets/work/`(AI 업스케일 640px PNG) → 그 아래 `hd\`** | `hd\` 가 있으면 우선 읽는다. 8K 원본은 `assets/hires/`(보관용, 영상엔 안 쓴다 — 프레임이 떨어진다) |
| 로고 | `assets/logos/` — `logo_ssjh.png`, `autodesk gold partner logo.png` | `logo_ssjh.png` 는 SVG 를 Edge 헤드리스로 뽑은 것(아래) |
| 소리 | `assets/audio/twinkle.wav` · `bgm.wav`(생성) | `bgm.wav` 는 52 MB 라 git 에 안 넣는다 — `make-bgm.ps1` 로 만든다 |

스크립트 옆(`$PSScriptRoot`)에 `logo_ssjh.png`, `twinkle.wav`, `bgm.wav`, `obs.ps1` 이 있어야 한다.
이 PC 에서는 `C:\Users\info\Desktop\demo\` 가 그 자리다.

```powershell
# 소리 만들기(결정적 — 같은 파일이 나온다)
powershell -File src\make-bgm.ps1      # 108 BPM · C–G–Am–F · −16 dBFS · 5분
powershell -File src\make-sfx.ps1      # 별빛 소리 0.9초 (C6–E7 아르페지오)
# 로고 SVG → 투명 PNG
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --screenshot=logo_ssjh.png --window-size=1400,413 --default-background-color=00000000 "file:///...상상진화 로고.svg"
```

## 실행

```
demo.cmd                      본판: 승격 → OBS 녹화 → C:\Users\<user>\Videos\*.mp4
demo.ps1 -NoObs               녹화 없이 전체 시연(승격 필요)
demo.ps1 -NoObs -SnapAll      + 진행 연출 구간 화면을 snap_sim07/22/end.png 로 남김
demo.ps1 -Test                비승격 시험: RUN 을 생략하고 snap_*.png 만 남김
```

**승격 창은 사람이 UAC 를 눌러야 뜬다.** 원격(Chrome Remote Desktop)에서는 승격 콘솔에 키 입력이 안 들어가므로,
스크립트는 처음부터 끝까지 손대지 않아도 되게 만들어져 있다. 돌리기 전에 **화면 주인에게 동의를 받는다** —
약 3분 30초 동안 마우스·키보드를 건드리면 장면이 깨진다.

끝나면 `demo-transcript.txt` 에 전체 로그가 남는다. `!!` 로 시작하는 줄이 실패다.
연출 뒤 실제 배치는 `■ 중단` 을 눌러 끊는다 — 로그 `[HH:MM:SS] 사용자 취소` 로 확인한다.
**끊기지 않았으면 실제 설치가 진행된다.** 반드시 확인한다.

## 장면 구성 (약 3분 25초)

| # | 장면 | 방법 |
|---|---|---|
| 0 | 인트로 14초 | `Intro` — 도시 장면 + 마스코트 넷(뛰고 눌리고 갸웃) + 제목 글자 하나씩 + 로고 튕김 + 태그라인. 별빛 소리 6회 |
| 1 | AutoCAD 2024 한국어 담기 | 제품군 → 버전 → 언어 → 설치 항목 → 배치에 추가. 클릭마다 스포트라이트 + 번호 툴팁 ①… + 자막 |
| 2 | Revit 2025 · Revit LT 2021 · Civil 3D 2026 빠른 담기 | `Pick-Quick` — 툴팁 없이 이동·클릭·링만 |
| 3 | 순서 바꾸기 | 4번째 선택 → ▲ → ▼ → ✕ 한 번씩 |
| 4 | 라이선스 | 네트워크 → Autodesk ID 로그인 |
| 5 | 사양 점검 | 창 열고 휠 스크롤 20틱, 항목별 자막, 주의·실패만 보기 켜고 끄기, 이대로 진행 |
| 6 | RUN → 예 | 실제로 누른다. 실제 다운로드가 뒤에서 시작된다 |
| 7 | 진행 연출 ~30초 | `Sim` — RUN 직전 화면을 떠 두고 **퍼센트·칩·세부 문구·막대·전체 막대·타일만** 제자리에 다시 그린다. 제품명은 캡처 그대로 |
| 8 | 엔딩 5.5초 | `Outro` — 로고 두께(어두운 판 겹침) · 옆으로 돌며 등장 · 빛줄기 · 반사 · 별빛 입자 · 검정 페이드 |

자막은 마케팅 문체로, 클릭마다 바뀐다. 진행 연출 자막은 "사람이 클릭할 필요가 없습니다" 를 되풀이한다 — 그것이 제품의 요점이다.

## 연출 창의 구조 (알아야 고칠 수 있는 것)

모두 WinForms `Overlay`(TopMost · NoActivate · Transparent · ToolWindow)다.

- **Backdrop** — 남색 배경. **TopMost 가 아니고** 앱 바로 아래에 둔다(`SetWindowPos(hwndInsertAfter=앱)`). 앱 위로 올라올 수 없다.
- **Spot** — 어둡게 + 둥근 구멍(TransparencyKey). 구멍은 클릭 대상 + 안내 말풍선.
- **Tip** — 번호 툴팁. **Guide** — 왼쪽 안내 캐릭터(다운로드7), 말할 때 입이 움직이고 말풍선은 툴팁과 같은 문구.
- **CursorFx** — 130px 붉은 화살표 + 형광 후광, 레이어드 창. OBS 는 `capture_cursor=false` 라 영상엔 이것만 보인다.
- **Caption** — 하단 104px 자막 바. 양끝에 로고.
- **Sim** — 진행 연출. 줄 자리(퍼센트·기호·상태·막대)와 상태 영역(문구·퍼센트·굵은 막대·타일)을 UIA 로 재서 받는다.
  색·기호·문구·가중치(다운로드 40 · 압축 해제 10 · 설치 50)는 앱 소스 `StatePalette` 와 같다.

**z-order 규칙**: 이미 TopMost 인 창을 다시 `HWND_TOPMOST` 로 올리면 자리가 안 바뀐다 — `HWND_TOP` 을 쓴다(`N.Top`).
앱은 실행 중에 스스로 앞으로 나온다. 그래서 `Sim.Set` 은 **매 틱** `Raise()` 한다.

## 실제로 당한 것 (다시 당하지 않기 위해)

| 증상 | 원인 | 처치 |
|---|---|---|
| 녹화가 새까맣다 | `monitor_capture` 의 `monitor_id` 가 `DUMMY` | `GetInputPropertiesListPropertyItems` 로 실제 모니터 id 를 받아 넣는다 |
| 앱이 배경에 가려 안 보인다 | Backdrop 도 TopMost 였다 | Backdrop 은 non-TopMost, 앱 아래에 삽입 |
| 모달 창을 못 찾는다 | WPF 모달·MessageBox 는 UIA 트리에서 **메인 창의 자식** | 루트 → 메인 창 자식 순으로 찾는다(`Find-Window`) |
| 큐 5번째 항목을 못 찾는다 | ListBox 가상화 | `ItemContainerPattern.FindItemByProperty` + `VirtualizedItemPattern.Realize` |
| 버전 바꾼 직후 언어를 못 찾는다 | 언어 목록이 통째로 다시 채워진다 | 2.5초까지 다시 찾는다 |
| 진행 연출에서 제품명이 '1 2 3' | 줄의 첫 Text(순번)를 제목으로 읽었다 | 순번 다음 Text 가 제목. 어차피 제목은 캡처 그림 그대로 둔다 |
| 진행 연출 1번 줄이 안 보인다 | ✕ 뒤에 목록이 한 줄 내려가 있었다 | 재기 전에 `ScrollPattern.SetScrollPercent(0)` |
| 30초쯤부터 연출이 사라진다 | 앱이 스스로 앞으로 나왔다 | 매 틱 `Raise()` |
| ■ 중단이 안 먹는다 → 실제 설치 계속 | 엔딩 창(불투명)이 클릭을 삼켰다 | 녹화 종료 뒤 엔딩 창을 먼저 닫는다 |
| JPG 캐릭터 둘레에 검은 네모 | JPG 의 "검정" 은 압축 잡음 | `KeyBlack` — 거의 검은 픽셀을 투명하게, 가장자리는 부드럽게 |
| 말풍선 글자가 잘린다 | 폭 계산이 한 줄 기준 | `TextRenderer` WordBreak + 제안 크기 |
| 스크립트가 통째로 안 돈다 | UTF-8 BOM 이 없다 / `0xFFFFFFFF` 가 −1 로 읽힌다 / `-File` 배열 인수가 한 문자열이 된다 | BOM 유지 · `[uint32]4294967176` · 스칼라 인수 |
| 파일이 깨졌다 | PS 5.1 음수 인덱스 슬라이스(`$a[0..($i-1)]`, i=−1) · `perl -CSD` 가 한국어를 망가뜨림 | `.Contains()` 로 찾고 줄 번호로 고친다 |

## 고칠 때 순서

1. 장면 하나를 바꾸면 **오프스크린으로 먼저 본다** — `Intro/Outro.RenderFrame(t, dur, path)`, `Sim` 은 옛 캡처 위에 그려 본다(`Sim(area, rows, status, Bitmap)`).
2. `-NoObs -SnapAll` 로 한 번 돌려 `snap_sim*.png` 와 `demo-transcript.txt` 를 본다. `!!` 0건이어야 한다.
3. 그다음 `demo.cmd` 로 본판을 찍는다. 찍은 뒤 `tools/serve.ps1` 로 Videos 폴더를 http 로 내놓고 브라우저 `<video>` 의 `currentTime` 을 옮겨 인트로(8초)·연출(150초)·엔딩(178초)을 본다. WPF `MediaPlayer` 추출은 탐색이 안 먹는다 — 쓰지 않는다.
4. `devlog.md` 에 무엇을 왜 바꿨는지 적는다. 근거(로그 시각·캡처 파일)를 함께.

## 업스케일 (8K 자료)

모든 그림 자료는 **8K 급 원본**을 `assets/hires/` 에 두고, 영상은 거기서 줄인 **작업본**(`assets/work/`)을 쓴다.
원본이 작은 그림(마스코트 320px JPG)은 단순 확대가 아니라 **Real-ESRGAN(ncnn-vulkan, GPU)** 으로 올린다 — 잡음이 빠지고 선이 산다.

```powershell
powershell -File tools\get-realesrgan.ps1                       # 처음 한 번: 43 MB 휴대판을 tools\realesrgan\ 에 푼다 (git 제외)
powershell -File tools\upscale-8k.ps1                           # 캐릭터 폴더 전체 → assets\hires\*_8k.png + assets\work\*.png
powershell -File tools\upscale-8k.ps1 -Src D:\new -Kind photo   # 사진·로고 글자는 photo (일반 모델)
powershell -File tools\upscale-8k.ps1 -Include 'mascot9.*' -Force   # 한 장만 다시
```

| 인수 | 뜻 | 기본 |
|---|---|---|
| `-Src` · `-Include` | 원본 폴더 · 이름 패턴 | `Downloads\캐릭터` · `*.jpg,*.jpeg,*.png` |
| `-Kind anime/photo` | 첫 통과 모델. 일러스트·마스코트는 `anime`(`x4plus-anime`), 사진·글자 로고는 `photo`(`x4plus`) | `anime` |
| `-Target` | 긴 변이 이 값 이상이 될 때까지 통과 | 7680 |
| `-WorkWidth` | 작업본 폭. 영상에서 그리는 크기의 **두 배쯤** | 640 (마스코트) · 배지는 1108 |
| `-Out` · `-Work` · `-Force` | 8K 자리 · 작업본 자리 · 있어도 다시 | `assets/hires` · `assets/work` |

**통과 계획**: 첫 통과는 언제나 ×4(잡음 정리가 가장 좋다). 그 뒤는 {2,3,4} 를 최대 세 번 곱해 필요한 배수를 넘기되 **가장 작게** 고른다 —
320 → 1280 뒤 6배가 필요하면 ×2·×3 = 7680 딱 맞춤(×4·×2 는 10240 으로 파일만 커진다). 554px 배지는 ×4·×4 = 8864.
실측(GTX 1660 SUPER): 마스코트 한 장 7~10초, 배지 46초(8864² 는 타일이 많다).

**SVG 는 업스케일하지 않는다** — 벡터라 Edge 헤드리스로 원하는 크기를 바로 뽑는다:
```powershell
& "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu --hide-scrollbars --screenshot=out.png --window-size=7680,2266 --default-background-color=00000000 "file:///.../logo.html"
```
(`logo.html` 은 `<img src="…svg" style="width:7680px;height:2266px">` 한 줄. `--screenshot` 에 SVG 를 직접 주면 크기가 안 맞는다.)

**영상에는 8K 를 그대로 쓰지 않는다.** 실측: 엔딩이 2000px 로고를 프레임마다 14번 줄여 그리면 266ms/프레임(≈4fps), 1400px 도 202ms 였다.
- 스크립트는 `캐릭터\hd\` 에 작업본이 있으면 우선 읽는다(`캐릭터 고해상도 판 5/5` 로그). 없으면 원본 JPG.
- `Intro.Prescale(img, w)` 로 **그리는 크기의 두 배**로 미리 줄인다: 장면 600 · 마스코트 460 · 안내 캐릭터 540 · 엔딩 로고 760.
- 엔딩 두께 판 12장은 생성 때 한 장으로 합친다. `DrawFit/DrawImg` 는 알파 1 이면 `ImageAttributes` 를 건너뛴다(픽셀마다 행렬 곱이라 느리다).
- 실측 후: 엔딩 32ms · 인트로 57ms · 안내 9ms(오프스크린 `DrawToBitmap` 기준, 화면은 더 빠르다).
- 그림 안 좌표(안내 캐릭터 입 위치 `MX,MY`)는 **320px 기준**이다 — 다른 크기 판을 쓰면 `bm.Width/320` 으로 비례해 잰다. 640 판에서 피부색 표본이 헬멧을 집은 적이 있다.

**새 그림을 넣을 때**: 원본을 `assets/characters/`(또는 `logos/`)에 두고 → `upscale-8k.ps1` → `assets/work/*.png` 를 실행 PC 의 `캐릭터\hd\` 로 복사 → 오프스크린 렌더로 확인(`RenderFrame`) → 프레임 비용을 잰다(위 실측과 비교) → `-NoObs -SnapAll` 한 번.
