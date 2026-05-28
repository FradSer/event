# event ![Swift](https://img.shields.io/badge/Swift-5.9+-F05138) ![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey)

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) [![Twitter Follow](https://img.shields.io/twitter/follow/FradSer?style=social)](https://twitter.com/FradSer)

[English](README.md) | **简体中文**

一个纯 Swift 编写的 CLI 工具，用于管理 Apple 提醒事项和日历。在 macOS 上通过 EventKit 直接读写 Apple 数据；在 Linux 上则基于一个与 Cloudflare D1 后端保持同步的本地 SQLite 存储工作。

## 功能特性

- 创建、读取、更新和删除提醒事项
- 完整的日历事件 CRUD 操作
- 将提醒事项组织到列表中
- 在提醒事项中添加和管理子任务
- 为提醒事项添加标签以便组织
- Markdown（默认）和 JSON 输出
- 通过 `event sync` 用 Cloudflare D1 在多设备间云同步
- 同时支持 macOS（EventKit）和 Linux（本地 SQLite + 同步）

## 系统要求

- Swift 5.9 或更高版本
- **macOS** 14.0 或更高版本 —— 通过 EventKit 直接读写 Apple 提醒事项和日历
- **Linux** —— 没有 EventKit，因此 `event` 基于位于 `~/.local/share/event-sync/local.db` 的本地 SQLite 数据库工作。先运行 `event sync` 从 Cloudflare D1 填充数据，之后用相同的命令操作这些数据

## 安装方法

### Homebrew（推荐）

```bash
# 添加 tap
brew tap FradSer/brew

# 安装
brew install event
```

### 源码编译安装

```bash
# 克隆仓库
git clone https://github.com/FradSer/event.git
cd event

# 编译并安装
swift build -c release
cp .build/release/event /usr/local/bin/
```

### 首次运行 - 授予权限（macOS）

首次运行时，工具会请求访问提醒事项和日历的权限。如果系统权限对话框没有弹出，你可以手动授予权限：

**推荐：使用 AdvancedReminderEdit 快捷指令**
- 下载 [AdvancedReminderEdit](https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808)
- 打开「快捷指令」应用并运行一次该快捷指令
- 这将启用高级提醒功能：原生支持 tags、URL 和父提醒事项
- 同时也会触发提醒事项和日历的系统权限对话框

或者，你也可以在系统设置中手动开启权限：
- 系统设置 > 隐私与安全性 > 提醒事项 > 启用「终端」
- 系统设置 > 隐私与安全性 > 日历 > 启用「终端」

## 使用方法

### 提醒事项

```bash
# 列出提醒事项
event reminders list

# 创建提醒事项
event reminders create --title "购买日用品"

# 创建带标签的提醒事项
event reminders create --title "购买日用品" --tags "购物,紧急"

# 标记提醒事项为已完成
event reminders update --id <REMINDER_ID> --completed

# 删除提醒事项
event reminders delete --id <REMINDER_ID>
```

### 日历

```bash
# 列出日历事件
event calendar list

# 列出指定日期范围内的事件
event calendar list --start "2026-03-01" --end "2026-03-31"

# 创建事件
event calendar create --title "会议" --start "2026-03-10 14:00:00" --end "2026-03-10 15:00:00"
```

### 列表

```bash
# 列出所有提醒事项列表
event reminders lists list

# 创建列表
event reminders lists create --name "工作"
```

### 同步（Cloudflare D1）

`event sync` 通过 Cloudflare Worker（后端为 D1）在多台设备之间同步提醒事项、日历事件和列表。

#### 1. 部署 Worker（一次性）

```bash
cd skills/apple-events/references/worker
pnpm install
pnpm exec wrangler login
cp wrangler.toml.example wrangler.toml    # 复制配置文件模板
pnpm exec wrangler d1 create event-sync   # 把输出的 database_id 填入 wrangler.toml
pnpm run db:migrate:remote                # 创建 D1 数据表
openssl rand -hex 32 | pnpm exec wrangler secret put API_TOKEN   # 自动生成并设置一个强随机 token
pnpm run deploy                           # 输出 https://<worker>.workers.dev
```

#### 2. 在每台设备上配置

设置两个环境变量 —— 写入 `~/.zshrc`（或 `~/.bashrc`）以便跨终端持久生效：

```bash
export EVENT_SYNC_API_URL=https://<your-worker>.workers.dev
export EVENT_SYNC_API_TOKEN=<第 1 步设置的 API_TOKEN>
# EVENT_SYNC_DEVICE_ID 可选，未设置时默认使用主机名

event sync status   # 验证配置
```

环境变量优先。未设置时，`event` 会回退到 `event sync config --api-url <URL>
--api-token <TOKEN>` 写入的配置文件（`--device-id` 可选，默认使用主机名）。

> **注意：** 配置文件 `~/.config/event-sync/config.json` 以明文存储 API token
> （权限 `0600`，仅属主可读）。请勿提交到版本控制或复制到共享存储。

#### 3. 同步

```bash
event sync   # 完整双向同步：先拉取，再推送
```

在每台设备上运行即可。device id（默认用主机名）区分各设备，设备不会把自己刚推送的数据又拉回来。在 Linux 上，这是新机器上的第一步 —— 它会先填充本地 SQLite 存储，之后其他 `event` 命令才有数据可显示。

高级用法 —— 单向 / 按类型同步：

```bash
event sync push --type all      # 仅推送
event sync pull --type calendar # 仅拉取，且只同步一种类型
```

> **注意：** 日历同步仅覆盖过去一年到未来两年范围内的事件，超出该窗口的事件不会同步。
> 冲突按“最后写入优先”解决：拉取不会覆盖比服务器版本更新的本地副本，该副本会在下次同步时推送。

更多命令请运行 `event --help`。

## Agent Skill

[`apple-events`](skills/apple-events/) skill 可让 AI agent 通过 `event` 直接管理你的 Apple 提醒事项和日历。

1. 确保 `event` CLI 已安装并在系统 PATH 中。
2. 安装 skill：
   ```bash
   npx skills add https://github.com/FradSer/event --skill apple-events
   ```

## 许可证

MIT License

## 作者

Frad Lee - [frad.me](https://frad.me)