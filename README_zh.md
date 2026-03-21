# peon-ping
<div align="center">

[English](README.md) | [한국어](README_ko.md) | **中文**

![macOS](https://img.shields.io/badge/macOS-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue) ![Linux](https://img.shields.io/badge/Linux-blue) ![Windows](https://img.shields.io/badge/Windows-blue) ![MSYS2](https://img.shields.io/badge/MSYS2-blue) ![SSH](https://img.shields.io/badge/SSH-blue)
![License](https://img.shields.io/badge/license-MIT-green)

![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01) ![Amp](https://img.shields.io/badge/Amp-adapter-ffab01) ![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-adapter-ffab01) ![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-adapter-ffab01) ![Codex](https://img.shields.io/badge/Codex-adapter-ffab01) ![Cursor](https://img.shields.io/badge/Cursor-adapter-ffab01) ![OpenCode](https://img.shields.io/badge/OpenCode-adapter-ffab01) ![Kilo CLI](https://img.shields.io/badge/Kilo_CLI-adapter-ffab01) ![Kiro](https://img.shields.io/badge/Kiro-adapter-ffab01) ![Kimi Code](https://img.shields.io/badge/Kimi_Code-adapter-ffab01) ![Windsurf](https://img.shields.io/badge/Windsurf-adapter-ffab01) ![Antigravity](https://img.shields.io/badge/Antigravity-adapter-ffab01) ![OpenClaw](https://img.shields.io/badge/OpenClaw-adapter-ffab01) ![DeepAgents](https://img.shields.io/badge/DeepAgents-adapter-ffab01)

**当你的 AI 编程助手需要关注时，播放游戏角色语音 + 显示视觉覆盖通知 — 或通过 MCP 让 AI 自行选择音效。**

AI 编程助手完成任务或需要权限时不会通知你。你切换标签页、失去焦点，然后浪费 15 分钟重新进入状态。peon-ping 通过魔兽争霸、星际争霸、传送门、塞尔达等游戏的角色语音和醒目的屏幕横幅来解决这个问题 — 支持 **Claude Code**、**Amp**、**Gemini CLI**、**GitHub Copilot**、**Codex**、**Cursor**、**OpenCode**、**Kilo CLI**、**Kiro**、**Kimi Code**、**Windsurf**、**Google Antigravity**、**OpenClaw**、**DeepAgents** 及任何 MCP 客户端.

**查看演示** &rarr; [peonping.com](https://peonping.com/)

</div>

---

- [安装](#安装)
- [你会听到什么](#你会听到什么)
- [快捷控制](#快捷控制)
- [配置](#配置)
- [Peon 教练](#peon-教练)
- [MCP 服务器](#mcp-服务器)
- [多 IDE 支持](#多-ide-支持)
- [远程开发](#远程开发ssh--devcontainers--codespaces)
- [手机通知](#手机通知)
- [语音包](#语音包)
- [卸载](#卸载)
- [系统要求](#系统要求)
- [工作原理](#工作原理)
- [链接](#链接)

---

## 安装

### 方式一：Homebrew（推荐）

```bash
brew install PeonPing/tap/peon-ping
```

然后运行 `peon-ping-setup` 注册钩子并下载语音包。支持 macOS 和 Linux。

### 方式二：安装脚本（macOS、Linux、WSL2）

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash
```

⚠️ 在 WSL2 中，若要使用 **WAV** 以外格式的语音包，必须安装 **ffmpeg**。在 Debian 发行版中可使用以下命令安装：

```sh
sudo apt update; sudo apt install -y ffmpeg
```

### 方式三：Windows 安装

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.ps1" -UseBasicParsing | Invoke-Expression
```

默认安装 5 个精选语音包（魔兽、星际、传送门）。重新运行可更新，同时保留配置和状态。你也可以在 **[peonping.com 交互式选择语音包](https://peonping.com/#picker)** 获取自定义安装命令。

实用安装参数：

- `--all` — 安装所有可用语音包
- `--packs=peon,sc_kerrigan,...` — 仅安装指定语音包
- `--local` — 将语音包、配置和钩子安装到当前项目的 `./.claude/` 目录
- `--global` — 显式全局安装（与默认相同）
- `--init-local-config` — 仅创建 `./.claude/hooks/peon-ping/config.json`

`--local` 不会修改你的 shell rc 文件（不注入全局 `peon` 别名/补全）。钩子注册到项目级 `./.claude/settings.json` 并使用绝对路径，因此在项目内的任何工作目录下都能工作。

示例：

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --all
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --packs=peon,sc_kerrigan
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --local
```

如果已存在全局安装，你又安装了本地版本（或反之），安装程序会提示你移除现有的以避免冲突。

### 方式四：克隆后检查

```bash
git clone https://github.com/PeonPing/peon-ping.git
cd peon-ping
./install.sh
```

## 你会听到什么

| 事件 | CESP 分类 | 示例 |
|---|---|---|
| 会话开始 | `session.start` | *"Ready to work?"*, *"Yes?"*, *"What you want?"* |
| 任务完成 | `task.complete` | *"Work, work."*, *"I can do that."*, *"Okie dokie."* |
| 需要权限 | `input.required` | *"Something need doing?"*, *"Hmm?"*, *"What you want?"* |
| 速率或 token 限制 | `resource.limit` | *"Zug zug."*（取决于语音包）|
| 快速提示（10秒内3次以上）| `user.spam` | *"Me busy, leave me alone!"* |

此外，还会在每个屏幕上显示**大型覆盖横幅**（macOS/WSL/MSYS2）和终端标签页标题（`● 项目: 完成`）——即使你在其他应用中，也能立即知道任务完成。

peon-ping 实现了 [编码事件语音包规范（CESP）](https://github.com/PeonPing/openpeon) — 这是一个任何代理式 IDE 都可以采用的编码事件声音开放标准。

## 快捷控制

开会或结对编程时需要静音？两种方式：

| 方式 | 命令 | 适用场景 |
|---|---|---|
| **斜杠命令** | `/peon-ping-toggle` | 在 Claude Code 中工作时 |
| **CLI** | `peon toggle` | 从任意终端标签页 |

其他 CLI 命令：

```bash
peon pause                # 静音
peon mute                 # 'pause' 的别名
peon volume               # 查看当前音量
peon volume 0.7           # 设置音量（0.0–1.0）
peon rotation             # 查看当前轮换模式
peon rotation random      # 设置轮换模式（random|round-robin|session_override）
peon resume               # 取消静音
peon unmute               # 'resume' 的别名
peon status               # 查看暂停或活动状态
peon packs list           # 列出已安装的语音包
peon packs list --registry # 浏览注册表中所有可用语音包
peon packs community      # 按信任等级列出所有注册表语音包（Windows）
peon packs search <query> # 按名称搜索注册表语音包（Windows）
peon packs install <p1,p2> # 从注册表安装语音包
peon packs install --all  # 从注册表安装所有语音包
peon packs install-local <path> # 从本地目录安装语音包
peon packs use <name>     # 切换到指定语音包（Windows 上自动从注册表安装）
peon packs next           # 切换到下一个语音包
peon packs remove <p1,p2> # 移除指定语音包
peon packs bind <name>    # 将语音包绑定到当前目录
peon packs bind --pattern <path> # 将语音包绑定到目录模式，例如 "*/services"
peon packs unbind         # 移除当前目录的绑定
peon packs bindings       # 列出所有已分配的绑定
peon notifications on     # 启用桌面通知
peon notifications off    # 禁用桌面通知
peon preview              # 播放 session.start 的所有声音
peon preview <category>   # 播放指定分类的所有声音
peon preview --list       # 列出活动语音包的所有分类
peon mobile ntfy <topic>  # 设置手机通知（免费）
peon mobile off           # 禁用手机通知
peon mobile test          # 发送测试通知
peon relay --daemon       # 启动音频中继（用于 SSH/devcontainer）
peon relay --stop         # 停止后台中继
```

`peon preview` 支持的 CESP 分类：`session.start`、`task.acknowledge`、`task.complete`、`task.error`、`input.required`、`resource.limit`、`user.spam`。（扩展分类 `session.end` 和 `task.progress` 已在 CESP 规范中定义，语音包可以实现，但目前未由内置钩子事件触发。）

支持 Tab 补全 — 输入 `peon packs use <TAB>` 查看可用语音包名称。

暂停会立即静音声音和桌面通知。暂停状态会跨会话保持，直到你恢复。暂停时标签页标题仍会更新。

## 配置

peon-ping 在 Claude Code 中安装以下斜杠命令：

- `/peon-ping-toggle` — 静音/取消静音
- `/peon-ping-config` — 更改任意设置（音量、语音包、分类等）
- `/peon-ping-rename <名称>` — 为当前会话设置自定义名称，显示在通知标题和终端标签标题中（零 token 消耗，由钩子拦截处理）；不带参数则重置为自动检测

你也可以直接让 Claude 帮你修改设置 — 例如"启用轮换语音包"、"将音量设为 0.3"或"添加 glados 到我的语音包轮换"。无需手动编辑配置文件。

配置位置取决于安装模式：

- 全局安装：`$CLAUDE_CONFIG_DIR/hooks/peon-ping/config.json`（默认 `~/.claude/hooks/peon-ping/config.json`）
- 本地安装：`./.claude/hooks/peon-ping/config.json`

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

### 独立控制

peon-ping 有三个独立的控制开关，可以混合使用：

| 配置键 | 控制项 | 影响声音 | 影响桌面弹窗 | 影响手机推送 |
|--------|--------|----------|--------------|--------------|
| `enabled` | 主音频开关 | ✅ 是 | ❌ 否 | ❌ 否 |
| `desktop_notifications` | 桌面弹窗横幅 | ❌ 否 | ✅ 是 | ❌ 否 |
| `mobile_notify.enabled` | 手机推送通知 | ❌ 否 | ❌ 否 | ✅ 是 |

这意味着您可以：
- 保留声音但禁用桌面弹窗：`peon notifications off`
- 保留桌面弹窗但禁用声音：`peon pause`
- 启用手机推送但不显示桌面弹窗：设置 `desktop_notifications: false` 和 `mobile_notify.enabled: true`

- **volume**：0.0–1.0（适合办公室使用的音量）
- **desktop_notifications**：`true`/`false` — 独立于声音控制桌面通知弹窗（默认：`true`）。禁用时，声音继续播放但视觉弹窗被抑制。手机通知不受影响。
- **notification_style**：`"overlay"` 或 `"standard"` — 控制桌面通知显示方式（默认：`"overlay"`）
  - **overlay**：大型醒目横幅 — macOS 上使用 JXA Cocoa 覆盖，WSL/MSYS2 上使用 Windows Forms 弹窗。点击覆盖层可聚焦终端（支持 Ghostty、Warp、iTerm2、Zed、Terminal.app）。在 iTerm2 上，点击可聚焦到正确的标签页/窗格/窗口。
  - **standard**：系统通知 — macOS 上使用 [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) / `osascript`，WSL/MSYS2 上使用 Windows toast。安装 `terminal-notifier`（`brew install terminal-notifier`）后，点击通知可自动聚焦终端
- **overlay_theme**：`"jarvis"`、`"glass"`、`"sakura"`，或留空使用默认覆盖层 — 仅 macOS（默认：无）
  - **jarvis**：圆形 HUD，带旋转弧线、刻度和进度环
  - **glass**：毛玻璃风格面板，带强调色条、进度线和时间戳
  - **sakura**：禅意花园，带盆景树和动态樱花花瓣
  - **wsl_toast**：`true`/`false` — 在 WSL 上使用原生 Windows toast 通知代替 Windows Forms 弹窗。Toast 不会抢占焦点并出现在操作中心。（默认：`true`）
- **categories**：单独开关 CESP 声音分类（例如 `"session.start": false` 禁用问候声音）
- **annoyed_threshold / annoyed_window_seconds**：在 N 秒内多少次提示触发 `user.spam` 彩蛋
- **silent_window_seconds**：对于短于 N 秒的任务，抑制 `task.complete` 声音和通知。（例如 `10` 表示只播放超过 10 秒的任务声音）
- **session_start_cooldown_seconds**（数字，默认：`30`）：当多个工作区同时启动时（例如用 OpenCode 或 Cursor 打开多个文件夹），对问候声音进行去重。只有第一个会话启动会播放问候声；在此窗口期内的后续会话保持静默。设为 `0` 可禁用去重，始终播放问候声。
- **suppress_subagent_complete**（布尔值，默认：`false`）：当子 Agent 会话结束时，抑制 `task.complete` 声音和通知。当 Claude Code 的 Task 工具并行派发多个子 Agent 时，每个子 Agent 完成都会触发一次提示音——将此选项设为 `true`，则只播放父会话的完成提示音。
- **default_pack**：当没有更具体的规则时使用的备选语音包（默认：`"peon"`）。取代旧的 `active_pack` 键——现有配置在 `peon update` 时自动迁移。
- **path_rules**：`{ "pattern": "...", "pack": "..." }` 对象数组。根据工作目录使用通配符匹配（`*`、`?`）为会话分配语音包。第一个匹配规则生效，优先级高于 `pack_rotation` 和 `default_pack`，但低于 `session_override` 分配。
- **pack_rotation**：语音包名称数组（例如 `["peon", "sc_kerrigan", "peasant"]`）。用于 `pack_rotation_mode` 为 `random` 或 `round-robin` 时。留空 `[]` 则仅使用 `default_pack`（或 `path_rules`）。
- **pack_rotation_mode**：`"random"`（默认）、`"round-robin"` 或 `"session_override"`。使用 `random`/`round-robin` 时，每个会话从 `pack_rotation` 中选择一个语音包。使用 `session_override` 时，`/peon-ping-use <pack>` 命令为每个会话分配语音包。无效或缺失的语音包会按层级回退。（`"agentskill"` 作为 `"session_override"` 的旧别名仍被接受。）
- **session_ttl_days**（数字，默认：7）：使超过 N 天的陈旧每会话语音包分配过期。防止使用 `session_override` 模式时 `.state.json` 无限增长。
- **headphones_only**（布尔值，默认：`false`）：仅在检测到耳机或外部音频设备时播放声音。启用后，如果内置扬声器是活动输出，声音将被静音 — 适用于开放式办公室。使用 `peon status` 查看状态。支持 macOS（通过 `system_profiler`）和 Linux（通过 PipeWire `wpctl` 或 PulseAudio `pactl`）。
- **suppress_sound_when_tab_focused**（布尔值，默认：`false`）：当生成钩子事件的终端标签页处于当前活动/聚焦状态时，跳过声音播放。声音仍会在后台标签页中播放，提醒您其他地方发生了事件。桌面和移动通知不受影响。适用于只想在未查看的标签页中听到音频提示的用户。仅支持 macOS（使用 `osascript` 检查最前端应用和 iTerm2 标签页焦点）。
- **notification_position**（字符串，默认：`"top-center"`）：覆盖通知在屏幕上的显示位置。选项：`"top-left"`、`"top-center"`、`"top-right"`、`"bottom-left"`、`"bottom-center"`、`"bottom-right"`。
- **notification_dismiss_seconds**（数字，默认：`4`）：覆盖通知在 N 秒后自动消失。设为 `0` 则通知持续显示，需点击关闭。
- **`CLAUDE_SESSION_NAME` 环境变量**：在启动 `claude` 前设置，为会话指定自定义名称。同时显示在桌面通知标题和终端标签标题中，优先级高于所有配置项。示例：`CLAUDE_SESSION_NAME="Auth Refactor" claude` 或先 `export CLAUDE_SESSION_NAME="功能: Auth"` 再 `claude`。
- **notification_title_override**（字符串，默认：`""`）：覆盖通知标题中显示的项目名称。为空时自动检测：`/peon-ping-rename` > `CLAUDE_SESSION_NAME` > `.peon-label` > `notification_title_script` > `project_name_map` > git 仓库名 > 文件夹名。
- **notification_title_script**（字符串，默认：`""`）：在事件触发时运行的 Shell 命令，用于动态计算项目名称。可用环境变量：`PEON_SESSION_ID`、`PEON_CWD`、`PEON_HOOK_EVENT`、`PEON_SESSION_NAME`。使用标准输出（去除首尾空白，最多 50 字符）；非零退出码则继续查找下一层级。示例：`"basename $PEON_CWD"`。
- **project_name_map**（对象，默认：`{}`）：将目录路径映射为通知中的自定义项目标签。键为路径模式，值为显示名称。
- **notification_templates**（对象，默认：`{}`）：自定义通知事件的消息格式。键为事件类型（`stop`、`permission`、`error`、`idle`、`question`），值为支持变量替换的模板字符串。可用变量：`{project}`、`{summary}`、`{tool_name}`、`{status}`、`{event}`。

### 语音包选择层级

peon-ping 通过 5 层层级结构确定使用哪个语音包。第一个产生有效已安装语音包的层级生效：

| 优先级 | 层级 | 来源 | 设置方式 |
|--------|------|------|----------|
| 1（最高） | **session_override** | 每会话分配 | `/peon-ping-use <pack>` 技能或 MCP |
| 2 | **path_rules** | 工作目录的通配符匹配 | `peon packs bind` 或配置中的 `path_rules` |
| 3 | **pack_rotation** | 从列表中随机或轮换 | 配置中的 `pack_rotation` 数组 + `pack_rotation_mode` |
| 4 | **default_pack** | 静态回退 | `peon packs use <name>` 或配置中的 `default_pack` |
| 5（最低） | **硬编码** | 内置默认 | `"peon"` |

如果某层级引用的语音包未安装，则回退到下一层级。

### 按项目分配语音包（path_rules）

根据目录路径为不同项目分配不同的语音包。可以使用 CLI 或直接编辑 `config.json`。

**CLI（推荐）：**

```bash
peon packs bind glados                     # 将 glados 绑定到当前目录
peon packs bind sc_kerrigan --pattern "*/services/*"  # 绑定到通配符模式
peon packs bind duke_nukem --install       # 绑定并在需要时从注册表安装
peon packs unbind                          # 移除当前目录的绑定
peon packs unbind --pattern "*/services/*" # 移除特定模式的绑定
peon packs bindings                        # 列出所有绑定
```

**手动配置：**

```json
"path_rules": [
  { "pattern": "*/work/client-a/*", "pack": "glados" },
  { "pattern": "*/personal/*",      "pack": "peon" },
  { "pattern": "*/services/*",      "pack": "sc_kerrigan" }
]
```

规则使用通配符匹配（`*`、`?`）。第一个匹配规则生效。路径规则优先级高于 `pack_rotation` 和 `default_pack`，但低于 `session_override` 分配。

## 常见用例

### 保留声音但禁用弹窗

想要语音反馈但不想要视觉干扰？

```bash
peon notifications off
```

这会保持所有声音类别的播放，同时禁用桌面通知横幅。手机通知（如果已配置）继续工作。

您也可以使用别名：

```bash
peon popups off
```

### 静音模式但保留通知

想要视觉提醒但不要音频？

```bash
peon pause  # 或在配置中设置 "enabled": false
```

当 `desktop_notifications: true` 时，您将收到弹窗但没有声音。

### 完全静音

禁用所有功能：

```bash
peon pause
peon notifications off
peon mobile off
```

## Peon 教练

你的苦工也是你的私人教练。内置帕维尔风格（Pavel-style）每日锻炼模式 — 那个告诉你"work work"的兽人现在会叫你趴下做二十个俯卧撑。

### 快速开始

```bash
peon trainer on              # 启用教练模式
peon trainer goal 200        # 设置每日目标（默认：300/300）
# ... 写一段时间代码，苦工每约 20 分钟唠叨你一次 ...
peon trainer log 25 pushups  # 记录你的运动次数
peon trainer log 30 squats
peon trainer status          # 查看进度
```

### 工作原理

教练提醒基于你的编程会话运行。当你开始新会话时，苦工会立即鼓励你在写任何代码之前先做俯卧撑。然后在活跃编程期间每约 20 分钟，你会听到苦工喊你做更多次。无需后台守护进程。使用 `peon trainer log` 记录你的次数，进度在午夜自动重置。

### 命令

| 命令 | 描述 |
|---------|-------------|
| `peon trainer on` | 启用教练模式 |
| `peon trainer off` | 禁用教练模式 |
| `peon trainer status` | 显示今日进度 |
| `peon trainer log <n> <exercise>` | 记录次数（例如 `log 25 pushups`） |
| `peon trainer goal <n>` | 设置所有运动的目标 |
| `peon trainer goal <exercise> <n>` | 设置单项运动的目标 |

### Claude Code 技能

在 Claude Code 中，你可以不用离开对话就记录次数：

```
/peon-ping-log 25 pushups
/peon-ping-log 30 squats
```

### 自定义语音

将你自己的音频文件放入 `~/.claude/hooks/peon-ping/trainer/sounds/`：

```
trainer/sounds/session_start/  # 会话问候（"Pushups first, code second! Zug zug!"）
trainer/sounds/remind/         # 提醒语音（"Something need doing? YES. PUSHUPS."）
trainer/sounds/log/            # 确认语音（"Work work! Muscles getting bigger maybe!"）
trainer/sounds/complete/       # 庆祝语音（"Zug zug! Human finish all reps!"）
trainer/sounds/slacking/       # 失望语音（"Peon very disappointed."）
```

更新 `trainer/manifest.json` 来注册你的声音文件。

## MCP 服务器

peon-ping 包含一个 [MCP（模型上下文协议）](https://modelcontextprotocol.io/)服务器，任何兼容 MCP 的 AI 代理都可以通过工具调用直接播放声音，无需钩子。

核心区别：**由代理选择声音**。代理不再在每个事件上自动播放固定声音，而是直接调用 `play_sound` 指定想要的声音——构建失败时用 `duke_nukem/SonOfABitch`，读取文件时用 `sc_kerrigan/IReadYou`。

### 设置

在 MCP 客户端配置中添加（Claude Desktop、Cursor 等）：

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

通过 Homebrew 安装时路径为 `$(brew --prefix peon-ping)/libexec/mcp/peon-mcp.js`。完整设置说明见 [`mcp/README.md`](mcp/README.md)。

### 可用功能

| 功能 | 说明 |
|---|---|
| **`play_sound`** | 按键名播放一个或多个声音（如 `duke_nukem/SonOfABitch`、`peon/PeonReady1`） |
| **`peon-ping://catalog`** | 以 MCP 资源形式获取完整语音包目录——客户端预取一次，无需重复工具调用 |
| **`peon-ping://pack/{name}`** | 获取指定语音包的详细信息和可用声音键名 |

需要 Node.js 18+。由 [@tag-assistant](https://github.com/tag-assistant) 贡献。

## 多 IDE 支持

peon-ping 适用于任何支持钩子的代理式 IDE。适配器将 IDE 特定事件转换为 [CESP 标准](https://github.com/PeonPing/openpeon)。

| IDE | 状态 | 设置 |
|---|---|---|
| **Claude Code** | 内置 | `curl \| bash` 安装会自动处理 |
| **Amp** | 适配器 | `bash adapters/amp.sh` / `powershell adapters/amp.ps1`（[设置](#amp-设置)） |
| **Gemini CLI** | 适配器 | 添加指向 `adapters/gemini.sh`（Windows 用 `.ps1`）的钩子（[设置](#gemini-cli-设置)） |
| **GitHub Copilot** | 适配器 | 在 `.github/hooks/hooks.json` 中添加指向 `adapters/copilot.sh`（或 `.ps1`）的钩子（[设置](#github-copilot-设置)） |
| **OpenAI Codex** | 适配器 | 在 `~/.codex/config.toml` 中添加指向 `adapters/codex.sh`（或 `.ps1`）的 `notify` 条目 |
| **Cursor** | 内置 | `curl \| bash`、`peon-ping-setup` 或 Windows `install.ps1` 自动检测并注册钩子。在 Windows 上，请在 **设置 → 功能 → 第三方技能** 中启用，以便 Cursor 加载 `~/.claude/settings.json` 以播放 SessionStart/Stop 音效。 |
| **OpenCode** | 适配器 | `bash adapters/opencode.sh` / `powershell adapters/opencode.ps1`（[设置](#opencode-设置)） |
| **Kilo CLI** | 适配器 | `bash adapters/kilo.sh` / `powershell adapters/kilo.ps1`（[设置](#kilo-cli-设置)） |
| **Kiro** | 适配器 | 添加指向 `adapters/kiro.sh`（或 `.ps1`）的钩子条目（[设置](#kiro-设置)） |
| **Windsurf** | 适配器 | 添加指向 `adapters/windsurf.sh`（或 `.ps1`）的钩子条目（[设置](#windsurf-设置)） |
| **Google Antigravity** | 适配器 | `bash adapters/antigravity.sh` / `powershell adapters/antigravity.ps1` |
| **Kimi Code** | 适配器 | `bash adapters/kimi.sh --install` / `powershell adapters/kimi.ps1 -Install`（[设置](#kimi-code-设置)） |
| **OpenClaw** | 适配器 | 调用 `adapters/openclaw.sh <event>`（或 `openclaw.ps1`），支持所有 CESP 分类和原生 Claude Code 事件名 |
| **Rovo Dev CLI** | 适配器 | 如果 `~/.rovodev` 存在，`install.sh` 会自动注册，或手动添加钩子到 `~/.rovodev/config.yml`（[设置](#rovo-dev-cli-设置)） |
| **DeepAgents** | 适配器 | `bash adapters/deepagents.sh` / `powershell adapters/deepagents.ps1`（[设置](#deepagents-设置)） |

> **Windows：** 所有适配器都有原生 PowerShell（`.ps1`）版本。Windows 安装程序（`install.ps1`）会将其复制到 `~/.claude/hooks/peon-ping/adapters/`。文件系统监视器（Amp、Antigravity、Kimi）使用 .NET `FileSystemWatcher` 而非 fswatch/inotifywait — 无需额外依赖。

### Amp 设置

[Amp](https://ampcode.com)（Sourcegraph）的文件系统监视适配器。Amp 不像 Claude Code 那样提供事件钩子，因此该适配器监视 Amp 的线程文件并检测代理何时完成回合。

**设置步骤：**

1. 确保已安装 peon-ping（`curl -fsSL https://peonping.com/install | bash`）

2. 安装 `fswatch`（macOS）或 `inotify-tools`（Linux）：

   ```bash
   brew install fswatch        # macOS
   sudo apt install inotify-tools  # Linux
   ```

3. 启动监视器：

   ```bash
   bash ~/.claude/hooks/peon-ping/adapters/amp.sh        # 前台运行
   bash ~/.claude/hooks/peon-ping/adapters/amp.sh &       # 后台运行
   ```

**事件映射：**

- 新线程文件创建 → 问候音效（*"Ready to work?"*、*"Yes?"*）
- 线程文件停止更新 + 代理完成回合 → 完成音效（*"Work, work."*、*"Job's done!"*）

**工作原理：**

适配器监视 `~/.local/share/amp/threads/` 目录的 JSON 文件变化。当线程文件停止更新（1 秒空闲超时）且最后一条消息来自助手的文本内容（非待处理的工具调用）时，发出 `Stop` 事件 — 表示代理已完成，正在等待你的输入。

### GitHub Copilot 设置

[GitHub Copilot](https://github.com/features/copilot) 的 shell 适配器，完全符合 [CESP v1.0](https://github.com/PeonPing/openpeon) 规范。

**设置步骤：**

1. 确保已安装 peon-ping（`curl -fsSL https://peonping.com/install | bash`）

2. 在仓库的默认分支中创建 `.github/hooks/hooks.json`：

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

3. 提交并合并到默认分支。下次 Copilot agent 会话时钩子将激活。

**事件映射：**

- `sessionStart` → 问候音效（*"Ready to work?"*、*"Yes?"*）
- `userPromptSubmitted` → 首次提示 = 问候，后续 = 垃圾信息检测
- `postToolUse` → 完成音效（*"Work, work."*、*"Job's done!"*）
- `errorOccurred` → 错误音效（*"I can't do that."*）
- `preToolUse` → 跳过（过于嘈杂）
- `sessionEnd` → 无音效（session.end 尚未实现）

**功能：**

- **音频播放** 通过 `afplay`（macOS）、`pw-play`/`paplay`/`ffplay`（Linux）—— 与 shell 钩子相同的优先级链
- **CESP 事件映射** —— GitHub Copilot 钩子映射到标准 CESP 分类（`session.start`、`task.complete`、`task.error`、`user.spam`）
- **桌面通知** —— 默认使用大型覆盖横幅，或标准通知
- **垃圾信息检测** —— 检测 10 秒内 3 次以上快速提示，触发 `user.spam` 语音
- **会话跟踪** —— 每个 Copilot sessionId 独立的会话标记

### OpenCode 设置

[OpenCode](https://opencode.ai/) 的原生 TypeScript 插件，完全符合 [CESP v1.0](https://github.com/PeonPing/openpeon) 规范。

**快速安装：**

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh | bash
```

安装程序将 `peon-ping.ts` 复制到 `~/.config/opencode/plugins/` 并在 `~/.config/opencode/peon-ping/config.json` 创建配置。语音包存储在共享 CESP 路径（`~/.openpeon/packs/`）。

**功能：**

- **声音播放** — 通过 `afplay`（macOS）、`pw-play`/`paplay`/`ffplay`（Linux）— 与 shell 钩子相同的优先级链
- **CESP 事件映射** — `session.created` / `session.idle` / `session.error` / `permission.asked` / 快速提示检测都映射到标准 CESP 分类
- **桌面通知** — 通过 [`terminal-notifier`](https://github.com/julienXX/terminal-notifier) 提供丰富通知（副标题、按项目分组），回退到 `osascript`。仅在终端未获得焦点时触发
- **终端焦点检测** — 通过 AppleScript 检测你的终端应用（Terminal、iTerm2、Warp、Alacritty、kitty、WezTerm、ghostty、Hyper）是否在最前端
- **标签页标题** — 更新终端标签页显示任务状态（`● 项目: 工作中...` / `✓ 项目: 完成` / `✗ 项目: 错误`）
- **语音包切换** — 从配置读取 `default_pack`（旧版配置中回退到 `active_pack`），运行时加载语音包的 `openpeon.json` 清单。`path_rules` 可根据工作目录覆盖语音包。
- **不重复逻辑** — 避免每个分类连续播放相同声音
- **刷屏检测** — 检测 10 秒内 3 次以上快速提示，触发 `user.spam` 语音

<details>
<summary>🖼️ 截图：带有自定义苦工图标的桌面通知</summary>

![peon-ping OpenCode notifications](https://github.com/user-attachments/assets/e433f9d1-2782-44af-a176-71875f3f532c)

</details>

> **提示：** 安装 `terminal-notifier`（`brew install terminal-notifier`）以获得更丰富的通知（支持副标题和分组）。

<details>
<summary>🎨 可选：自定义苦工图标用于通知</summary>

默认情况下，`terminal-notifier` 显示通用终端图标。包含的脚本使用 macOS 内置工具（`sips` + `iconutil`）将其替换为苦工图标 — 无需额外依赖。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/setup-icon.sh)
```

或本地安装（Homebrew / git clone）：

```bash
bash ~/.claude/hooks/peon-ping/adapters/opencode/setup-icon.sh
```

脚本会自动查找苦工图标（Homebrew libexec、OpenCode 配置或 Claude 钩子目录），生成正确的 `.icns`，备份原始 `Terminal.icns` 并替换。`brew upgrade terminal-notifier` 后需重新运行。

> **未来：** 当 [jamf/Notifier](https://github.com/jamf/Notifier) 发布到 Homebrew（[#32](https://github.com/jamf/Notifier/issues/32)）时，插件将迁移到它 — Notifier 内置 `--rebrand` 支持，无需修改图标。

</details>

### Kilo CLI 设置

[Kilo CLI](https://github.com/kilocode/cli) 的原生 TypeScript 插件，完全符合 [CESP v1.0](https://github.com/PeonPing/openpeon) 规范。Kilo CLI 是 OpenCode 的分支，使用相同的插件系统 — 此安装程序下载 OpenCode 插件并为 Kilo 打补丁。

**快速安装：**

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/kilo.sh | bash
```

安装程序将 `peon-ping.ts` 复制到 `~/.config/kilo/plugins/` 并在 `~/.config/kilo/peon-ping/config.json` 创建配置。语音包存储在共享 CESP 路径（`~/.openpeon/packs/`）。

**功能：** 与 [OpenCode 适配器](#opencode-设置)相同 — 声音播放、CESP 事件映射、桌面通知、终端焦点检测、标签页标题、语音包切换、不重复逻辑和刷屏检测。

### Gemini CLI 设置

[Gemini CLI](https://github.com/google-gemini/gemini-cli) 的 shell 适配器，完全符合 [CESP v1.0](https://github.com/PeonPing/openpeon) 规范。

**设置步骤：**

1. 确保已安装 peon-ping（`curl -fsSL https://peonping.com/install | bash`）

2. 在 `~/.gemini/settings.json` 中添加以下钩子：

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

**事件映射：**

- `SessionStart`（startup）→ 问候音效（*"准备好了吗？"*、*"是的？"*）
- `AfterAgent` → 任务完成音效（*"干活，干活。"*、*"完成了！"*）
- `AfterTool`（成功）→ 任务完成音效；（失败）→ 错误音效（*"我做不到。"*）
- `Notification` → 系统通知

### Windsurf 设置

添加到 `~/.codeium/windsurf/hooks.json`（用户级）或 `.windsurf/hooks.json`（工作区级）：

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

### Kiro 设置

创建 `~/.kiro/agents/peon-ping.json`：

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

`preToolUse`/`postToolUse` 被有意排除 — 它们会在每次工具调用时触发，会非常嘈杂。

### Rovo Dev CLI 设置

[Rovo Dev CLI](https://developer.atlassian.com/cloud/rovo/)（Atlassian）的 shell 适配器，完全符合 [CESP v1.0](https://github.com/PeonPing/openpeon) 规范。

**自动设置：**

如果运行 `install.sh` 或 `peon-ping-setup` 时 `~/.rovodev/config.yml` 存在，事件钩子会自动注册。

**手动设置：**

1. 确保已安装 peon-ping（`curl -fsSL https://peonping.com/install | bash`）

2. 添加到 `~/.rovodev/config.yml`：

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

3. 重启 Rovo Dev CLI 以使钩子生效。

**事件映射：**

- `on_complete` → 完成音效（*"Work, work."*、*"Job's done!"*）
- `on_error` → 错误音效（*"I can't do that."*、*"Son of a bitch!"*）
- `on_tool_permission` → 权限提示音效（*"Something need doing?"*、*"Hmm?"*）

**功能：**

- **声音播放** 通过 `afplay`（macOS）、`pw-play`/`paplay`/`ffplay`（Linux）— 与 shell 钩子相同的优先级链
- **CESP 事件映射** — Rovo Dev 事件映射到标准 CESP 分类（`task.complete`、`task.error`、`input.required`）
- **桌面通知** — 默认大型覆盖横幅，或标准通知
- **防抖** — 抑制快速完成产生的重复声音

### Kimi Code 设置

[Kimi Code CLI](https://github.com/MoonshotAI/kimi-cli)（MoonshotAI）的文件系统监视适配器。Kimi Code 将 Wire Mode 事件写入 `~/.kimi/sessions/` — 该适配器作为后台守护进程监视这些文件并将事件转换为 CESP 格式。

```bash
# 安装（启动后台守护进程）
bash ~/.claude/hooks/peon-ping/adapters/kimi.sh --install

# 查看状态 / 停止
bash ~/.claude/hooks/peon-ping/adapters/kimi.sh --status
bash ~/.claude/hooks/peon-ping/adapters/kimi.sh --uninstall
```

macOS 需要 `fswatch`（`brew install fswatch`），Linux 需要 `inotifywait`（`apt install inotify-tools`）。`curl | bash` 安装器会自动检测 Kimi Code 并启动守护进程。

**事件映射：**

- 新会话 → 问候音效（*"Ready to work?"*、*"Yes?"*）
- Agent 完成回合 → 完成音效（*"Work, work."*、*"Job's done!"*）
- 上下文压缩 → Token 限制音效
- 子 Agent 启动 → 子 Agent 跟踪

## 远程开发（SSH / Devcontainers / Codespaces）

在远程服务器或容器中编码？peon-ping 自动检测 SSH 会话、devcontainers 和 Codespaces，然后通过本地机器上运行的轻量级中继路由音频和通知。

### SSH 设置

1. **在本地机器上**，启动中继：
   ```bash
   peon relay --daemon
   ```

2. **带端口转发的 SSH**：
   ```bash
   ssh -R 19998:localhost:19998 your-server
   ```

3. **在远程安装 peon-ping** — 它会自动检测 SSH 会话并通过转发端口将音频请求发送回本地中继。

就这样。声音在你的笔记本电脑上播放，而不是远程服务器。

### Devcontainers / Codespaces

无需端口转发 — peon-ping 自动检测 `REMOTE_CONTAINERS` 和 `CODESPACES` 环境变量并将音频路由到 `host.docker.internal:19998`。只需在主机上运行 `peon relay --daemon`。

### 中继命令

```bash
peon relay                # 前台启动中继
peon relay --daemon       # 后台启动
peon relay --stop         # 停止后台中继
peon relay --status       # 检查中继是否运行
peon relay --port=12345   # 自定义端口（默认：19998）
peon relay --bind=0.0.0.0 # 监听所有接口（安全性较低）
```

环境变量：`PEON_RELAY_PORT`、`PEON_RELAY_HOST`、`PEON_RELAY_BIND`。

如果 peon-ping 检测到 SSH 或容器会话但无法连接中继，它会在 `SessionStart` 时打印设置说明。

### 基于分类的 API（用于轻量级远程钩子）

中继支持在服务器端处理声音选择的基于分类的端点。这对于未安装 peon-ping 的远程机器很有用 — 远程钩子只需发送分类名称，中继从活动语音包中随机选择声音。

**端点：**

| 端点 | 描述 |
|---|---|
| `GET /health` | 健康检查（返回 "OK"） |
| `GET /play?file=<path>` | 播放指定声音文件（旧版） |
| `GET /play?category=<cat>` | 播放分类中的随机声音（推荐） |
| `POST /notify` | 发送桌面通知 |

**远程钩子示例（`scripts/remote-hook.sh`）：**

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

将其复制到远程机器并在 `~/.claude/settings.json` 中注册：

```json
{
  "hooks": {
    "SessionStart": [{"command": "bash /path/to/remote-hook.sh"}],
    "Stop": [{"command": "bash /path/to/remote-hook.sh"}],
    "PermissionRequest": [{"command": "bash /path/to/remote-hook.sh"}]
  }
}
```

中继从本地机器的 `config.json` 读取活动语音包和音量，加载语音包清单，并选择随机声音（避免重复）。

## 手机通知

当任务完成或需要关注时在手机上收到推送通知 — 当你离开桌面时很有用。

### 快速开始（ntfy.sh — 免费，无需账户）

1. 在手机上安装 [ntfy 应用](https://ntfy.sh)
2. 在应用中订阅一个唯一主题（例如 `my-peon-notifications`）
3. 运行：
   ```bash
   peon mobile ntfy my-peon-notifications
   ```

也支持 [Pushover](https://pushover.net) 和 [Telegram](https://core.telegram.org/bots)：

```bash
peon mobile pushover <user_key> <app_token>
peon mobile telegram <bot_token> <chat_id>
```

### 手机命令

```bash
peon mobile on            # 启用手机通知
peon mobile off           # 禁用手机通知
peon mobile status        # 显示当前配置
peon mobile test          # 发送测试通知
```

手机通知在每个事件时都会触发，无论窗口焦点 — 它们独立于桌面通知和声音。

## 语音包

160 多个语音包，涵盖魔兽争霸、星际争霸、红色警戒、传送门、塞尔达、Dota 2、绝地潜兵2、上古卷轴等。默认安装包含 5 个精选语音包：

| 语音包 | 角色 | 声音 |
|---|---|---|
| `peon`（默认） | 兽人苦工（魔兽争霸 III） | "Ready to work?", "Work, work.", "Okie dokie." |
| `peasant` | 人类农民（魔兽争霸 III） | "Yes, milord?", "Job's done!", "Ready, sir." |
| `sc_kerrigan` | 莎拉·凯瑞甘（星际争霸） | "I gotcha", "What now?", "Easily amused, huh?" |
| `sc_battlecruiser` | 战列巡航舰（星际争霸） | "Battlecruiser operational", "Make it happen", "Engage" |
| `glados` | GLaDOS（传送门） | "Oh, it's you.", "You monster.", "Your entire team is dead." |

**[浏览所有语音包并试听 &rarr; openpeon.com/packs](https://openpeon.com/packs)**

使用 `--all` 安装全部，或随时切换语音包：

```bash
peon packs use glados             # 切换到指定语音包
peon packs next                   # 切换到下一个语音包
peon packs list                   # 列出所有已安装语音包
peon packs list --registry        # 浏览所有可用语音包
peon packs install glados,murloc  # 安装指定语音包
peon packs install --all          # 安装注册表中所有语音包
```

想添加自己的语音包？参见 [openpeon.com/create 完整指南](https://openpeon.com/create) 或 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 卸载

**macOS/Linux：**

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/uninstall.sh        # 全局
bash .claude/hooks/peon-ping/uninstall.sh           # 项目本地
```

**Windows (PowerShell)：**

```powershell
# 标准卸载（删除声音前会提示）
powershell -File "$env:USERPROFILE\.claude\hooks\peon-ping\uninstall.ps1"

# 保留语音包（移除其他所有内容）
powershell -File "$env:USERPROFILE\.claude\hooks\peon-ping\uninstall.ps1" -KeepSounds
```

## 系统要求

- **macOS** — `afplay`（内置），AppleScript 用于通知
- **Linux** — 以下之一：`pw-play`、`paplay`、`ffplay`、`mpv`、`play`（SoX）或 `aplay`；`notify-send` 用于通知
- **Windows** — 原生 PowerShell 带 `MediaPlayer` 和 WinForms（无需 WSL），或 WSL2
- **MSYS2 / Git Bash** — `python3`、`cygpath`（内置）；音频通过 `ffplay`/`mpv`/`play` 或 PowerShell 回退
- **所有平台** — `python3`（原生 Windows 不需要）
- **SSH/远程** — 远程主机上需要 `curl`
- **IDE** — 支持钩子的 Claude Code（或通过[适配器](#多-ide-支持)的任何支持的 IDE）

## 工作原理

`peon.sh` 是一个为 `SessionStart`、`SessionEnd`、`SubagentStart`、`UserPromptSubmit`、`Stop`、`Notification`、`PermissionRequest`、`PostToolUseFailure` 和 `PreCompact` 事件注册的 Claude Code 钩子。在每个事件：

1. **事件映射** — 嵌入的 Python 块将钩子事件映射到 [CESP](https://github.com/PeonPing/openpeon) 声音分类（`session.start`、`task.complete`、`input.required` 等）
2. **声音选择** — 从活动语音包清单中随机选择一个语音，避免重复
3. **音频播放** — 通过 `afplay`（macOS）、PowerShell `MediaPlayer`（WSL2/MSYS2 回退）或 `pw-play`/`paplay`/`ffplay`/`mpv`/`aplay`（Linux/MSYS2）异步播放声音
4. **通知** — 更新终端标签页标题，如果终端未获得焦点则发送桌面通知
5. **远程路由** — 在 SSH 会话、devcontainers 和 Codespaces 中，音频和通知请求通过 HTTP 转发到本地机器上的[中继服务器](#远程开发ssh--devcontainers--codespaces)

语音包在安装时从 [OpenPeon 注册表](https://github.com/PeonPing/registry)下载。官方语音包托管在 [PeonPing/og-packs](https://github.com/PeonPing/og-packs)。声音文件归各自发行商（Blizzard、Valve、EA 等）所有，根据合理使用原则分发用于个人通知目的。

## 链接

- [@peonping on X](https://x.com/peonping) — 更新和公告
- [peonping.com](https://peonping.com/) — 主页
- [openpeon.com](https://openpeon.com/) — CESP 规范、语音包浏览器、[集成指南](https://openpeon.com/integrate)、创建指南
- [OpenPeon 注册表](https://github.com/PeonPing/registry) — 语音包注册表（GitHub Pages）
- [og-packs](https://github.com/PeonPing/og-packs) — 官方语音包
- [peon-pet](https://github.com/PeonPing/peon-pet) — macOS 桌面宠物（兽人精灵，响应钩子事件）
- [许可证 (MIT)](LICENSE)

## 支持项目

[removed_support_line]
- 社区代币（DYOR / 仅供娱乐）：有人在 Base 上创建了 $PEON 代币 — 我们接收交易手续费，帮助资助开发。[`0xf4ba744229afb64e2571eef89aacec2f524e8ba3`](https://dexscreener.com/base/0xf4bA744229aFB64E2571eef89AaceC2F524e8bA3)
