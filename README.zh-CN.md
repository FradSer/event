# event

[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?style=flat&logo=swift)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-000000?style=flat&logo=apple)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Twitter Follow](https://img.shields.io/twitter/follow/FradSer?style=social)](https://twitter.com/FradSer)

一个纯 Swift 编写的 CLI 工具，用于管理 macOS 上的 Apple 提醒事项和日历。

[English](README.md) | 简体中文

## 功能特性

- 提醒事项管理：创建、读取、更新和删除提醒事项
- 日历事件：完整的日历事件 CRUD 操作
- 列表：组织和管理提醒事项列表
- 子任务：在提醒事项中添加和管理子任务
- 标签：为提醒事项添加标签以便更好地组织
- 多种输出格式：Markdown（默认）和 JSON

## 系统要求

- macOS 14.0 或更高版本
- Swift 5.9 或更高版本

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

### 首次运行 - 授予权限

首次运行时，工具会请求访问提醒事项和日历的权限。如果系统权限对话框没有弹出，你可以手动授予权限：

**推荐：使用 AdvancedReminderEdit 快捷指令**
- 下载 [AdvancedReminderEdit](https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808)
- 打开「快捷指令」应用并运行一次该快捷指令
- 这将启用高级提醒功能：原生支持 tags、URL 和父提醒事项
- 同时也会触发提醒事项和日历的系统权限对话框

或者，你也可以在系统设置中手动开启权限：
- 系统设置 > 隐私与安全性 > 提醒事项 > 启用「终端」（或你的 Shell）
- 系统设置 > 隐私与安全性 > 日历 > 启用「终端」

## Agent Skill

`apple-events` skill 现已迁移到 [`FradSer/skills`](https://github.com/FradSer/skills) 仓库中，可让 AI agent 通过 `event` 直接管理你的 Apple 提醒事项和日历。

1. 确保已安装 `event` CLI，并且它已在系统 PATH 中（例如 `/usr/local/bin/event`）。
2. 从 skills 仓库安装 `apple-events` skill：
   ```bash
   npx skills add https://github.com/FradSer/skills --skill apple-events
   ```

## 使用方法

MIT License

## 作者

Frad Lee - https://frad.me
