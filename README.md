# VideoGenerator — Autodesk 설치 자동화 홍보 영상

앱을 실제로 조작하며 자동 녹화하는 홍보 영상 생성기. 편집 프로그램 없이 `src/demo.ps1` 하나가
인트로 → 시연(툴팁·스포트라이트·안내 캐릭터·자막) → 진행 연출 → 엔딩까지 만들고 OBS 로 찍는다.

| 폴더 | 내용 |
|---|---|
| `src/` | `demo.ps1`(본체) · `obs.ps1`(obs-websocket v5) · `make-bgm.ps1` · `make-sfx.ps1` · `demo.cmd`(승격 실행) |
| `assets/` | 캐릭터 그림 · 로고(SVG/PNG) · 효과음. 배경음악 `bgm.wav` 는 52 MB 라 `make-bgm.ps1` 로 만든다 |
| `previews/` | 오프스크린 렌더와 실행 중 캡처 — 인트로 · 엔딩 · 진행 연출 · 화면 |
| `output/` | 완성 영상(본판 녹화 뒤) |
| [SKILL.md](SKILL.md) | 다시 찍거나 고칠 때 읽는 방법 · 당했던 것 목록 |
| [devlog.md](devlog.md) | 무엇을 왜 바꿨는지, 회차별 결과 |

앱 소스는 별도 저장소(`Autodesk Install Automation`)에 있다.
