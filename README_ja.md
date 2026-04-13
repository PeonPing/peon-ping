# peon-ping
<div align="center">

[English](README.md) | [한국어](README_ko.md) | [中文](README_zh.md) | **日本語**

![macOS](https://img.shields.io/badge/macOS-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue) ![Linux](https://img.shields.io/badge/Linux-blue) ![Windows](https://img.shields.io/badge/Windows-blue) ![MSYS2](https://img.shields.io/badge/MSYS2-blue) ![SSH](https://img.shields.io/badge/SSH-blue)
![License](https://img.shields.io/badge/license-MIT-green)

![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01) ![Amp](https://img.shields.io/badge/Amp-adapter-ffab01) ![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-adapter-ffab01) ![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-adapter-ffab01) ![Codex](https://img.shields.io/badge/Codex-adapter-ffab01) ![Cursor](https://img.shields.io/badge/Cursor-adapter-ffab01) ![OpenCode](https://img.shields.io/badge/OpenCode-adapter-ffab01) ![Kilo CLI](https://img.shields.io/badge/Kilo_CLI-adapter-ffab01) ![Kiro](https://img.shields.io/badge/Kiro-adapter-ffab01) ![Kimi Code](https://img.shields.io/badge/Kimi_Code-adapter-ffab01) ![Windsurf](https://img.shields.io/badge/Windsurf-adapter-ffab01) ![Antigravity](https://img.shields.io/badge/Antigravity-adapter-ffab01) ![OpenClaw](https://img.shields.io/badge/OpenClaw-adapter-ffab01) ![Rovo Dev CLI](https://img.shields.io/badge/Rovo_Dev_CLI-adapter-ffab01) ![DeepAgents](https://img.shields.io/badge/DeepAgents-adapter-ffab01)

**AIコーディングエージェントが注意を必要とする時に、ゲームキャラクターのボイスライン＋ビジュアルオーバーレイ通知を再生 — またはMCPでエージェント自身にサウンドを選ばせることも可能。**

AIコーディングエージェントは、完了時や許可が必要な時に通知してくれません。タブを切り替えて集中力を失い、フローに戻るのに15分も無駄にしてしまいます。peon-pingは、Warcraft、StarCraft、Portal、Zelda などのゲームのボイスラインと目立つ画面バナーでこの問題を解決します — **Claude Code**、**Amp**、**GitHub Copilot**、**Codex**、**Cursor**、**OpenCode**、**Kilo CLI**、**Kiro**、**Kimi Code**、**Windsurf**、**Google Antigravity**、**Rovo Dev CLI**、**DeepAgents**、および任意のMCPクライアントに対応。

**デモを見る** &rarr; [peonping.com](https://peonping.com/)

<video src="https://github.com/user-attachments/assets/149b6d15-65c2-41f2-9b56-13575ff8364b" autoplay loop muted playsinline width="400"></video>

</div>

---

- [インストール](#インストール)
- [再生されるサウンド](#再生されるサウンド)
- [クイックコントロール](#クイックコントロール)
- [設定](#設定)
- [Peon トレーナー](#peon-トレーナー)
- [MCP サーバー](#mcp-サーバー)
- [マルチIDE対応](#マルチide対応)
- [リモート開発](#リモート開発ssh--devcontainers--codespaces)
- [モバイル通知](#モバイル通知)
- [サウンドパック](#サウンドパック)
- [アンインストール](#アンインストール)
- [必要環境](#必要環境)
- [仕組み](#仕組み)
- [リンク](#リンク)

---

## インストール

### 方法1: Homebrew（推奨）

```bash
brew install PeonPing/tap/peon-ping
```

`peon-ping-setup` を実行してフックの登録とサウンドパックのダウンロードを行います。macOS と Linux に対応。

### 方法2: インストールスクリプト（macOS、Linux、WSL2）

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash
```

⚠️ WSL2 では、**WAV** 以外のフォーマットのサウンドパックを使用するには **ffmpeg** のインストールが必要です。Debian 系ディストリビューションでは以下のコマンドでインストールできます：

```sh
sudo apt update; sudo apt install -y ffmpeg
```

### 方法3: Windows インストーラー

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.ps1" -UseBasicParsing | Invoke-Expression
```

デフォルトで5つの厳選パック（Warcraft、StarCraft、Portal）がインストールされます。再実行すると設定/状態を保持したまま更新されます。**[peonping.comでパックをインタラクティブに選択](https://peonping.com/#picker)** して、カスタムインストールコマンドを取得することもできます。

便利なインストーラーフラグ：

- `--all` — 利用可能なすべてのパックをインストール
- `--packs=peon,sc_kerrigan,...` — 指定パックのみインストール
- `--local` — パック、設定、フックを現在のプロジェクトの `./.claude/` にインストール
- `--global` — 明示的なグローバルインストール（デフォルトと同じ）
- `--init-local-config` — `./.claude/hooks/peon-ping/config.json` のみ作成

`--local` はシェルの rc ファイルを変更しません（グローバルな `peon` エイリアス/補完の注入なし）。フックはプロジェクトレベルの `./.claude/settings.json` に絶対パスで登録されるため、プロジェクト内のどの作業ディレクトリからでも動作します。

例：

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --all
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --packs=peon,sc_kerrigan
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --local
```

グローバルインストールが既にある状態でローカルインストール（またはその逆）を行うと、競合を避けるために既存のものを削除するよう促されます。

### 方法4: クローンして確認

```bash
git clone https://github.com/PeonPing/peon-ping.git
cd peon-ping
./install.sh
```

### 方法5: Nix（macOS、Linux）

ソースから直接実行（インストール不要）：

```bash
nix run github:PeonPing/peon-ping -- status
nix run github:PeonPing/peon-ping -- packs install peon
```

プロファイルにインストール：

```bash
nix profile install github:PeonPing/peon-ping
```

開発シェル（bats、shellcheck、nodejs）：

```bash
nix develop  # or use direnv
```

#### Home Manager モジュール（宣言的設定）

再現可能なセットアップには、Home Manager モジュールを使用：

```nix
# In your home.nix or flake.nix
{ inputs, pkgs, ... }:

let
  peonCursorAdapterPath = "${inputs.peon-ping.packages.${pkgs.system}.default}/share/peon-ping/adapters/cursor.sh";
in {
  imports = [ inputs.peon-ping.homeManagerModules.default ];

  programs.peon-ping = {
    enable = true;
    package = inputs.peon-ping.packages.${pkgs.system}.default;

    settings = {
      default_pack = "glados";
      volume = 0.7;
      enabled = true;
      desktop_notifications = true;
      categories = {
        "session.start" = true;
        "task.complete" = true;
        "task.error" = true;
        "input.required" = true;
        "resource.limit" = true;
        "user.spam" = true;
      };
    };

    # og-packs からパックをインストール（シンプルな文字列表記）
    # およびカスタムソース（name + src の attrset）
    installPacks = [
      "peon"
      "glados"
      "sc_kerrigan"
      # GitHub からカスタムパック（openpeon.com レジストリ）
      {
        name = "mr_meeseeks";
        src = pkgs.fetchFromGitHub {
          owner = "kasperhendriks";
          repo = "openpeon-mrmeeseeks";
          rev = "main";  # or use a commit hash for reproducibility
          sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };
      }
    ];
    enableZshIntegration = true;
  };

  # Cursor hooks
  home.file.".cursor/hooks.json".text = builtins.toJSON {
    version = 1;
    hooks = {
      afterAgentResponse = [{ command = "bash ${peonCursorAdapterPath} afterAgentResponse"; }];
      stop               = [{ command = "bash ${peonCursorAdapterPath} stop"; }];
    };
  };
}
```

**サウンドパックのインストール**: `installPacks` オプションは2つの形式をサポートしています：
- **シンプルな文字列**（例: `"peon"`、`"glados"`）— [og-packs](https://github.com/PeonPing/og-packs) リポジトリから取得
- **カスタムソース** — `name` と `src` フィールドを持つ attrset で、`src` は任意の Nix フェッチャー結果（例: `pkgs.fetchFromGitHub`）

[openpeon.com](https://openpeon.com/) に掲載されているパックの場合、GitHub リポジトリのリンクを確認し `pkgs.fetchFromGitHub` を使用：
```nix
{
  name = "pack_name";
  src = pkgs.fetchFromGitHub {
    owner = "github-owner";
    repo = "repo-name";
    rev = "main";  # or a commit hash/tag
    sha256 = "";   # Leave empty first, Nix will tell you the correct hash
  };
}
```

**IDE フック**: peon-ping の Home Manager モジュールは、競合する更新を避けるため IDE フックのセットアップを行いません。IDE の管理方法に応じてフックを自分で定義する必要があります（上記の例を参照）。
- peon-ping は `cursor.sh` などの各種 IDE 向けアダプタースクリプトを提供しています — [`adapters/`](https://github.com/PeonPing/peon-ping/tree/main/adapters) を参照
- 以下のようにフックとして呼び出す必要があります：
  ```sh
  ${inputs.peon-ping.packages.${pkgs.system}.default}/share/peon-ping/adapters/$YOUR_IDE.sh EVENT_NAME
  ```
  上記の Cursor の例を参照してください

## 再生されるサウンド

| イベント | CESP カテゴリ | 例 |
|---|---|---|
| セッション開始 | `session.start` | *"Ready to work?"*, *"Yes?"*, *"What you want?"* |
| タスク完了 | `task.complete` | *"Work, work."*, *"I can do that."*, *"Okie dokie."* |
| ツールまたはコマンドエラー | `task.error` | *"I can't do that."*, *"Son of a bitch!"* |
| エージェントがタスクを確認 | `task.acknowledge` | *"I read you."*, *"On it."* *(デフォルトで無効)* |
| 許可が必要 | `input.required` | *"Something need doing?"*, *"Hmm?"*, *"What you want?"* |
| レートまたはトークン制限 | `resource.limit` | *"Zug zug."* *(パックによる)* |
| 高速プロンプト（10秒以内に3回以上）| `user.spam` | *"Me busy, leave me alone!"* |

さらに、すべての画面に**大型オーバーレイバナー**（macOS/WSL/MSYS2）とターミナルタブタイトル（`● project: done`）が表示され、他のアプリを使用中でも何か起きたことがすぐにわかります。

peon-ping は [Coding Event Sound Pack Specification (CESP)](https://github.com/PeonPing/openpeon) を実装しています — 任意のエージェント型 IDE が採用できるコーディングイベントサウンドのオープンスタンダードです。

## クイックコントロール

会議やペアプログラミング中にミュートしたい場合、2つの方法があります：

| 方法 | コマンド | 使用場面 |
|---|---|---|
| **スラッシュコマンド** | `/peon-ping-toggle` | Claude Code で作業中 |
| **CLI** | `peon toggle` | 任意のターミナルタブから |

その他の CLI コマンド：

```bash
peon pause                # サウンドをミュート
peon resume               # ミュート解除
peon mute                 # 'pause' のエイリアス
peon unmute               # 'resume' のエイリアス
peon status               # 一時停止中かアクティブか確認
peon volume               # 現在の音量を表示
peon volume 0.7           # 音量設定（0.0〜1.0）
peon rotation             # 現在のローテーションモードを表示
peon rotation random      # ローテーションモード設定（random|round-robin|session_override）
peon packs list           # インストール済みサウンドパック一覧
peon packs list --registry # レジストリの全パックを閲覧
peon packs community      # 信頼ティア別にレジストリパックを一覧（Windows）
peon packs search <query> # レジストリパックを名前で検索（Windows）
peon packs install <p1,p2> # レジストリからパックをインストール
peon packs install --all  # レジストリの全パックをインストール
peon packs install-local <path> # ローカルディレクトリからパックをインストール
peon packs use <name>     # 特定パックに切り替え（Windows ではレジストリから自動インストール）
peon packs use --install <name>  # 必要に応じてレジストリからインストールして切り替え
peon packs next           # 次のパックに切り替え
peon packs remove <p1,p2> # 特定パックを削除
peon packs bind <name>    # 現在のディレクトリにパックをバインド
peon packs bind --pattern <path> # ディレクトリパターンにバインド（例: "*/services"）
peon packs unbind         # 現在のディレクトリのバインドを解除
peon packs bindings       # すべてのバインド一覧
peon notifications on     # デスクトップ通知を有効化
peon notifications off    # デスクトップ通知を無効化
peon notifications overlay   # 大型オーバーレイバナーを使用（デフォルト）
peon notifications standard  # 標準システム通知を使用
peon notifications test      # テスト通知を送信
peon notifications position [pos]    # 通知位置の取得/設定（top-left, top-center, top-right, bottom-left, bottom-center, bottom-right）
peon notifications dismiss [N]       # 自動消去時間（秒）の取得/設定（0 = 永続）
peon notifications label [text|reset] # プロジェクトラベルの取得/設定
peon notifications template [key] [fmt]  # メッセージテンプレートの取得/設定/リセット（キー: stop, permission, error, idle, question）
peon preview              # session.start のすべてのサウンドを再生
peon preview <category>   # 特定カテゴリのすべてのサウンドを再生
peon preview --list       # アクティブパックのカテゴリ一覧
peon mobile ntfy <topic>  # モバイル通知を設定（無料）
peon mobile off           # モバイル通知を無効化
peon mobile test          # テスト通知を送信
peon relay --daemon       # オーディオリレーを開始（SSH/devcontainer 用）
peon relay --stop         # バックグラウンドリレーを停止
```

`peon preview` で利用可能な CESP カテゴリ: `session.start`、`task.acknowledge`、`task.complete`、`task.error`、`input.required`、`resource.limit`、`user.spam`。（拡張カテゴリ `session.end` と `task.progress` は CESP 仕様で定義されパックマニフェストでサポートされていますが、現在は組み込みフックイベントによるトリガーはありません。）

Tab 補完に対応 — `peon packs use <TAB>` と入力すると利用可能なパック名が表示されます。

一時停止するとサウンドとデスクトップ通知が即座にミュートされます。再開するまでセッション間で保持されます。一時停止中もタブタイトルは更新されます。

## 設定

peon-ping は Claude Code に以下のスラッシュコマンドをインストールします：

- `/peon-ping-toggle` — サウンドのミュート/ミュート解除
- `/peon-ping-config` — 任意の設定を変更（音量、パック、カテゴリなど）
- `/peon-ping-rename <name>` — 現在のセッションにカスタム名を設定。通知タイトルとターミナルタブタイトルに表示されます（ゼロトークン、フック処理）。引数なしで自動検出にリセット

Claude に設定変更を依頼することもできます — 例えば「パックのラウンドロビンローテーションを有効にして」「音量を0.3に設定して」「gladosをパックローテーションに追加して」など。設定ファイルを手動で編集する必要はありません。

設定ファイルの場所はインストールモードによって異なります：

- グローバルインストール: `$CLAUDE_CONFIG_DIR/hooks/peon-ping/config.json`（デフォルト `~/.claude/hooks/peon-ping/config.json`）
- ローカルインストール: `./.claude/hooks/peon-ping/config.json`

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

### 独立コントロール

peon-ping には3つの独立したコントロールがあり、自由に組み合わせて使用できます：

| 設定キー | 制御対象 | サウンドに影響 | デスクトップポップアップに影響 | モバイルプッシュに影響 |
|----------|----------|----------------|-------------------------------|------------------------|
| `enabled` | メインオーディオスイッチ | ✅ はい | ❌ いいえ | ❌ いいえ |
| `desktop_notifications` | デスクトップポップアップバナー | ❌ いいえ | ✅ はい | ❌ いいえ |
| `mobile_notify.enabled` | モバイルプッシュ通知 | ❌ いいえ | ❌ いいえ | ✅ はい |

これにより以下のような使い方ができます：
- サウンドを残してデスクトップポップアップを無効化: `peon notifications off`
- デスクトップポップアップを残してサウンドを無効化: `peon pause`
- デスクトップポップアップなしでモバイルプッシュを有効化: `desktop_notifications: false` と `mobile_notify.enabled: true` を設定

- **volume**: 0.0〜1.0（オフィスでも使える音量）
- **desktop_notifications**: `true`/`false` — サウンドとは独立にデスクトップ通知ポップアップを切り替え（デフォルト: `true`）。無効にするとサウンドは再生されますがビジュアルポップアップは抑制されます。モバイル通知には影響しません。
- **notification_style**: `"overlay"` または `"standard"` — デスクトップ通知の表示方法を制御（デフォルト: `"overlay"`）
  - **overlay**: 大型の目立つバナー — macOS では JXA Cocoa オーバーレイ、WSL/MSYS2 では Windows Forms ポップアップ。オーバーレイをクリックするとターミナルにフォーカス（Ghostty、Warp、iTerm2、Zed、Terminal.app に対応）。iTerm2 ではクリックで正しいタブ/ペイン/ウィンドウにフォーカスします。
  - **standard**: システム通知 — macOS では [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) / `osascript`、WSL/MSYS2 では Windows toast。`terminal-notifier` がインストールされている場合（`brew install terminal-notifier`）、通知をクリックすると自動的にターミナルにフォーカス（Ghostty、Warp、iTerm2、Zed、Terminal.app に対応）。ネイティブ Windows では、toast 通知をクリックすると IDE またはターミナルウィンドウにフォーカス（VS Code、Cursor、Windsurf、Windows Terminal、PowerShell に対応）。複数ウィンドウが開いている場合、PID ベースのプロセスツリーマッチングにより、イベントを発生させた正確なウィンドウが通知のターゲットになります。
- **overlay_theme**: `"jarvis"`、`"glass"`、`"sakura"`、または省略でデフォルトオーバーレイ — macOS のみ（デフォルト: なし）
  - **jarvis**: 回転するアーク、目盛り、プログレスリング付きの円形 HUD
  - **glass**: アクセントカラーバー、プログレスライン、タイムスタンプ付きのグラスモーフィズムパネル
  - **sakura**: 盆栽の木とアニメーション桜の花びら付きの禅庭園
- **categories**: 個別の CESP サウンドカテゴリのオン/オフを切り替え（例: `"session.start": false` で挨拶サウンドを無効化）
- **annoyed_threshold / annoyed_window_seconds**: N 秒以内に何回のプロンプトで `user.spam` イースターエッグがトリガーされるか
- **silent_window_seconds**: N 秒未満のタスクの `task.complete` サウンドと通知を抑制（例: `10` にすると10秒以上かかるタスクのみサウンドが再生される）
- **session_start_cooldown_seconds**（数値、デフォルト: `30`）: 複数のワークスペースが同時に起動した時（例: OpenCode や Cursor で複数フォルダを開いた時）の挨拶サウンドの重複を排除。最初のセッション開始のみ挨拶が再生され、このウィンドウ内の後続セッションは無音。`0` に設定すると重複排除を無効にし、常に挨拶を再生。
- **suppress_subagent_complete**（ブール値、デフォルト: `false`）: サブエージェントセッション終了時の `task.complete` サウンドと通知を抑制。Claude Code の Task ツールが並列サブエージェントを起動すると、各サブエージェントの完了時にサウンドが鳴ります — `true` に設定すると親セッションの完了サウンドのみ再生。
- **default_pack**: より具体的なルールがない場合に使用されるフォールバックパック（デフォルト: `"peon"`）。旧 `active_pack` キーを置き換え — 既存の設定は `peon update` 時に自動移行。
- **path_rules**: `{ "pattern": "...", "pack": "..." }` オブジェクトの配列。作業ディレクトリに基づいてグロブマッチング（`*`、`?`）でセッションにパックを割り当て。最初にマッチしたルールが適用。`pack_rotation` と `default_pack` より優先されますが、`session_override` には劣後します。
  ```json
  "path_rules": [
    { "pattern": "*/work/client-a/*", "pack": "glados" },
    { "pattern": "*/personal/*",      "pack": "peon" }
  ]
  ```
- **pack_rotation**: パック名の配列（例: `["peon", "sc_kerrigan", "peasant"]`）。`pack_rotation_mode` が `random` または `round-robin` の場合に使用。空 `[]` にすると `default_pack`（または `path_rules`）のみ使用。
- **pack_rotation_mode**: `"random"`（デフォルト）、`"round-robin"`、または `"session_override"`。`random`/`round-robin` では各セッションが `pack_rotation` から1つのパックを選択。`session_override` では `/peon-ping-use <pack>` コマンドでセッションごとにパックを割り当て。無効または欠落したパックは階層をフォールバック。（`"agentskill"` は `"session_override"` のレガシーエイリアスとして受け入れられます。）
- **session_ttl_days**（数値、デフォルト: 7）: N 日以上古いセッションごとのパック割り当てを期限切れにします。`session_override` モード使用時に `.state.json` が無制限に増大するのを防ぎます。
- **headphones_only**（ブール値、デフォルト: `false`）: ヘッドフォンまたは外部オーディオデバイスが検出された場合のみサウンドを再生。有効にすると内蔵スピーカーがアクティブ出力の場合にサウンドが抑制されます — オープンオフィスに便利。`peon status` でステータスを確認。macOS（`system_profiler` 経由）および Linux（PipeWire `wpctl` または PulseAudio `pactl` 経由）に対応。
- **suppress_sound_when_tab_focused**（ブール値、デフォルト: `false`）: フックイベントを生成したターミナルタブが現在アクティブ/フォーカスされている場合、サウンド再生をスキップ。バックグラウンドタブでは他の場所で何かが起きたことをアラートとしてサウンドが再生されます。デスクトップとモバイル通知には影響しません。監視していないタブからのみオーディオキューが欲しい場合に便利。macOS のみ（`osascript` で最前面アプリと iTerm2 タブフォーカスを確認）。
- **meeting_detect**: マイクが現在使用中かどうかを検出し、マイクの使用が終わるまで一時的にオーディオのみを抑制。通知は引き続き表示されます。
- **notification_position**（文字列、デフォルト: `"top-center"`）: オーバーレイ通知の画面上の表示位置。オプション: `"top-left"`、`"top-center"`、`"top-right"`、`"bottom-left"`、`"bottom-center"`、`"bottom-right"`。
- **notification_dismiss_seconds**（数値、デフォルト: `4`）: N 秒後にオーバーレイ通知を自動的に消去。`0` に設定するとクリックで消去するまで永続的に表示。
- **`CLAUDE_SESSION_NAME` 環境変数**: `claude` 起動前に設定すると、セッションにカスタム名を付けられます。デスクトップ通知タイトルとターミナルタブタイトルの両方に表示されます。すべての設定ベースの命名より優先。例: `CLAUDE_SESSION_NAME="Auth Refactor" claude` または `export CLAUDE_SESSION_NAME="Feature: Auth"` してから `claude`。各ターミナルは自動的に独自のタイトルを取得します。
- **notification_title_override**（文字列、デフォルト: `""`）: 通知タイトルに表示されるプロジェクト名を上書き。空の場合は自動検出: `/peon-ping-rename` > `CLAUDE_SESSION_NAME` > `.peon-label` > `notification_title_script` > `project_name_map` > git リポジトリ名 > フォルダ名。
- **notification_title_marker**（文字列、デフォルト: `"●"`）: 通知タイトルとターミナルタブタイトル前に表示される文字。`""` に設定すると無効化。例如：`"🔔"`。
- **notification_title_script**（文字列、デフォルト: `""`）: イベント発生時に実行されるシェルコマンドで、プロジェクト名を動的に計算。利用可能な環境変数: `PEON_SESSION_ID`、`PEON_CWD`、`PEON_HOOK_EVENT`、`PEON_SESSION_NAME`。stdout を使用（トリミング済み、最大50文字）; 非ゼロ終了は次のティアにフォールスルー。例: `"basename $PEON_CWD"`。
- **project_name_map**（オブジェクト、デフォルト: `{}`）: ディレクトリパスを通知のカスタムプロジェクトラベルにマッピング。キーはパスパターン、値は表示名。例: `{ "/home/user/work/client-a": "Client A" }`。
- **notification_templates**（オブジェクト、デフォルト: `{}`）: 通知イベントのカスタムメッセージフォーマット文字列。キーはイベントタイプ（`stop`、`permission`、`error`、`idle`、`question`）、値は変数置換付きのテンプレート文字列。利用可能な変数: `{project}`、`{summary}`、`{tool_name}`、`{status}`、`{event}`。例: `{ "stop": "{project}: {summary}", "permission": "{project}: {tool_name} needs approval" }`。

### パック選択の優先順位

peon-ping は5層の階層を通じて使用するサウンドパックを決定します。有効なインストール済みパックを返す最初の層が採用されます：

| 優先度 | 層 | ソース | 設定方法 |
|--------|-----|--------|----------|
| 1（最高） | **session_override** | セッションごとの割り当て | `/peon-ping-use <pack>` スキルまたは MCP |
| 2 | **path_rules** | 作業ディレクトリのグロブマッチ | `peon packs bind` または設定の `path_rules` |
| 3 | **pack_rotation** | リストからランダムまたはラウンドロビン | 設定の `pack_rotation` 配列 + `pack_rotation_mode` |
| 4 | **default_pack** | 静的フォールバック | `peon packs use <name>` または設定の `default_pack` |
| 5（最低） | **ハードコード** | 組み込みデフォルト | `"peon"` |

ある層が参照するパックがインストールされていない場合、次の層にフォールバックします。

### プロジェクトごとのパック割り当て（path_rules）

ディレクトリパスに基づいて異なるプロジェクトに異なるサウンドパックを割り当てます。CLI を使用するか、`config.json` を直接編集できます。

**CLI（推奨）：**

```bash
peon packs bind glados                     # 現在のディレクトリに glados をバインド
peon packs bind sc_kerrigan --pattern "*/services/*"  # グロブパターンにバインド
peon packs bind duke_nukem --install       # バインドし、必要に応じてレジストリからインストール
peon packs unbind                          # 現在のディレクトリのバインドを解除
peon packs unbind --pattern "*/services/*" # 特定パターンのバインドを解除
peon packs bindings                        # すべてのバインド一覧
```

**手動設定：**

```json
"path_rules": [
  { "pattern": "*/work/client-a/*", "pack": "glados" },
  { "pattern": "*/personal/*",      "pack": "peon" },
  { "pattern": "*/services/*",      "pack": "sc_kerrigan" }
]
```

ルールはグロブマッチング（`*`、`?`）を使用。最初にマッチしたルールが適用されます。パスルールは `pack_rotation` と `default_pack` より優先されますが、`session_override` には劣後します。

## よくある使い方

### サウンドのみ（ポップアップなし）

ボイスフィードバックは欲しいけどビジュアルの邪魔はいらない場合：

```bash
peon notifications off
```

すべてのサウンドカテゴリの再生を維持しつつ、デスクトップ通知バナーを抑制します。モバイル通知（設定済みの場合）は引き続き動作します。

エイリアスも使用可能：

```bash
peon popups off
```

### サイレントモード（通知のみ）

ビジュアルアラートは欲しいけどオーディオはいらない場合：

```bash
peon pause  # または設定で "enabled": false
```

`desktop_notifications: true` の場合、ポップアップは表示されますがサウンドは再生されません。

### 完全サイレント

すべてを無効化：

```bash
peon pause
peon notifications off
peon mobile off
```

## Peon トレーナー

あなたのペオンはパーソナルトレーナーでもあります。パヴェルスタイルの毎日のエクササイズモードを内蔵 — 「work work」と言ってくるあのオークが、今度は腕立て伏せ20回を命令してきます。

### クイックスタート

```bash
peon trainer on              # トレーナーを有効化
peon trainer goal 200        # 毎日の目標を設定（デフォルト: 300/300）
# ... しばらくコーディング、ペオンが約20分ごとにうるさく言ってくる ...
peon trainer log 25 pushups  # やった回数を記録
peon trainer log 30 squats
peon trainer status          # 進捗を確認
```

### 仕組み

トレーナーリマインダーはコーディングセッションに連動しています。新しいセッションを開始すると、ペオンがコードを書く前にまず腕立て伏せをするよう促します。その後、アクティブなコーディング中に約20分ごとにもっとやるようペオンが叫びます。バックグラウンドデーモンは不要。`peon trainer log` で回数を記録し、進捗は午前0時に自動リセットされます。

### コマンド

| コマンド | 説明 |
|---------|------|
| `peon trainer on` | トレーナーモードを有効化 |
| `peon trainer off` | トレーナーモードを無効化 |
| `peon trainer status` | 今日の進捗を表示 |
| `peon trainer log <n> <exercise>` | 回数を記録（例: `log 25 pushups`） |
| `peon trainer goal <n>` | すべてのエクササイズの目標を設定 |
| `peon trainer goal <exercise> <n>` | 単一エクササイズの目標を設定 |

### Claude Code スキル

Claude Code では、会話を離れずに回数を記録できます：

```
/peon-ping-log 25 pushups
/peon-ping-log 30 squats
```

### カスタムボイスライン

`~/.claude/hooks/peon-ping/trainer/sounds/` に自分のオーディオファイルを配置：

```
trainer/sounds/session_start/  # セッション挨拶（"Pushups first, code second! Zug zug!"）
trainer/sounds/remind/         # リマインダー（"Something need doing? YES. PUSHUPS."）
trainer/sounds/log/            # 確認（"Work work! Muscles getting bigger maybe!"）
trainer/sounds/complete/       # お祝い（"Zug zug! Human finish all reps!"）
trainer/sounds/slacking/       # 失望（"Peon very disappointed."）
```

`trainer/manifest.json` を更新してサウンドファイルを登録してください。

## MCP サーバー

peon-ping には [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) サーバーが含まれており、MCP 対応の AI エージェントがツールコールで直接サウンドを再生できます — フック不要。

重要な違い: **エージェントがサウンドを選択します**。イベントごとに固定サウンドを自動再生する代わりに、エージェントが `play_sound` を呼び出して欲しいサウンドを指定します — ビルド失敗時に `duke_nukem/SonOfABitch`、ファイル読み込み時に `sc_kerrigan/IReadYou` など。

### セットアップ

MCP クライアントの設定に追加（Claude Desktop、Cursor など）：

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

Homebrew でインストールした場合のパス: `$(brew --prefix peon-ping)/libexec/mcp/peon-mcp.js`。詳細なセットアップ手順は [`mcp/README.md`](mcp/README.md) を参照。

### エージェントができること

| 機能 | 説明 |
|---|---|
| **`play_sound`** | キーでサウンドを再生（例: `duke_nukem/SonOfABitch`、`peon/PeonReady1`） |
| **`peon-ping://catalog`** | MCP リソースとしての完全なパックカタログ — クライアントが一度プリフェッチするので繰り返しのツールコール不要 |
| **`peon-ping://pack/{name}`** | 個別パックの詳細と利用可能なサウンドキー |

Node.js 18+ が必要。[@tag-assistant](https://github.com/tag-assistant) により提供。

## マルチIDE対応

peon-ping はフックをサポートする任意のエージェント型 IDE で動作します。アダプターは IDE 固有のイベントを [CESP 標準](https://github.com/PeonPing/openpeon) に変換します。

| IDE | ステータス | セットアップ |
|---|---|---|
| **Claude Code** | 組み込み | `curl \| bash` でインストールすればすべて自動 |
| **Amp** | アダプター | `bash adapters/amp.sh` / `powershell adapters/amp.ps1`（[セットアップ](#amp-セットアップ)） |
| **Gemini CLI** | アダプター | `adapters/gemini.sh`（Windows では `.ps1`）を指すフックを追加（[セットアップ](#gemini-cli-セットアップ)） |
| **GitHub Copilot** | アダプター | `.github/hooks/hooks.json` に `adapters/copilot.sh`（または `.ps1`）を指すフックを追加（[セットアップ](#github-copilot-セットアップ)） |
| **OpenAI Codex** | アダプター | まず peon-ping ランタイムをインストールし、`~/.codex/config.toml` に `adapters/codex.sh`（または `.ps1`）を指す `notify` を追加（[セットアップ](#openai-codex-セットアップ)） |
| **Cursor** | 組み込み | `curl \| bash`、`peon-ping-setup`、または Windows `install.ps1` が自動検出して登録。Windows では **設定 → 機能 → サードパーティスキル** を有効にして、Cursor が `~/.claude/settings.json` を読み込み SessionStart/Stop サウンドを再生するようにしてください。 |
| **OpenCode** | アダプター | `bash adapters/opencode.sh` / `powershell adapters/opencode.ps1`（[セットアップ](#opencode-セットアップ)） |
| **Kilo CLI** | アダプター | `bash adapters/kilo.sh` / `powershell adapters/kilo.ps1`（[セットアップ](#kilo-cli-セットアップ)） |
| **Kiro** | アダプター | `adapters/kiro.sh`（または `.ps1`）を指すフックエントリを追加（[セットアップ](#kiro-セットアップ)） |
| **Windsurf** | アダプター | `adapters/windsurf.sh`（または `.ps1`）を指すフックエントリを追加（[セットアップ](#windsurf-セットアップ)） |
| **Google Antigravity** | アダプター | `bash adapters/antigravity.sh` / `powershell adapters/antigravity.ps1` |
| **Kimi Code** | アダプター | `bash adapters/kimi.sh --install` / `powershell adapters/kimi.ps1 -Install`（[セットアップ](#kimi-code-セットアップ)） |
| **OpenClaw** | アダプター | OpenClaw スキルから `adapters/openclaw.sh <event>`（または `openclaw.ps1`）を呼び出し |
| **Rovo Dev CLI** | アダプター | `~/.rovodev` が存在する場合 `install.sh` が自動登録、または `~/.rovodev/config.yml` にフックを手動追加（[セットアップ](#rovo-dev-cli-セットアップ)） |
| **DeepAgents** | アダプター | `bash adapters/deepagents.sh` / `powershell adapters/deepagents.ps1`（[セットアップ](#deepagents-セットアップ)） |

> **Windows:** すべてのアダプターにネイティブ PowerShell（`.ps1`）バージョンがあります。Windows インストーラー（`install.ps1`）はそれらを `~/.claude/hooks/peon-ping/adapters/` にコピーします。ファイルシステムウォッチャー（Amp、Antigravity、Kimi）は fswatch/inotifywait の代わりに .NET `FileSystemWatcher` を使用 — 追加の依存関係は不要。

### OpenAI Codex セットアップ

Codex サポートはアダプターを使用し、`peon-ping-setup` では自動登録されません。

Codex アダプターは peon-ping ランタイムが `~/.claude/hooks/peon-ping/` に存在することを期待します（Codex のみ使用し Claude Code を使用しない場合でも同様）。

**セットアップ：**

1. まず peon-ping ランタイムをインストール：

   ```bash
   bash "$(brew --prefix peon-ping)"/libexec/install.sh --no-rc
   ```

   または標準インストーラーで：

   ```bash
   curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --no-rc
   ```

2. `~/.codex/config.toml` に以下を追加：

   ```toml
   notify = ["bash", "~/.claude/hooks/peon-ping/adapters/codex.sh"]
   ```

3. Codex を再起動。

Homebrew でインストールした場合、ランタイムファイルは `~/.claude/hooks/peon-ping/` で管理され、Codex アダプターは Codex の notify イベントをその共有ランタイムに転送します。

### Amp セットアップ

[Amp](https://ampcode.com)（Sourcegraph）用のファイルシステムウォッチャーアダプター。Amp は Claude Code のようなイベントフックを公開していないため、このアダプターは Amp のスレッドファイルをディスク上で監視し、エージェントがターンを終了したことを検出します。

**セットアップ：**

1. peon-ping がインストール済みであることを確認（`curl -fsSL https://peonping.com/install | bash`）

2. `fswatch`（macOS）または `inotify-tools`（Linux）をインストール：

   ```bash
   brew install fswatch        # macOS
   sudo apt install inotify-tools  # Linux
   ```

3. ウォッチャーを起動：

   ```bash
   bash ~/.claude/hooks/peon-ping/adapters/amp.sh        # フォアグラウンド
   bash ~/.claude/hooks/peon-ping/adapters/amp.sh &       # バックグラウンド
   ```

**イベントマッピング：**

- 新しいスレッドファイル作成 → 挨拶サウンド（*"Ready to work?"*、*"Yes?"*）
- スレッドファイルの更新停止 + エージェントのターン完了 → 完了サウンド（*"Work, work."*、*"Job's done!"*）

**仕組み：**

アダプターは `~/.local/share/amp/threads/` ディレクトリの JSON ファイル変更を監視します。スレッドファイルの更新が停止し（1秒のアイドルタイムアウト）、最後のメッセージがアシスタントからのテキストコンテンツ（保留中のツールコールではない）の場合、`Stop` イベントを発行します — エージェントが完了し、あなたの入力を待っていることを意味します。

**環境変数：**

| 変数 | デフォルト | 説明 |
|---|---|---|
| `AMP_DATA_DIR` | `~/.local/share/amp` | Amp データディレクトリ |
| `AMP_THREADS_DIR` | `$AMP_DATA_DIR/threads` | 監視するスレッドディレクトリ |
| `AMP_IDLE_SECONDS` | `1` | Stop を発行するまでの変更なし秒数 |
| `AMP_STOP_COOLDOWN` | `10` | スレッドごとの Stop イベント間の最小秒数 |

### GitHub Copilot セットアップ

[GitHub Copilot](https://github.com/features/copilot) 用のシェルアダプター。[CESP v1.0](https://github.com/PeonPing/openpeon) に完全準拠。

**セットアップ：**

1. peon-ping がインストール済みであることを確認（`curl -fsSL https://peonping.com/install | bash`）

2. リポジトリのデフォルトブランチに `.github/hooks/hooks.json` を作成：

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

3. コミットしてデフォルトブランチにマージ。次の Copilot エージェントセッションでフックが有効になります。

**イベントマッピング：**

- `sessionStart` → 挨拶サウンド（*"Ready to work?"*、*"Yes?"*）
- `userPromptSubmitted` → 最初のプロンプト = 挨拶、以降 = スパム検出
- `postToolUse` → 完了サウンド（*"Work, work."*、*"Job's done!"*）
- `errorOccurred` → エラーサウンド（*"I can't do that."*）
- `preToolUse` → スキップ（ノイズが多すぎるため）
- `sessionEnd` → サウンドなし（session.end は未実装）

**機能：**

- **サウンド再生** — `afplay`（macOS）、`pw-play`/`paplay`/`ffplay`（Linux）経由 — シェルフックと同じ優先チェーン
- **CESP イベントマッピング** — GitHub Copilot フックが標準 CESP カテゴリ（`session.start`、`task.complete`、`task.error`、`user.spam`）にマッピング
- **デスクトップ通知** — デフォルトで大型オーバーレイバナー、または標準通知
- **スパム検出** — 10秒以内の3回以上の高速プロンプトを検出し、`user.spam` ボイスラインをトリガー
- **セッション追跡** — Copilot sessionId ごとに独立したセッションマーカー

### OpenCode セットアップ

[OpenCode](https://opencode.ai/) 用のネイティブ TypeScript プラグイン。[CESP v1.0](https://github.com/PeonPing/openpeon) に完全準拠。

**クイックインストール：**

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh | bash
```

インストーラーは `peon-ping.ts` を `~/.config/opencode/plugins/` にコピーし、`~/.config/opencode/peon-ping/config.json` に設定を作成します。パックは共有 CESP パス（`~/.openpeon/packs/`）に保存されます。

**機能：**

- **サウンド再生** — `afplay`（macOS）、`pw-play`/`paplay`/`ffplay`（Linux）経由 — シェルフックと同じ優先チェーン
- **CESP イベントマッピング** — `session.created` / `session.idle` / `session.error` / `permission.asked` / 高速プロンプト検出がすべて標準 CESP カテゴリにマッピング
- **デスクトップ通知** — デフォルトで大型オーバーレイバナー（JXA Cocoa、全画面で表示）、または [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) / `osascript` 経由の標準通知。ターミナルがフォーカスされていない場合のみ発火
- **ターミナルフォーカス検出** — AppleScript でターミナルアプリ（Terminal、iTerm2、Warp、Alacritty、kitty、WezTerm、ghostty、Hyper）が最前面かどうかを確認
- **タブタイトル** — ターミナルタブにタスクステータスを表示（`● project: working...` / `✓ project: done` / `✗ project: error`）
- **パック切り替え** — 設定から `default_pack` を読み込み（レガシー設定では `active_pack` にフォールバック）、実行時にパックの `openpeon.json` マニフェストを読み込み。`path_rules` で作業ディレクトリごとにパックを上書き可能。
- **リピート防止ロジック** — カテゴリごとに同じサウンドを連続再生することを回避
- **スパム検出** — 10秒以内の3回以上の高速プロンプトを検出し、`user.spam` ボイスラインをトリガー

<details>
<summary>🖼️ スクリーンショット: カスタムペオンアイコン付きデスクトップ通知</summary>

![peon-ping OpenCode notifications](https://github.com/user-attachments/assets/e433f9d1-2782-44af-a176-71875f3f532c)

</details>

> **ヒント:** `terminal-notifier`（`brew install terminal-notifier`）をインストールすると、サブタイトルやグループ化に対応したリッチな通知が利用可能。

<details>
<summary>🎨 オプション: 通知用のカスタムペオンアイコン</summary>

デフォルトでは `terminal-notifier` はジェネリックな Terminal アイコンを表示します。付属のスクリプトは macOS 内蔵ツール（`sips` + `iconutil`）を使用してペオンアイコンに置き換えます — 追加依存関係不要。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/setup-icon.sh)
```

または、ローカルインストール（Homebrew / git clone）の場合：

```bash
bash ~/.claude/hooks/peon-ping/adapters/opencode/setup-icon.sh
```

スクリプトはペオンアイコンを自動検出（Homebrew libexec、OpenCode 設定、または Claude フックディレクトリ）し、適切な `.icns` を生成、元の `Terminal.icns` をバックアップして置き換えます。`brew upgrade terminal-notifier` 後に再実行が必要です。

> **将来:** [jamf/Notifier](https://github.com/jamf/Notifier) が Homebrew に公開されたら（[#32](https://github.com/jamf/Notifier/issues/32)）、プラグインはそちらに移行予定 — Notifier には `--rebrand` サポートが組み込まれており、アイコンのハックが不要になります。

</details>

### Kilo CLI セットアップ

[Kilo CLI](https://github.com/kilocode/cli) 用のネイティブ TypeScript プラグイン。[CESP v1.0](https://github.com/PeonPing/openpeon) に完全準拠。Kilo CLI は OpenCode のフォークで同じプラグインシステムを使用 — このインストーラーは OpenCode プラグインをダウンロードして Kilo 用にパッチします。

**クイックインストール：**

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/kilo.sh | bash
```

インストーラーは `peon-ping.ts` を `~/.config/kilo/plugins/` にコピーし、`~/.config/kilo/peon-ping/config.json` に設定を作成します。パックは共有 CESP パス（`~/.openpeon/packs/`）に保存されます。

**機能:** [OpenCode アダプター](#opencode-セットアップ)と同じ — サウンド再生、CESP イベントマッピング、デスクトップ通知、ターミナルフォーカス検出、タブタイトル、パック切り替え、リピート防止ロジック、スパム検出。

### Gemini CLI セットアップ

**Gemini CLI** 用のシェルアダプター。[CESP v1.0](https://github.com/PeonPing/openpeon) に完全準拠。

**セットアップ：**

1. peon-ping がインストール済みであることを確認（`curl -fsSL https://peonping.com/install | bash`）

2. `~/.gemini/settings.json` に以下のフックを追加：

   ```json
    {
      "hooks": {
        "SessionStart": [
          {
            "matcher": "startup",
            "hooks": [
              {
                "name": "peon-start",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh SessionStart"
              }
            ]
          }
        ],
        "AfterAgent": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-after-agent",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh AfterAgent"
              }
            ]
          }
        ],
        "AfterTool": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-after-tool",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh AfterTool"
              }
            ]
          }
        ],
        "Notification": [
          {
            "matcher": "*",
            "hooks": [
              {
                "name": "peon-notification",
                "type": "command",
                "command": "bash ~/.claude/hooks/peon-ping/adapters/gemini.sh Notification"
              }
            ]
          }
        ]
      }
    }
   ```

**イベントマッピング：**

- `SessionStart`（startup）→ 挨拶サウンド（*"Ready to work?"*、*"Yes?"*）
- `AfterAgent` → タスク完了サウンド（*"Work, work."*、*"Job's done!"*）
- `AfterTool` → 成功 = タスク完了サウンド、失敗 = エラーサウンド（*"I can't do that."*）
- `Notification` → システム通知

### Windsurf セットアップ

`~/.codeium/windsurf/hooks.json`（ユーザーレベル）または `.windsurf/hooks.json`（ワークスペースレベル）に追加：

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

### Kiro セットアップ

`~/.kiro/agents/peon-ping.json` を作成：

```json
{
  "name": "peon-ping",
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

`preToolUse`/`postToolUse` は意図的に除外されています — ツールコールのたびに発火するため非常にうるさくなります。

### Rovo Dev CLI セットアップ

[Rovo Dev CLI](https://developer.atlassian.com/cloud/rovo/)（Atlassian）用のシェルアダプター。[CESP v1.0](https://github.com/PeonPing/openpeon) に完全準拠。

**自動セットアップ：**

`install.sh` または `peon-ping-setup` 実行時に `~/.rovodev/config.yml` が存在する場合、イベントフックが自動登録されます。

**手動セットアップ：**

1. peon-ping がインストール済みであることを確認（`curl -fsSL https://peonping.com/install | bash`）

2. `~/.rovodev/config.yml` に追加：

   ```yaml
   eventHooks:
     events:
       - name: on_complete
         commands:
           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_complete
       - name: on_error
         commands:
           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_error
       - name: on_tool_permission
         commands:
           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_tool_permission
   ```

3. Rovo Dev CLI を再起動してフックを有効化。

**イベントマッピング：**

- `on_complete` → 完了サウンド（*"Work, work."*、*"Job's done!"*）
- `on_error` → エラーサウンド（*"I can't do that."*、*"Son of a bitch!"*）
- `on_tool_permission` → 許可プロンプトサウンド（*"Something need doing?"*、*"Hmm?"*）

**機能：**

- **サウンド再生** — `afplay`（macOS）、`pw-play`/`paplay`/`ffplay`（Linux）経由 — シェルフックと同じ優先チェーン
- **CESP イベントマッピング** — Rovo Dev イベントが標準 CESP カテゴリ（`task.complete`、`task.error`、`input.required`）にマッピング
- **デスクトップ通知** — デフォルトで大型オーバーレイバナー、または標準通知
- **デバウンス** — 高速完了による重複サウンドを抑制

### Kimi Code セットアップ

[Kimi Code CLI](https://github.com/MoonshotAI/kimi-cli)（MoonshotAI）用のファイルシステムウォッチャーアダプター。Kimi Code は Wire Mode イベントを `~/.kimi/sessions/` に書き込み、このアダプターはバックグラウンドデーモンとしてファイルを監視し CESP フォーマットに変換します。

```bash
# インストール（バックグラウンドデーモンを起動）
bash ~/.claude/hooks/peon-ping/adapters/kimi.sh --install

# ステータス確認 / 停止
bash ~/.claude/hooks/peon-ping/adapters/kimi.sh --status
bash ~/.claude/hooks/peon-ping/adapters/kimi.sh --uninstall
```

macOS では `fswatch`（`brew install fswatch`）、Linux では `inotifywait`（`apt install inotify-tools`）が必要。`curl | bash` インストーラーは Kimi Code を自動検出してデーモンを起動します。

**イベントマッピング：**

- 新しいセッション → 挨拶サウンド（*"Ready to work?"*、*"Yes?"*）
- エージェントのターン完了 → 完了サウンド（*"Work, work."*、*"Job's done!"*）
- コンテキスト圧縮 → トークン制限サウンド
- サブエージェント起動 → サブエージェント追跡

## リモート開発（SSH / Devcontainers / Codespaces）

リモートサーバーやコンテナ内でコーディング中？peon-ping は SSH セッション、devcontainers、Codespaces を自動検出し、ローカルマシンで実行される軽量リレーを通じてオーディオと通知をルーティングします。

### SSH セットアップ

1. **ローカルマシンで**リレーを起動：
   ```bash
   peon relay --daemon
   ```

2. **ポートフォワーディング付きで SSH**：
   ```bash
   ssh -R 19998:localhost:19998 your-server
   ```

3. **リモートに peon-ping をインストール** — SSH セッションを自動検出し、転送ポートを通じてオーディオリクエストをローカルリレーに送信します。

以上です。サウンドはリモートサーバーではなくあなたのラップトップで再生されます。

オプションの SSH ルーティングモード：

```bash
peon ssh-audio relay   # デフォルト、常にリレーを使用
peon ssh-audio auto    # リレーを試み、SSH ホストでのローカル再生にフォールバック
peon ssh-audio local   # 常に SSH ホストで再生
```

### Devcontainers / Codespaces

ポートフォワーディング不要 — peon-ping は `REMOTE_CONTAINERS` と `CODESPACES` 環境変数を自動検出し、`host.docker.internal:19998` にオーディオをルーティングします。ホストマシンで `peon relay --daemon` を実行するだけです。

### リレーコマンド

```bash
peon relay                # フォアグラウンドでリレー開始
peon relay --daemon       # バックグラウンドで開始
peon relay --stop         # バックグラウンドリレーを停止
peon relay --status       # リレーの動作状況を確認
peon relay --port=12345   # カスタムポート（デフォルト: 19998）
peon relay --bind=0.0.0.0 # すべてのインターフェースでリッスン（セキュリティ低下）
```

環境変数: `PEON_RELAY_PORT`、`PEON_RELAY_HOST`、`PEON_RELAY_BIND`。

peon-ping が SSH またはコンテナセッションを検出してもリレーに到達できない場合、`SessionStart` 時にセットアップ手順が表示されます。

### カテゴリベース API（軽量リモートフック用）

リレーはサーバーサイドでサウンド選択を処理するカテゴリベースのエンドポイントをサポートしています。これは peon-ping がインストールされていないリモートマシンに便利です — リモートフックはカテゴリ名を送信するだけで、リレーがアクティブパックからランダムなサウンドを選択します。

**エンドポイント：**

| エンドポイント | 説明 |
|---|---|
| `GET /health` | ヘルスチェック（"OK" を返す） |
| `GET /play?file=<path>` | 特定のサウンドファイルを再生（レガシー） |
| `GET /play?category=<cat>` | カテゴリからランダムサウンドを再生（推奨） |
| `POST /notify` | デスクトップ通知を送信 |

**リモートフックの例（`scripts/remote-hook.sh`）：**

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

リモートマシンにコピーし `~/.claude/settings.json` に登録：

```json
{
  "hooks": {
    "SessionStart": [{"command": "bash /path/to/remote-hook.sh"}],
    "Stop": [{"command": "bash /path/to/remote-hook.sh"}],
    "PermissionRequest": [{"command": "bash /path/to/remote-hook.sh"}]
  }
}
```

リレーはローカルマシンの `config.json` からアクティブパックと音量を読み取り、パックのマニフェストを読み込んで、リピートを避けながらランダムなサウンドを選択します。

## モバイル通知

タスク完了時や注意が必要な時にスマートフォンでプッシュ通知を受信 — デスクから離れている時に便利です。

### クイックスタート（ntfy.sh — 無料、アカウント不要）

1. スマートフォンに [ntfy アプリ](https://ntfy.sh) をインストール
2. アプリでユニークなトピックを購読（例: `my-peon-notifications`）
3. 実行：
   ```bash
   peon mobile ntfy my-peon-notifications
   ```

[Pushover](https://pushover.net) と [Telegram](https://core.telegram.org/bots) にも対応：

```bash
peon mobile pushover <user_key> <app_token>
peon mobile telegram <bot_token> <chat_id>
```

### モバイルコマンド

```bash
peon mobile on            # モバイル通知を有効化
peon mobile off           # モバイル通知を無効化
peon mobile status        # 現在の設定を表示
peon mobile test          # テスト通知を送信
```

モバイル通知はウィンドウフォーカスに関係なくすべてのイベントで発火します — デスクトップ通知やサウンドとは独立しています。

## サウンドパック

Warcraft、StarCraft、Red Alert、Portal、Zelda、Dota 2、Helldivers 2、Elder Scrolls など、165以上のパックがあります。デフォルトインストールには5つの厳選パックが含まれます：

| パック | キャラクター | サウンド |
|---|---|---|
| `peon`（デフォルト） | オークペオン（Warcraft III） | "Ready to work?", "Work, work.", "Okie dokie." |
| `peasant` | ヒューマンペザント（Warcraft III） | "Yes, milord?", "Job's done!", "Ready, sir." |
| `sc_kerrigan` | サラ・ケリガン（StarCraft） | "I gotcha", "What now?", "Easily amused, huh?" |
| `sc_battlecruiser` | バトルクルーザー（StarCraft） | "Battlecruiser operational", "Make it happen", "Engage" |
| `glados` | GLaDOS（Portal） | "Oh, it's you.", "You monster.", "Your entire team is dead." |

**[すべてのパックをオーディオプレビュー付きで閲覧 &rarr; openpeon.com/packs](https://openpeon.com/packs)**

`--all` ですべてインストール、またはいつでもパックを切り替え：

```bash
peon packs use glados             # 特定パックに切り替え
peon packs use --install glados   # インストール（または更新）して一度に切り替え
peon packs next                   # 次のパックに切り替え
peon packs list                   # インストール済みパック一覧
peon packs list --registry        # 利用可能な全パックを閲覧
peon packs install glados,murloc  # 特定パックをインストール
peon packs install --all          # レジストリのすべてのパックをインストール
```

自分のパックを追加したい場合は、[openpeon.com/create の完全ガイド](https://openpeon.com/create)または [CONTRIBUTING.md](CONTRIBUTING.md) を参照。

## デバッグ

サウンドが再生されない、または通知が表示されない場合、構造化デバッグログでフック呼び出し中に何が起こったかを正確に追跡できます。

### デバッグログの有効化

```bash
peon debug on             # 有効化 — ログは ~/.claude/hooks/peon-ping/logs/ に書き込まれます
peon debug off            # 無効化
peon debug status         # 状態、ログディレクトリ、ファイル数、合計サイズを表示
```

環境変数 `PEON_DEBUG=1` を設定することで、設定を変更せずに単一の呼び出しでデバッグログを有効にすることもできます。

### ログの閲覧

```bash
peon logs                 # 今日のログの最後の50行
peon logs --last 100      # すべてのログファイルの最後の100行
peon logs --session <ID>  # 今日のログをセッションIDでフィルタ
peon logs --session <ID> --all  # すべてのログファイルからセッションIDを検索
peon logs --clear         # すべてのログファイルを削除（確認あり）
```

### ログ形式

各ログ行は構造化された key=value レコードです：

```
2026-03-26T14:32:01.042 [config] inv=a3f1 loaded=/path/to/config.json volume=0.5 pack=peon enabled=True
2026-03-26T14:32:01.045 [event] inv=a3f1 hook_event=Stop cesp=task.complete session=abc123
2026-03-26T14:32:01.048 [sound] inv=a3f1 file=work-work.wav label="Work, work." category=task.complete
2026-03-26T14:32:01.120 [play] inv=a3f1 player=afplay file=work-work.wav
2026-03-26T14:32:01.125 [notify] inv=a3f1 title="peon: done" body="Work, work."
```

- **inv** -- 単一のフック呼び出しの全フェーズをリンクする一意の4文字呼び出しID
- **フェーズ**：`[config]`、`[event]`、`[sound]`、`[play]`、`[notify]` -- それぞれフックパイプラインの1段階を表す
- スペースや特殊文字を含む値はクォートされます

### よくある障害の例

| 症状 | ログで確認すべき内容 |
|---|---|
| サウンドが再生されない | `[event]` 行に `exit=early` が表示される（カテゴリ無効、一時停止中、またはデバウンス済み） |
| パックが間違っている | `[config]` 行に予期しない `pack=` 値が表示される -- path_rules またはローテーションを確認 |
| サウンドファイルが見つからない | `[sound]` 行に `error=` とファイルパスが表示される |
| 通知が表示されない | `[notify]` 行がない -- 設定の `desktop_notifications` を確認 |

### 設定キー

| キー | デフォルト | 説明 |
|---|---|---|
| `debug` | `false` | 構造化デバッグログを有効にする |
| `debug_retention_days` | `7` | N日より古いログを自動削除 |

ログは `~/.claude/hooks/peon-ping/logs/peon-ping-YYYY-MM-DD.log` に保存されます（1日1ファイル）。古いログは新しい日のログが作成される際に `debug_retention_days` に基づいて自動的に削除されます。

## アンインストール

**macOS/Linux：**

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/uninstall.sh        # グローバル
bash .claude/hooks/peon-ping/uninstall.sh           # プロジェクトローカル
```

**Windows (PowerShell)：**

```powershell
# 標準アンインストール（サウンド削除前に確認あり）
powershell -File "$env:USERPROFILE\.claude\hooks\peon-ping\uninstall.ps1"

# サウンドパックを保持（その他すべてを削除）
powershell -File "$env:USERPROFILE\.claude\hooks\peon-ping\uninstall.ps1" -KeepSounds
```

## 必要環境

- **macOS** — `afplay`（内蔵）、通知用に JXA Cocoa オーバーレイまたは AppleScript
- **Linux** — 以下のいずれか: `pw-play`、`paplay`、`ffplay`、`mpv`、`play`（SoX）、または `aplay`; 通知用に `notify-send`
- **Windows** — ネイティブ PowerShell + `MediaPlayer` + WinForms（WSL 不要）、または WSL2
- **MSYS2 / Git Bash** — `python3`、`cygpath`（内蔵）; オーディオは `ffplay`/`mpv`/`play` または PowerShell フォールバック
- **全プラットフォーム** — `python3`（ネイティブ Windows では不要）
- **SSH/リモート** — リモートホストに `curl`
- **IDE** — フックサポート付き Claude Code、Amp、または[アダプター](#マルチide対応)経由の任意のサポート IDE

## 仕組み

`peon.sh` は `SessionStart`、`SessionEnd`、`SubagentStart`、`Stop`、`Notification`、`PermissionRequest`、`PostToolUseFailure`、`PreCompact` イベントに登録された Claude Code フックです。各イベントで：

1. **イベントマッピング** — 埋め込み Python ブロックがフックイベントを [CESP](https://github.com/PeonPing/openpeon) サウンドカテゴリ（`session.start`、`task.complete`、`input.required` など）にマッピング
2. **サウンド選択** — アクティブパックのマニフェストからリピートを避けながらランダムなボイスラインを選択
3. **オーディオ再生** — `afplay`（macOS）、PowerShell `MediaPlayer`（WSL2/MSYS2 フォールバック）、または `pw-play`/`paplay`/`ffplay`/`mpv`/`aplay`（Linux/MSYS2）で非同期にサウンドを再生
4. **通知** — ターミナルタブタイトルを更新し、ターミナルがフォーカスされていない場合はデスクトップ通知を送信
5. **リモートルーティング** — SSH セッション、devcontainers、Codespaces では、オーディオと通知リクエストがローカルマシンの[リレーサーバー](#リモート開発ssh--devcontainers--codespaces)に HTTP 経由で転送

サウンドパックはインストール時に [OpenPeon レジストリ](https://github.com/PeonPing/registry) からダウンロードされます。公式パックは [PeonPing/og-packs](https://github.com/PeonPing/og-packs) でホストされています。サウンドファイルは各パブリッシャー（Blizzard、Valve、EA など）の所有物であり、個人的な通知目的のフェアユースに基づいて配布されています。

## リンク

- [@peonping on X](https://x.com/peonping) — 更新とお知らせ
- [peonping.com](https://peonping.com/) — ランディングページ
- [openpeon.com](https://openpeon.com/) — CESP 仕様、パックブラウザ、[インテグレーションガイド](https://openpeon.com/integrate)、作成ガイド
- [OpenPeon レジストリ](https://github.com/PeonPing/registry) — パックレジストリ（GitHub Pages）
- [og-packs](https://github.com/PeonPing/og-packs) — 公式サウンドパック
- [peon-pet](https://github.com/PeonPing/peon-pet) — macOS デスクトップペット（オークスプライト、フックイベントに反応）
- [ライセンス (MIT)](LICENSE)

## プロジェクトを支援

- Venmo: [@garysheng](https://venmo.com/garysheng)
- コミュニティトークン（DYOR / お楽しみ用）: Base 上に $PEON トークンが作成されました — トランザクション手数料が開発資金に充てられます。[`0xf4ba744229afb64e2571eef89aacec2f524e8ba3`](https://dexscreener.com/base/0xf4bA744229aFB64E2571eef89AaceC2F524e8bA3)
