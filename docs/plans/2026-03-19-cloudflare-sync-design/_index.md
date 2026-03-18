# Cloudflare 同步架构设计

## 背景与目标

### 问题陈述

当前 `event` CLI 仅能在 macOS 上运行，通过 EventKit 直接操作 Apple Reminders 和 Calendar。云端 AI Agent（运行于 Linux）无法访问同一份数据，限制了跨平台使用场景。

### 目标

1. **Mac 本地**：保持现有 EventKit 操作不变，新增同步能力
2. **云端 Agent（Linux）**：同一 Swift CLI 编译后直接操作 Cloudflare D1
3. **端到端加密**：敏感字段在客户端加密，Cloudflare 只存密文
4. **双向同步**：两端完整读写，变更自动同步，冲突自动解决
5. **用户配置**：通过 `event sync init` 配置 Cloudflare API 凭据

---

## 需求列表

| ID | 需求 | 优先级 |
|----|------|--------|
| R1 | Mac 端使用 EventKit 直接操作 Apple 数据 | Must |
| R2 | Linux 端通过 HTTP 操作 Cloudflare D1 | Must |
| R3 | 同一 Swift 代码库编译为 macOS 和 Linux 二进制 | Must |
| R4 | 敏感字段（notes, url, location）端到端加密 | Must |
| R5 | Mac 端检测到 EventKit 变化后自动同步 | Should |
| R6 | `event sync` 子命令管理同步配置和状态 | Must |
| R7 | Last-Write-Wins 冲突解决 | Must |
| R8 | Cloudflare Workers 提供 REST CRUD API | Must |
| R9 | Bearer Token 认证 | Must |
| R10 | 网络断开时本地操作不受影响（Mac 端） | Must |
| R11 | 加密主密钥在 macOS 存于 Keychain，Linux 存于环境变量 | Must |

---

## 技术决策

### 决策 1：编译时平台分离（`#if os(macOS)`）

**理由**：Swift 原生支持编译条件，零运行时开销，类型安全。
**替代方案**：运行时检测（较复杂，需 optional 类型）或独立仓库（维护成本高）。

### 决策 2：协议抽象服务层

**理由**：Commands 层无需感知底层实现，未来可扩展其他后端。
**新增协议**：`RemindersBackend`, `CalendarBackend`, `ListsBackend`

### 决策 3：部分字段加密（非全字段）

**理由**：`title`, `list_name`, `is_completed`, `due_date` 等用于云端查询和过滤，必须保持明文。
**加密字段**：`notes`, `url`, `location`, `alarms`, `recurrenceRules`（任务）及 `attendees`（日历事件）打包为 `encrypted_payload` JSON blob，存储为 base64 编码字符串。

### 决策 4：Cloudflare Workers + Hono.js

**理由**：轻量级路由框架，D1 binding 支持好，TypeScript 类型安全。

### 决策 5：Static Bearer Token 认证

**理由**：简单可靠，适合单用户场景。未来可升级为 Cloudflare Access。

---

## 详细设计

### 架构总览

```
┌─────────────────────────────────────────────────────────┐
│                    用户 / AI Agent                       │
└─────────────────────────┬───────────────────────────────┘
                          │ CLI 命令
          ┌───────────────┴───────────────┐
          │         Commands 层            │  (不变)
          │  ReminderCommands              │
          │  CalendarCommands              │
          │  ListCommands                  │
          │  SyncCommands (新增)           │
          └───────┬───────────────┬───────┘
                  │               │
       macOS      │               │  Linux
       ┌──────────▼──┐     ┌──────▼──────────┐
       │ EventKit    │     │ Cloudflare      │
       │ Services    │     │ Services        │
       │ (现有)      │     │ (新增)          │
       └──────┬──────┘     └──────┬──────────┘
              │                   │
              │   SyncService     │
              │   (macOS, 新增)   │
              └─────────┬─────────┘
                        │
              ┌─────────▼─────────┐
              │ CloudflareClient  │  (共用)
              │ + EncryptionSvc   │
              └─────────┬─────────┘
                        │ HTTPS + Bearer Token
              ┌─────────▼─────────┐
              │ Cloudflare Workers│
              │ (Hono.js)         │
              └─────────┬─────────┘
                        │
              ┌─────────▼─────────┐
              │ Cloudflare D1     │
              │ (SQLite)          │
              └───────────────────┘
```

### 新增 Swift 模块结构

```
Sources/event/
├── Commands/
│   ├── SyncCommands.swift          # 新增：event sync 子命令
│   └── ... (现有不变)
├── Services/
│   ├── Protocols/                  # 新增：服务协议
│   │   ├── RemindersBackend.swift
│   │   ├── CalendarBackend.swift
│   │   └── ListsBackend.swift
│   ├── EventKit/                   # macOS 专用
│   │   ├── ReminderService.swift   # 重命名/移动现有文件
│   │   ├── CalendarService.swift
│   │   └── ListService.swift
│   ├── Cloudflare/                 # 新增：Linux 实现
│   │   ├── CloudflareReminderService.swift
│   │   ├── CloudflareCalendarService.swift
│   │   └── CloudflareListService.swift
│   ├── CloudflareClient.swift      # 新增：HTTP 客户端（共用）
│   ├── EncryptionService.swift     # 新增：AES-256-GCM（共用）
│   ├── SyncService.swift           # 新增：macOS 双向同步
│   └── ConfigService.swift         # 新增：配置管理
└── Models/
    └── SyncModels.swift             # 新增：同步相关数据模型
```

### 服务协议定义

```swift
// RemindersBackend.swift
protocol RemindersBackend {
    func fetchReminders(from listName: String?) async throws -> [Reminder]
    func fetchReminder(byId id: String) async throws -> Reminder
    func createReminder(_ params: CreateReminderParams) async throws -> Reminder
    func updateReminder(id: String, params: UpdateReminderParams) async throws -> Reminder
    func deleteReminder(id: String) async throws
}
```

### 配置文件格式

```toml
# ~/.config/event/config.toml
[cloudflare]
api_url = "https://event-sync.your-name.workers.dev"
api_token = "your-bearer-token"

[encryption]
# macOS: 密钥存储在 Keychain，此处留空
# Linux: 通过 EVENT_ENCRYPTION_KEY 环境变量提供
key_source = "keychain"   # 或 "env"
```

### 加密方案

```
加密字段（打包为 JSON）：
  { "notes": "...", "url": "...", "location": "...", "alarms": [...] }

加密过程（每条记录独立）：
  1. 序列化为 JSON bytes
  2. 生成 12-byte 随机 IV
  3. AES-256-GCM 加密（key = 主密钥）
  4. 输出：base64(ciphertext + tag) 存入 encrypted_payload
           base64(iv) 存入 encrypted_iv

AAD（附加认证数据）：record_id + last_modified_date（防篡改）
```

### D1 数据库 Schema

```sql
-- 任务表
CREATE TABLE reminders (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    is_completed INTEGER DEFAULT 0,
    is_flagged INTEGER DEFAULT 0,
    list_name TEXT,
    due_date TEXT,
    start_date TEXT,
    completion_date TEXT,
    creation_date TEXT,
    last_modified_date TEXT NOT NULL,
    external_id TEXT,
    priority INTEGER DEFAULT 0,
    encrypted_payload TEXT,     -- AES-256-GCM 加密的 notes/url/location/alarms
    encrypted_iv TEXT,          -- base64 编码的 IV
    sync_version INTEGER DEFAULT 1,
    deleted_at TEXT,            -- 软删除
    device_id TEXT,             -- 最后修改的设备 ID
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 日历事件表
CREATE TABLE calendar_events (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    calendar_name TEXT,
    start_date TEXT NOT NULL,
    end_date TEXT NOT NULL,
    is_all_day INTEGER DEFAULT 0,
    last_modified_date TEXT NOT NULL,
    status TEXT,
    availability TEXT,
    encrypted_payload TEXT,     -- notes, url, location, attendees, alarms
    encrypted_iv TEXT,
    sync_version INTEGER DEFAULT 1,
    deleted_at TEXT,
    device_id TEXT,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 设备同步状态
CREATE TABLE sync_state (
    device_id TEXT PRIMARY KEY,
    last_sync_version INTEGER DEFAULT 0,
    last_synced_at TEXT
);

-- 索引
CREATE INDEX idx_reminders_list ON reminders(list_name) WHERE deleted_at IS NULL;
CREATE INDEX idx_reminders_due ON reminders(due_date) WHERE deleted_at IS NULL;
CREATE INDEX idx_reminders_version ON reminders(sync_version);
CREATE INDEX idx_events_calendar ON calendar_events(calendar_name) WHERE deleted_at IS NULL;
CREATE INDEX idx_events_start ON calendar_events(start_date) WHERE deleted_at IS NULL;
CREATE INDEX idx_events_version ON calendar_events(sync_version);
```

### Cloudflare Workers API

```
认证：
  Authorization: Bearer <token>
  X-Device-ID: <device-uuid>

端点：
  GET  /api/v1/reminders               # 查询任务（支持 ?list=&completed=&since_version=）
  GET  /api/v1/reminders/:id           # 获取单个任务
  POST /api/v1/reminders               # 创建任务
  PUT  /api/v1/reminders/:id           # 更新任务
  DELETE /api/v1/reminders/:id         # 软删除任务
  POST /api/v1/reminders/batch         # 批量推送变更（同步用）

  GET  /api/v1/events                  # 查询日历事件（?start=&end=&since_version=）
  GET  /api/v1/events/:id
  POST /api/v1/events
  PUT  /api/v1/events/:id
  DELETE /api/v1/events/:id
  POST /api/v1/events/batch

  GET  /api/v1/sync/version            # 获取当前全局 sync_version
  POST /api/v1/sync/checkpoint         # 更新设备同步状态
```

### 冲突解决（Last-Write-Wins）

```
规则：
  1. 比较 last_modified_date（ISO 8601 精度到秒）
  2. 较新的记录覆盖较旧的
  3. 软删除优先级：
     - 如果云端已删除且本地修改时间更早 → 保留删除
     - 如果本地修改时间更新 → 撤销删除，保留本地版本

流程（Mac 同步）：
  1. 获取云端 since_version 之后的所有变更
  2. 对比本地 EventKit 数据
  3. 解决冲突（LWW）
  4. 推送本地变更到云端
  5. 应用云端变更到 EventKit
  6. 更新 sync_state
```

### 新增 CLI 命令

```bash
# 初始化同步配置
event sync init --url <workers-url> --token <api-token>

# 查看同步状态
event sync status

# 手动推送本地变更到云端
event sync push

# 手动拉取云端变更到本地
event sync pull

# 启动后台自动同步守护进程（macOS 专用）
event sync daemon start
event sync daemon stop
```

---

## 设计文档

- [BDD Specifications](./bdd-specs.md) - 行为场景和测试策略
- [Architecture](./architecture.md) - Swift 代码架构和 Package.swift 变更详情
- [Best Practices](./best-practices.md) - 安全、性能和代码质量指南
