# peon-ping
<div align="center">

[English](README.md) | **한국어** | [中文](README_zh.md)

![macOS](https://img.shields.io/badge/macOS-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue) ![Linux](https://img.shields.io/badge/Linux-blue) ![Windows](https://img.shields.io/badge/Windows-blue) ![SSH](https://img.shields.io/badge/SSH-blue)
![License](https://img.shields.io/badge/license-MIT-green)

![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01) ![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-adapter-ffab01) ![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-adapter-ffab01) ![Codex](https://img.shields.io/badge/Codex-adapter-ffab01) ![Cursor](https://img.shields.io/badge/Cursor-adapter-ffab01) ![OpenCode](https://img.shields.io/badge/OpenCode-adapter-ffab01) ![Kilo CLI](https://img.shields.io/badge/Kilo_CLI-adapter-ffab01) ![Kiro](https://img.shields.io/badge/Kiro-adapter-ffab01) ![Windsurf](https://img.shields.io/badge/Windsurf-adapter-ffab01) ![Antigravity](https://img.shields.io/badge/Antigravity-adapter-ffab01) ![OpenClaw](https://img.shields.io/badge/OpenClaw-adapter-ffab01)

**AI 코딩 에이전트가 관심을 요청할 때 게임 캐릭터 음성 + 시각 오버레이 알림을 재생하거나, MCP를 통해 에이전트가 직접 효과음을 선택할 수 있습니다.**

AI 코딩 에이전트는 작업이 끝나거나 권한이 필요할 때 알려주지 않습니다. 다른 탭으로 전환했다가 집중을 잃고, 다시 몰입하는 데 15분을 허비하게 됩니다. peon-ping은 워크래프트, 스타크래프트, 포탈, 젤다 등의 게임 캐릭터 음성과 눈에 잘 띄는 화면 배너로 이 문제를 해결합니다. **Claude Code**, **GitHub Copilot**, **Codex**, **Cursor**, **OpenCode**, **Kilo CLI**, **Kiro**, **Windsurf**, **Google Antigravity** 및 모든 MCP 클라이언트를 지원합니다.

**데모 보기** &rarr; [peonping.com](https://peonping.com/)

<video src="docs/public/demo-avatar.mp4" autoplay loop muted playsinline width="400"></video>

</div>

---

- [설치](#설치)
- [어떤 소리가 나나요?](#어떤-소리가-나나요)
- [빠른 제어](#빠른-제어)
- [설정](#설정)
- [Peon 트레이너](#peon-트레이너)
- [MCP 서버](#mcp-서버)
- [멀티 IDE 지원](#멀티-ide-지원)
- [원격 개발](#원격-개발-ssh--devcontainers--codespaces)
- [모바일 알림](#모바일-알림)
- [사운드 팩](#사운드-팩)
- [제거](#제거)
- [시스템 요구사항](#시스템-요구사항)
- [동작 원리](#동작-원리)
- [링크](#링크)

---

## 설치

### 방법 1: Homebrew (추천)

```bash
brew install PeonPing/tap/peon-ping
```

설치 후 `peon-ping-setup`을 실행하면 훅이 등록되고 사운드 팩이 다운로드됩니다. macOS, Linux 지원.

### 방법 2: 설치 스크립트 (macOS, Linux, WSL2)

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash
```

### 방법 3: Windows 설치

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.ps1" -UseBasicParsing | Invoke-Expression
```

기본적으로 5개의 엄선된 사운드 팩(워크래프트, 스타크래프트, 포탈)이 설치됩니다. 재실행하면 설정과 상태를 유지하면서 업데이트됩니다. **[peonping.com에서 원하는 팩을 직접 골라](https://peonping.com/#picker)** 맞춤 설치 명령어를 받을 수도 있습니다.

유용한 설치 옵션:

- `--all` — 모든 사운드 팩 설치
- `--packs=peon,sc_kerrigan,...` — 특정 팩만 설치
- `--local` — 현재 프로젝트의 `./.claude/` 디렉토리에 팩과 설정을 설치 (훅은 항상 `~/.claude/settings.json`에 전역 등록)
- `--global` — 명시적 전역 설치 (기본값과 동일)
- `--init-local-config` — `./.claude/hooks/peon-ping/config.json`만 생성

`--local`은 쉘 rc 파일을 수정하지 않습니다 (전역 `peon` 별칭/자동완성을 주입하지 않음). 훅은 항상 전역 `~/.claude/settings.json`에 절대 경로로 기록되므로 어떤 프로젝트 디렉토리에서든 동작합니다.

예시:

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --all
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --packs=peon,sc_kerrigan
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --local
```

전역 설치가 이미 있는 상태에서 로컬 설치를 하거나 그 반대의 경우, 설치 프로그램이 충돌 방지를 위해 기존 설치를 제거할지 물어봅니다.

### 방법 4: 클론 후 직접 확인

```bash
git clone https://github.com/PeonPing/peon-ping.git
cd peon-ping
./install.sh
```

## 어떤 소리가 나나요?

| 이벤트 | CESP 카테고리 | 예시 |
|---|---|---|
| 세션 시작 | `session.start` | *"Ready to work?"*, *"Yes?"*, *"What you want?"* |
| 작업 완료 | `task.complete` | *"Work, work."*, *"I can do that."*, *"Okie dokie."* |
| 권한 필요 | `input.required` | *"Something need doing?"*, *"Hmm?"*, *"What you want?"* |
| 도구/명령 에러 | `task.error` | *"I can't do that."*, *"Son of a bitch!"* |
| 작업 수락 | `task.acknowledge` | *"I read you."*, *"On it."* *(기본 비활성화)* |
| 속도/토큰 제한 | `resource.limit` | *"Zug zug."* *(팩에 따라 다름)* |
| 빠른 연타 (10초 내 3회 이상) | `user.spam` | *"Me busy, leave me alone!"* |

추가로 모든 화면에 **대형 오버레이 배너** (macOS/WSL)와 터미널 탭 제목 (`● project: done`)이 표시됩니다 — 다른 앱을 사용 중이더라도 바로 알 수 있습니다.

peon-ping은 [코딩 이벤트 사운드 팩 표준 (CESP)](https://github.com/PeonPing/openpeon)을 구현합니다 — 모든 에이전트 기반 IDE가 채택할 수 있는 코딩 이벤트 사운드 오픈 표준입니다.

## 빠른 제어

회의나 페어 프로그래밍 중에 소리를 끄고 싶으신가요? 두 가지 방법이 있습니다:

| 방법 | 명령어 | 사용 시기 |
|---|---|---|
| **슬래시 커맨드** | `/peon-ping-toggle` | Claude Code에서 작업 중일 때 |
| **CLI** | `peon toggle` | 아무 터미널 탭에서 |

기타 CLI 명령어:

```bash
peon pause                # 소리 끄기
peon resume               # 소리 켜기
peon status               # 일시정지/활성 상태 확인
peon volume               # 현재 볼륨 확인
peon volume 0.7           # 볼륨 설정 (0.0–1.0)
peon rotation             # 현재 로테이션 모드 확인
peon rotation random      # 로테이션 모드 설정 (random|round-robin|session_override)
peon packs list           # 설치된 사운드 팩 목록
peon packs list --registry # 레지스트리의 모든 사운드 팩 검색
peon packs install <p1,p2> # 레지스트리에서 팩 설치
peon packs install --all  # 레지스트리의 모든 팩 설치
peon packs use <name>     # 특정 팩으로 전환
peon packs use --install <name>  # 팩 설치(필요시) 후 전환
peon packs next           # 다음 팩으로 순환
peon packs remove <p1,p2> # 특정 팩 제거
peon notifications on     # 데스크톱 알림 활성화
peon notifications off    # 데스크톱 알림 비활성화
peon notifications overlay   # 대형 오버레이 배너 사용 (기본값)
peon notifications standard  # 시스템 알림 사용
peon notifications test      # 테스트 알림 보내기
peon preview              # session.start의 모든 사운드 재생
peon preview <category>   # 특정 카테고리의 모든 사운드 재생
peon preview --list       # 활성 팩의 모든 카테고리 나열
peon mobile ntfy <topic>  # 모바일 알림 설정 (무료)
peon mobile off           # 모바일 알림 비활성화
peon mobile test          # 테스트 알림 보내기
peon relay --daemon       # 오디오 릴레이 시작 (SSH/devcontainer용)
peon relay --stop         # 백그라운드 릴레이 중지
```

`peon preview`에서 사용 가능한 CESP 카테고리: `session.start`, `task.acknowledge`, `task.complete`, `task.error`, `input.required`, `resource.limit`, `user.spam`. (확장 카테고리 `session.end`와 `task.progress`는 CESP 표준에 정의되어 있고 팩 매니페스트에서 지원하지만, 현재 내장 훅 이벤트에서는 트리거되지 않습니다.)

탭 자동완성을 지원합니다 — `peon packs use <TAB>`을 입력하면 사용 가능한 팩 이름이 표시됩니다.

일시정지하면 소리와 데스크톱 알림이 즉시 꺼집니다. 일시정지 상태는 세션 간에 유지되며, 다시 활성화할 때까지 지속됩니다. 일시정지 중에도 탭 제목은 계속 업데이트됩니다.

## 설정

peon-ping은 Claude Code에 두 가지 슬래시 커맨드를 설치합니다:

- `/peon-ping-toggle` — 소리 켜기/끄기
- `/peon-ping-config` — 설정 변경 (볼륨, 팩, 카테고리 등)

Claude에게 직접 설정을 변경해달라고 요청할 수도 있습니다 — 예를 들어 "라운드 로빈 팩 로테이션 활성화해줘", "볼륨을 0.3으로 설정해줘", "glados를 팩 로테이션에 추가해줘" 같은 식으로요. 설정 파일을 직접 편집할 필요가 없습니다.

설정 파일 위치는 설치 모드에 따라 다릅니다:

- 전역 설치: `$CLAUDE_CONFIG_DIR/hooks/peon-ping/config.json` (기본값 `~/.claude/hooks/peon-ping/config.json`)
- 로컬 설치: `./.claude/hooks/peon-ping/config.json`

```json
{
  "volume": 0.5,
  "categories": {
    "session.start": true,
    "task.acknowledge": true,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  }
}
```

- **volume**: 0.0–1.0 (사무실에서도 적당한 볼륨)
- **desktop_notifications**: `true`/`false` — 소리와 독립적으로 데스크톱 알림 팝업 토글 (기본값: `true`)
- **notification_style**: `"overlay"` 또는 `"standard"` — 데스크톱 알림 표시 방식 (기본값: `"overlay"`)
  - **overlay**: 크고 잘 보이는 배너 — macOS에서는 JXA Cocoa 오버레이, WSL에서는 Windows Forms 팝업. 오버레이를 클릭하면 터미널로 포커스 이동 (Ghostty, Warp, iTerm2, Zed, Terminal.app 지원)
  - **standard**: 시스템 알림 — macOS에서는 [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) / `osascript`, WSL에서는 Windows toast. `terminal-notifier`를 설치하면 (`brew install terminal-notifier`) 알림 클릭 시 자동으로 터미널로 포커스 이동 (Ghostty, Warp, iTerm2, Zed, Terminal.app 지원)
- **categories**: 개별 CESP 사운드 카테고리를 켜거나 끌 수 있음 (예: `"session.start": false`로 인사 소리 비활성화)
- **annoyed_threshold / annoyed_window_seconds**: N초 내 몇 번의 프롬프트가 `user.spam` 이스터에그를 트리거하는지
- **silent_window_seconds**: N초 미만으로 완료된 작업의 `task.complete` 소리와 알림을 억제 (예: `10`으로 설정하면 10초 이상 걸린 작업에서만 소리가 남)
- **suppress_subagent_complete** (boolean, 기본값: `false`): 서브 에이전트 세션이 끝날 때 `task.complete` 소리와 알림을 억제. Claude Code의 Task 도구가 서브 에이전트를 병렬로 실행하면 각각 완료 시 알림이 울리는데, `true`로 설정하면 부모 세션의 완료 알림만 울립니다.
- **default_pack**: 더 구체적인 규칙이 없을 때 사용할 기본 팩 (기본값: `"peon"`). 이전의 `active_pack` 키를 대체하며, 기존 설정은 `peon update` 시 자동으로 마이그레이션됩니다.
- **path_rules**: `{ "pattern": "...", "pack": "..." }` 객체 배열. 작업 디렉토리를 기준으로 글로브 매칭 (`*`, `?`)을 사용해 세션에 팩을 할당합니다. 첫 번째로 일치하는 규칙이 적용됩니다. `pack_rotation`과 `default_pack`보다 우선하지만, `session_override` 할당에는 밀립니다.
  ```json
  "path_rules": [
    { "pattern": "*/work/client-a/*", "pack": "glados" },
    { "pattern": "*/personal/*",      "pack": "peon" }
  ]
  ```
- **pack_rotation**: 팩 이름 배열 (예: `["peon", "sc_kerrigan", "peasant"]`). `pack_rotation_mode`가 `random` 또는 `round-robin`일 때 사용. 빈 배열 `[]`로 두면 `default_pack` (또는 `path_rules`)만 사용합니다.
- **pack_rotation_mode**: `"random"` (기본값), `"round-robin"`, 또는 `"session_override"`. `random`/`round-robin`은 각 세션마다 `pack_rotation`에서 하나의 팩을 선택합니다. `session_override`는 `/peon-ping-use <pack>` 명령으로 세션별로 팩을 지정합니다. 유효하지 않거나 누락된 팩은 계층 구조에 따라 폴백됩니다. (`"agentskill"`은 `"session_override"`의 레거시 별칭으로 계속 사용 가능합니다.)
- **session_ttl_days** (number, 기본값: 7): N일이 지난 오래된 세션별 팩 할당을 만료시킵니다. `session_override` 모드 사용 시 `.state.json`이 무한히 커지는 것을 방지합니다.

## Peon 트레이너

당신의 피언은 개인 트레이너이기도 합니다. 파벨(Pavel) 스타일의 일일 운동 모드가 내장되어 있습니다 — "work work" 하던 오크가 이제 엎드려 팔굽혀펴기 20개를 시킵니다.

### 빠른 시작

```bash
peon trainer on              # 트레이너 활성화
peon trainer goal 200        # 일일 목표 설정 (기본값: 300/300)
# ... 코딩하는 동안 약 20분마다 피언이 잔소리합니다 ...
peon trainer log 25 pushups  # 운동 기록
peon trainer log 30 squats
peon trainer status          # 진행 상황 확인
```

### 동작 방식

트레이너 알림은 코딩 세션에 연동됩니다. 새 세션을 시작하면 피언이 바로 코드를 작성하기 전에 팔굽혀펴기를 하라고 독려합니다. 이후 활발한 코딩 중 약 20분마다 더 하라고 소리칩니다. 백그라운드 데몬이 필요 없습니다. `peon trainer log`로 횟수를 기록하면 자정에 자동으로 초기화됩니다.

### 명령어

| 명령어 | 설명 |
|---------|-------------|
| `peon trainer on` | 트레이너 모드 활성화 |
| `peon trainer off` | 트레이너 모드 비활성화 |
| `peon trainer status` | 오늘의 진행 상황 표시 |
| `peon trainer log <n> <exercise>` | 횟수 기록 (예: `log 25 pushups`) |
| `peon trainer goal <n>` | 모든 운동의 목표 설정 |
| `peon trainer goal <exercise> <n>` | 특정 운동의 목표 설정 |

### Claude Code 스킬

Claude Code에서 대화를 나가지 않고도 횟수를 기록할 수 있습니다:

```
/peon-ping-log 25 pushups
/peon-ping-log 30 squats
```

### 커스텀 음성

`~/.claude/hooks/peon-ping/trainer/sounds/`에 직접 만든 오디오 파일을 넣으세요:

```
trainer/sounds/session_start/  # 세션 인사 ("Pushups first, code second! Zug zug!")
trainer/sounds/remind/         # 리마인더 ("Something need doing? YES. PUSHUPS.")
trainer/sounds/log/            # 기록 확인 ("Work work! Muscles getting bigger maybe!")
trainer/sounds/complete/       # 목표 달성 ("Zug zug! Human finish all reps!")
trainer/sounds/slacking/       # 실망 ("Peon very disappointed.")
```

`trainer/manifest.json`을 업데이트하여 사운드 파일을 등록하세요.

## MCP 서버

peon-ping에는 [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) 서버가 포함되어 있어, MCP를 지원하는 모든 AI 에이전트가 훅 없이도 도구 호출로 직접 사운드를 재생할 수 있습니다.

핵심 차이점: **에이전트가 사운드를 선택합니다.** 이벤트마다 고정된 사운드를 자동 재생하는 대신, 에이전트가 원하는 사운드를 직접 `play_sound`로 호출합니다 — 빌드 실패 시 `duke_nukem/SonOfABitch`, 파일 읽기 시 `sc_kerrigan/IReadYou` 같은 식으로요.

### 설정 방법

MCP 클라이언트 설정에 추가하세요 (Claude Desktop, Cursor 등):

```json
{
  "mcpServers": {
    "peon-ping": {
      "command": "node",
      "args": ["/path/to/peon-ping/mcp/peon-mcp.js"]
    }
  }
}
```

Homebrew로 설치한 경우: `$(brew --prefix peon-ping)/libexec/mcp/peon-mcp.js`. 전체 설정 방법은 [`mcp/README.md`](mcp/README.md)를 참고하세요.

### 에이전트가 할 수 있는 것

| 기능 | 설명 |
|---|---|
| **`play_sound`** | 키 이름으로 하나 이상의 사운드 재생 (예: `duke_nukem/SonOfABitch`, `peon/PeonReady1`) |
| **`peon-ping://catalog`** | MCP 리소스로 전체 팩 카탈로그 제공 — 클라이언트가 한 번 미리 가져오면 반복 호출 불필요 |
| **`peon-ping://pack/{name}`** | 개별 팩의 상세 정보와 사용 가능한 사운드 키 |

Node.js 18+ 필요. [@tag-assistant](https://github.com/tag-assistant) 기여.

## 멀티 IDE 지원

peon-ping은 훅을 지원하는 모든 에이전트 기반 IDE에서 동작합니다. 어댑터가 IDE별 이벤트를 [CESP 표준](https://github.com/PeonPing/openpeon)으로 변환합니다.

| IDE | 상태 | 설정 |
|---|---|---|
| **Claude Code** | 내장 | `curl \| bash` 설치 시 자동 처리 |
| **Gemini CLI** | 어댑터 | `~/.gemini/settings.json`에 `adapters/gemini.sh` 훅 추가 ([설정](#gemini-cli-설정)) |
| **GitHub Copilot** | 어댑터 | `.github/hooks/hooks.json`에 `adapters/copilot.sh` 훅 추가 ([설정](#github-copilot-설정)) |
| **OpenAI Codex** | 어댑터 | `~/.codex/config.toml`에 `notify = ["bash", "/절대경로/.claude/hooks/peon-ping/adapters/codex.sh"]` 추가 |
| **Cursor** | 내장 | `curl \| bash` 또는 `peon-ping-setup`이 자동 감지 후 Cursor 훅 등록 |
| **OpenCode** | 어댑터 | `curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh \| bash` ([설정](#opencode-설정)) |
| **Kilo CLI** | 어댑터 | `curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/kilo.sh \| bash` ([설정](#kilo-cli-설정)) |
| **Kiro** | 어댑터 | `~/.kiro/agents/peon-ping.json`에 `adapters/kiro.sh` 훅 추가 ([설정](#kiro-설정)) |
| **Windsurf** | 어댑터 | `~/.codeium/windsurf/hooks.json`에 `adapters/windsurf.sh` 훅 추가 ([설정](#windsurf-설정)) |
| **Google Antigravity** | 어댑터 | `bash ~/.claude/hooks/peon-ping/adapters/antigravity.sh` (`fswatch` 필요: `brew install fswatch`) |
| **OpenClaw** | 어댑터 | OpenClaw 스킬에서 `adapters/openclaw.sh <event>` 호출. 모든 CESP 카테고리와 Claude Code 이벤트명 지원. |

### GitHub Copilot 설정

[GitHub Copilot](https://github.com/features/copilot)용 셸 어댑터로, [CESP v1.0](https://github.com/PeonPing/openpeon) 표준을 완전히 준수합니다.

**설정 방법:**

1. peon-ping이 설치되어 있는지 확인 (`curl -fsSL https://peonping.com/install | bash`)

2. 레포지토리의 기본 브랜치에 `.github/hooks/hooks.json`을 생성:

   ```json
   {
     "version": 1,
     "hooks": {
       "sessionStart": [
         {
           "type": "command",
           "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh sessionStart"
         }
       ],
       "userPromptSubmitted": [
         {
           "type": "command",
           "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh userPromptSubmitted"
         }
       ],
       "postToolUse": [
         {
           "type": "command",
           "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh postToolUse"
         }
       ],
       "errorOccurred": [
         {
           "type": "command",
           "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh errorOccurred"
         }
       ]
     }
   }
   ```

3. 커밋 후 기본 브랜치에 병합합니다. 다음 Copilot 에이전트 세션부터 훅이 활성화됩니다.

**이벤트 매핑:**

- `sessionStart` → 인사 사운드 (*"Ready to work?"*, *"Yes?"*)
- `userPromptSubmitted` → 첫 프롬프트 = 인사, 이후 = 스팸 감지
- `postToolUse` → 완료 사운드 (*"Work, work."*, *"Job's done!"*)
- `errorOccurred` → 에러 사운드 (*"I can't do that."*)
- `preToolUse` → 건너뜀 (너무 시끄러움)
- `sessionEnd` → 사운드 없음 (session.end 미구현)

**기능:**

- **사운드 재생** — `afplay` (macOS), `pw-play`/`paplay`/`ffplay` (Linux) — 셸 훅과 동일한 우선순위
- **CESP 이벤트 매핑** — GitHub Copilot 훅을 표준 CESP 카테고리로 매핑 (`session.start`, `task.complete`, `task.error`, `user.spam`)
- **데스크톱 알림** — 기본값은 대형 오버레이 배너, 또는 시스템 알림
- **스팸 감지** — 10초 내 3회 이상 빠른 프롬프트 감지 시 `user.spam` 음성 트리거
- **세션 추적** — Copilot sessionId별 독립 세션 마커

### OpenCode 설정

[OpenCode](https://opencode.ai/)용 네이티브 TypeScript 플러그인으로, [CESP v1.0](https://github.com/PeonPing/openpeon) 표준을 완전히 준수합니다.

**빠른 설치:**

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh | bash
```

설치 프로그램이 `peon-ping.ts`를 `~/.config/opencode/plugins/`에 복사하고, `~/.config/opencode/peon-ping/config.json`에 설정 파일을 생성합니다. 사운드 팩은 공유 CESP 경로(`~/.openpeon/packs/`)에 저장됩니다.

**기능:**

- **사운드 재생** — `afplay` (macOS), `pw-play`/`paplay`/`ffplay` (Linux) — 셸 훅과 동일한 우선순위
- **CESP 이벤트 매핑** — `session.created` / `session.idle` / `session.error` / `permission.asked` / 빠른 프롬프트 감지를 모두 표준 CESP 카테고리로 매핑
- **데스크톱 알림** — 기본값은 대형 오버레이 배너 (JXA Cocoa, 모든 화면에서 표시), 또는 [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) / `osascript`를 통한 표준 알림. 터미널이 포커스되지 않았을 때만 작동
- **터미널 포커스 감지** — AppleScript로 사용 중인 터미널 앱 (Terminal, iTerm2, Warp, Alacritty, kitty, WezTerm, ghostty, Hyper)이 최전면에 있는지 확인
- **탭 제목** — 작업 상태를 보여주도록 터미널 탭 제목 업데이트 (`● project: working...` / `✓ project: done` / `✗ project: error`)
- **팩 전환** — 설정에서 `default_pack`을 읽음 (레거시 설정의 `active_pack` 폴백 지원). 런타임에 팩의 `openpeon.json` 매니페스트를 로드. `path_rules`로 작업 디렉토리에 따라 팩 오버라이드 가능
- **중복 방지** — 카테고리별로 같은 사운드가 연속 재생되지 않음
- **스팸 감지** — 10초 내 3회 이상 빠른 프롬프트 감지 시 `user.spam` 음성 트리거

<details>
<summary>🖼️ 스크린샷: 커스텀 피언 아이콘이 적용된 데스크톱 알림</summary>

![peon-ping OpenCode notifications](https://github.com/user-attachments/assets/e433f9d1-2782-44af-a176-71875f3f532c)

</details>

> **팁:** `terminal-notifier`를 설치하면 (`brew install terminal-notifier`) 부제목과 그룹화를 지원하는 더 풍부한 알림을 받을 수 있습니다.

<details>
<summary>🎨 선택 사항: 알림용 커스텀 피언 아이콘</summary>

기본적으로 `terminal-notifier`는 일반 터미널 아이콘을 표시합니다. 포함된 스크립트가 macOS 내장 도구(`sips` + `iconutil`)를 사용해 피언 아이콘으로 교체합니다 — 추가 의존성이 필요 없습니다.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/setup-icon.sh)
```

또는 로컬 설치 (Homebrew / git clone):

```bash
bash ~/.claude/hooks/peon-ping/adapters/opencode/setup-icon.sh
```

스크립트가 피언 아이콘을 자동으로 찾아 (Homebrew libexec, OpenCode 설정 또는 Claude 훅 디렉토리) 올바른 `.icns`를 생성하고, 원본 `Terminal.icns`를 백업한 뒤 교체합니다. `brew upgrade terminal-notifier` 후 다시 실행하세요.

> **향후 계획:** [jamf/Notifier](https://github.com/jamf/Notifier)가 Homebrew에 배포되면 ([#32](https://github.com/jamf/Notifier/issues/32)) 플러그인이 이를 사용하도록 전환될 예정입니다 — Notifier에는 `--rebrand` 지원이 내장되어 있어 아이콘 해킹이 필요 없습니다.

</details>

### Kilo CLI 설정

[Kilo CLI](https://github.com/kilocode/cli)용 네이티브 TypeScript 플러그인으로, [CESP v1.0](https://github.com/PeonPing/openpeon) 표준을 완전히 준수합니다. Kilo CLI는 OpenCode의 포크로 같은 플러그인 시스템을 사용합니다 — 이 설치 프로그램이 OpenCode 플러그인을 다운로드하고 Kilo용으로 패치합니다.

**빠른 설치:**

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/kilo.sh | bash
```

설치 프로그램이 `peon-ping.ts`를 `~/.config/kilo/plugins/`에 복사하고, `~/.config/kilo/peon-ping/config.json`에 설정 파일을 생성합니다. 사운드 팩은 공유 CESP 경로(`~/.openpeon/packs/`)에 저장됩니다.

**기능:** [OpenCode 어댑터](#opencode-설정)와 동일 — 사운드 재생, CESP 이벤트 매핑, 데스크톱 알림, 터미널 포커스 감지, 탭 제목, 팩 전환, 중복 방지, 스팸 감지.

### Gemini CLI 설정

**Gemini CLI**용 셸 어댑터로, [CESP v1.0](https://github.com/PeonPing/openpeon) 표준을 완전히 준수합니다.

**설정 방법:**

1. peon-ping이 설치되어 있는지 확인 (`curl -fsSL https://peonping.com/install | bash`)

2. `~/.gemini/settings.json`에 다음 훅을 추가:

   ```json
   {
     "hooks": {
       "SessionStart": [
         {
           "matcher": "startup",
           "type": "command",
           "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh SessionStart"
         }
       ],
       "AfterAgent": [
         {
           "matcher": "*",
           "type": "command",
           "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh AfterAgent"
         }
       ],
       "AfterTool": [
         {
           "matcher": "*",
           "type": "command",
           "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh AfterTool"
         }
       ],
       "Notification": [
         {
           "matcher": "*",
           "type": "command",
           "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh Notification"
         }
       ]
     }
   }
   ```

**이벤트 매핑:**

- `SessionStart` (startup) → 인사 사운드 (*"Ready to work?"*, *"Yes?"*)
- `AfterAgent` → 작업 완료 사운드 (*"Work, work."*, *"Job's done!"*)
- `AfterTool` → 성공 = 완료 사운드, 실패 = 에러 사운드 (*"I can't do that."*)
- `Notification` → 시스템 알림

### Windsurf 설정

`~/.codeium/windsurf/hooks.json` (사용자 수준) 또는 `.windsurf/hooks.json` (워크스페이스 수준)에 추가:

```json
{
  "hooks": {
    "post_cascade_response": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh post_cascade_response", "show_output": false }
    ],
    "pre_user_prompt": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh pre_user_prompt", "show_output": false }
    ],
    "post_write_code": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh post_write_code", "show_output": false }
    ],
    "post_run_command": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh post_run_command", "show_output": false }
    ]
  }
}
```

### Kiro 설정

`~/.kiro/agents/peon-ping.json`을 생성:

```json
{
  "hooks": {
    "agentSpawn": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro.sh" }
    ],
    "userPromptSubmit": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro.sh" }
    ],
    "stop": [
      { "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro.sh" }
    ]
  }
}
```

`preToolUse`/`postToolUse`는 의도적으로 제외했습니다 — 모든 도구 호출마다 실행되어 너무 시끄럽습니다.

## 원격 개발 (SSH / Devcontainers / Codespaces)

원격 서버나 컨테이너에서 코딩하시나요? peon-ping이 SSH 세션, 데브컨테이너, Codespaces를 자동 감지하고, 로컬 머신에서 실행 중인 경량 릴레이를 통해 오디오와 알림을 전달합니다.

### SSH 설정

1. **로컬 머신에서** 릴레이를 시작합니다:
   ```bash
   peon relay --daemon
   ```

2. **포트 포워딩으로 SSH 접속**:
   ```bash
   ssh -R 19998:localhost:19998 your-server
   ```

3. **원격 서버에 peon-ping 설치** — SSH 세션을 자동 감지하고 포워딩된 포트를 통해 오디오 요청을 로컬 릴레이로 전송합니다.

이게 전부입니다. 소리는 원격 서버가 아닌 내 노트북에서 재생됩니다.

### Devcontainers / Codespaces

포트 포워딩이 필요 없습니다 — peon-ping이 `REMOTE_CONTAINERS`와 `CODESPACES` 환경 변수를 자동 감지하고 오디오를 `host.docker.internal:19998`로 라우팅합니다. 호스트 머신에서 `peon relay --daemon`만 실행하면 됩니다.

### 릴레이 명령어

```bash
peon relay                # 포그라운드에서 릴레이 시작
peon relay --daemon       # 백그라운드에서 시작
peon relay --stop         # 백그라운드 릴레이 중지
peon relay --status       # 릴레이 실행 여부 확인
peon relay --port=12345   # 커스텀 포트 (기본값: 19998)
peon relay --bind=0.0.0.0 # 모든 인터페이스에서 수신 (보안 약화)
```

환경 변수: `PEON_RELAY_PORT`, `PEON_RELAY_HOST`, `PEON_RELAY_BIND`.

peon-ping이 SSH 또는 컨테이너 세션을 감지했지만 릴레이에 연결할 수 없으면, `SessionStart` 시 설정 안내를 출력합니다.

### 카테고리 기반 API (경량 원격 훅용)

릴레이는 서버 측에서 사운드 선택을 처리하는 카테고리 기반 엔드포인트를 지원합니다. peon-ping이 설치되지 않은 원격 머신에서 유용합니다 — 원격 훅이 카테고리 이름만 보내면, 릴레이가 활성 팩에서 랜덤으로 사운드를 선택합니다.

**엔드포인트:**

| 엔드포인트 | 설명 |
|---|---|
| `GET /health` | 헬스 체크 ("OK" 반환) |
| `GET /play?file=<path>` | 특정 사운드 파일 재생 (레거시) |
| `GET /play?category=<cat>` | 카테고리에서 랜덤 사운드 재생 (추천) |
| `POST /notify` | 데스크톱 알림 전송 |

**원격 훅 예시 (`scripts/remote-hook.sh`):**

```bash
#!/bin/bash
RELAY_URL="${PEON_RELAY_URL:-http://127.0.0.1:19998}"
EVENT=$(cat | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name',''))" 2>/dev/null)
case "$EVENT" in
  SessionStart)      CATEGORY="session.start" ;;
  Stop)              CATEGORY="task.complete" ;;
  PermissionRequest) CATEGORY="input.required" ;;
  *)                 exit 0 ;;
esac
curl -sf "${RELAY_URL}/play?category=${CATEGORY}" >/dev/null 2>&1 &
```

이 스크립트를 원격 머신에 복사하고 `~/.claude/settings.json`에 등록하세요:

```json
{
  "hooks": {
    "SessionStart": [{"command": "bash /path/to/remote-hook.sh"}],
    "Stop": [{"command": "bash /path/to/remote-hook.sh"}],
    "PermissionRequest": [{"command": "bash /path/to/remote-hook.sh"}]
  }
}
```

릴레이는 로컬 머신의 `config.json`에서 활성 팩과 볼륨을 읽어, 팩 매니페스트를 로드하고 중복을 피하면서 랜덤 사운드를 선택합니다.

## 모바일 알림

작업 완료나 관심이 필요할 때 스마트폰으로 푸시 알림을 받을 수 있습니다 — 자리를 비웠을 때 유용합니다.

### 빠른 시작 (ntfy.sh — 무료, 계정 불필요)

1. 스마트폰에 [ntfy 앱](https://ntfy.sh)을 설치합니다
2. 앱에서 고유한 토픽을 구독합니다 (예: `my-peon-notifications`)
3. 실행:
   ```bash
   peon mobile ntfy my-peon-notifications
   ```

[Pushover](https://pushover.net)와 [Telegram](https://core.telegram.org/bots)도 지원합니다:

```bash
peon mobile pushover <user_key> <app_token>
peon mobile telegram <bot_token> <chat_id>
```

### 모바일 명령어

```bash
peon mobile on            # 모바일 알림 활성화
peon mobile off           # 모바일 알림 비활성화
peon mobile status        # 현재 설정 표시
peon mobile test          # 테스트 알림 보내기
```

모바일 알림은 창 포커스와 관계없이 모든 이벤트에서 발생합니다 — 데스크톱 알림 및 사운드와 독립적으로 동작합니다.

## 사운드 팩

워크래프트, 스타크래프트, 레드 얼럿, 포탈, 젤다, Dota 2, 헬다이버즈 2, 엘더 스크롤 등 75개 이상의 팩이 있습니다. 기본 설치에는 5개의 엄선된 팩이 포함됩니다:

| 팩 | 캐릭터 | 사운드 |
|---|---|---|
| `peon` (기본) | 오크 피언 (워크래프트 III) | "Ready to work?", "Work, work.", "Okie dokie." |
| `peasant` | 인간 농부 (워크래프트 III) | "Yes, milord?", "Job's done!", "Ready, sir." |
| `sc_kerrigan` | 사라 케리건 (스타크래프트) | "I gotcha", "What now?", "Easily amused, huh?" |
| `sc_battlecruiser` | 배틀크루저 (스타크래프트) | "Battlecruiser operational", "Make it happen", "Engage" |
| `glados` | GLaDOS (포탈) | "Oh, it's you.", "You monster.", "Your entire team is dead." |

**[모든 팩 둘러보기 및 오디오 미리듣기 &rarr; openpeon.com/packs](https://openpeon.com/packs)**

`--all`로 전체 설치하거나, 언제든지 팩을 전환할 수 있습니다:

```bash
peon packs use glados             # 특정 팩으로 전환
peon packs use --install glados   # 설치(또는 업데이트) 후 전환을 한 번에
peon packs next                   # 다음 팩으로 순환
peon packs list                   # 모든 설치된 팩 목록
peon packs list --registry        # 사용 가능한 모든 팩 검색
peon packs install glados,murloc  # 특정 팩 설치
peon packs install --all          # 레지스트리의 모든 팩 설치
```

나만의 팩을 추가하고 싶으신가요? [openpeon.com/create 전체 가이드](https://openpeon.com/create) 또는 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

## 제거

**macOS/Linux:**

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/uninstall.sh        # 전역
bash .claude/hooks/peon-ping/uninstall.sh           # 프로젝트 로컬
```

**Windows (PowerShell):**

```powershell
# 일반 제거 (사운드 삭제 전 확인 프롬프트)
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\peon-ping\uninstall.ps1"

# 사운드 팩 유지 (나머지만 제거)
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\peon-ping\uninstall.ps1" -KeepSounds
```

## 시스템 요구사항

- **macOS** — `afplay` (내장), JXA Cocoa 오버레이 또는 AppleScript로 알림
- **Linux** — 다음 중 하나: `pw-play`, `paplay`, `ffplay`, `mpv`, `play` (SoX), 또는 `aplay`; 알림에는 `notify-send`
- **Windows** — 네이티브 PowerShell + `MediaPlayer` 및 WinForms (WSL 불필요), 또는 WSL2
- **모든 플랫폼** — `python3` (네이티브 Windows에서는 불필요)
- **SSH/원격** — 원격 호스트에 `curl` 필요
- **IDE** — 훅을 지원하는 Claude Code (또는 [어댑터](#멀티-ide-지원)를 통한 모든 지원 IDE)

## 동작 원리

`peon.sh`는 `SessionStart`, `SessionEnd`, `SubagentStart`, `Stop`, `Notification`, `PermissionRequest`, `PostToolUseFailure`, `PreCompact` 이벤트에 등록된 Claude Code 훅입니다. 각 이벤트 발생 시:

1. **이벤트 매핑** — 내장된 Python 블록이 훅 이벤트를 [CESP](https://github.com/PeonPing/openpeon) 사운드 카테고리로 매핑 (`session.start`, `task.complete`, `input.required` 등)
2. **사운드 선택** — 활성 팩의 매니페스트에서 중복을 피하며 랜덤으로 음성을 선택
3. **오디오 재생** — `afplay` (macOS), PowerShell `MediaPlayer` (WSL2), 또는 `pw-play`/`paplay`/`ffplay`/`mpv`/`aplay` (Linux)를 통해 비동기 재생
4. **알림** — 터미널 탭 제목을 업데이트하고, 터미널이 포커스되지 않았으면 데스크톱 알림 전송
5. **원격 라우팅** — SSH 세션, 데브컨테이너, Codespaces에서는 오디오와 알림 요청이 HTTP를 통해 로컬 머신의 [릴레이 서버](#원격-개발-ssh--devcontainers--codespaces)로 전달

사운드 팩은 설치 시 [OpenPeon 레지스트리](https://github.com/PeonPing/registry)에서 다운로드됩니다. 공식 팩은 [PeonPing/og-packs](https://github.com/PeonPing/og-packs)에 호스팅됩니다. 사운드 파일은 각 배급사(Blizzard, Valve, EA 등)의 소유이며, 개인 알림 목적의 공정 사용으로 배포됩니다.

## 링크

- [@peonping on X](https://x.com/peonping) — 업데이트 및 공지
- [peonping.com](https://peonping.com/) — 랜딩 페이지
- [openpeon.com](https://openpeon.com/) — CESP 표준, 팩 브라우저, 팩 만들기 가이드
- [OpenPeon 레지스트리](https://github.com/PeonPing/registry) — 사운드 팩 레지스트리 (GitHub Pages)
- [og-packs](https://github.com/PeonPing/og-packs) — 공식 사운드 팩
- [peon-pet](https://github.com/PeonPing/peon-pet) — macOS 데스크톱 펫 (오크 스프라이트, 훅 이벤트에 반응)
- [라이선스 (MIT)](LICENSE)

## 프로젝트 후원

- Venmo: [@garysheng](https://venmo.com/garysheng)
- 커뮤니티 토큰 (DYOR / 재미 목적): 누군가 Base에 $PEON 토큰을 만들었습니다 — 거래 수수료가 개발 지원에 사용됩니다. [`0xf4ba744229afb64e2571eef89aacec2f524e8ba3`](https://dexscreener.com/base/0xf4bA744229aFB64E2571eef89AaceC2F524e8bA3)
