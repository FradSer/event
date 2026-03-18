# 架构详情

## Package.swift 变更

### 平台支持

```swift
// 当前
platforms: [.macOS(.v14)]

// 变更后
platforms: [.macOS(.v14), .linux]  // Linux 无最低版本限制
```

### 依赖新增

```swift
dependencies: [
    // 现有依赖不变
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),

    // 新增：Linux 上 CryptoKit 的替代方案
    .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),

    // 新增：HTTP 客户端（URLSession 在 Linux 需要此包）
    // 注意：Swift 5.9+ URLSession 已内置 Linux 支持，无需额外依赖
],
```

### Target 分离

```swift
.executableTarget(
    name: "event",
    dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        // 条件依赖
        .target(name: "EventSyncCore"),
    ],
    swiftSettings: [
        .unsafeFlags(["-parse-as-library"]),
    ]
),

// 跨平台核心（Commands + Models + Cloudflare 服务）
.target(
    name: "EventSyncCore",
    dependencies: [
        .product(name: "Crypto", package: "swift-crypto"),
    ]
),
```

**注意**：实际实现可以保持单一 target，使用 `#if os(macOS)` 在源文件内区分，不必分 target。这样改动最小。

---

## 协议层设计

### RemindersBackend.swift

```swift
// Sources/event/Services/Protocols/RemindersBackend.swift
protocol RemindersBackend: Sendable {
    func fetchReminders(from listName: String?) async throws -> [Reminder]
    func fetchReminder(byId id: String) async throws -> Reminder
    func createReminder(_ params: CreateReminderParams) async throws -> Reminder
    func updateReminder(id: String, params: UpdateReminderParams) async throws -> Reminder
    func deleteReminder(id: String) async throws
}
```

### CalendarBackend.swift

```swift
protocol CalendarBackend: Sendable {
    func fetchEvents(
        from start: Date,
        to end: Date,
        calendar: String?
    ) async throws -> [CalendarEvent]
    func fetchEvent(byId id: String) async throws -> CalendarEvent
    func createEvent(_ params: CreateEventParams) async throws -> CalendarEvent
    func updateEvent(id: String, params: UpdateEventParams) async throws -> CalendarEvent
    func deleteEvent(id: String) async throws
}
```

### ListsBackend.swift

```swift
protocol ListsBackend: Sendable {
    func fetchLists() async throws -> [ReminderList]
    func createList(name: String, color: String?) async throws -> ReminderList
    func deleteList(name: String) async throws
}
```

---

## macOS 实现（现有服务适配）

现有的 `ReminderService`, `CalendarService`, `ListService` 只需添加协议遵从声明：

```swift
// 只需添加这一行
extension ReminderService: RemindersBackend {}
extension CalendarService: CalendarBackend {}
extension ListService: ListsBackend {}
```

所有现有方法签名已满足协议要求，或进行最小调整。

---

## Linux 实现（Cloudflare 服务）

### CloudflareClient.swift

```swift
// 跨平台 HTTP 客户端（macOS 和 Linux 共用）
actor CloudflareClient {
    let baseURL: String
    let token: String
    let encryptionService: EncryptionService

    init(config: CloudflareConfig, encryptionService: EncryptionService) {
        self.baseURL = config.apiURL
        self.token = config.apiToken
        self.encryptionService = encryptionService
    }

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T
    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T
    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T
    func delete(_ path: String) async throws

    private func makeRequest(_ urlRequest: URLRequest) async throws -> Data
    private func addAuth(_ request: inout URLRequest)
}
```

### CloudflareReminderService.swift

```swift
// 仅在 Linux 编译或 macOS 配置了 Cloudflare 时使用
actor CloudflareReminderService: RemindersBackend {
    private let client: CloudflareClient

    func fetchReminders(from listName: String?) async throws -> [Reminder] {
        var queryItems: [URLQueryItem] = []
        if let listName { queryItems.append(.init(name: "list", value: listName)) }
        let response: [CloudflareReminderDTO] = try await client.get(
            "/api/v1/reminders",
            queryItems: queryItems
        )
        return try response.map { try $0.toReminder(decryptWith: client.encryptionService) }
    }

    // ...其他方法类似
}
```

---

## EncryptionService.swift

```swift
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto  // swift-crypto on Linux
#endif

actor EncryptionService {
    private let key: SymmetricKey

    init(key: SymmetricKey) {
        self.key = key
    }

    // 加密：返回 (ciphertext: Data, iv: Data)
    func encrypt(_ payload: EncryptedPayload, recordId: String, modifiedDate: String) throws -> (ciphertext: Data, iv: Data) {
        let plaintext = try JSONEncoder().encode(payload)
        let nonce = try AES.GCM.Nonce()  // 随机 12-byte IV
        let aad = "\(recordId)|\(modifiedDate)".data(using: .utf8)!

        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
        return (sealed.ciphertext + sealed.tag, Data(nonce))
    }

    // 解密
    func decrypt(_ ciphertext: Data, iv: Data, recordId: String, modifiedDate: String) throws -> EncryptedPayload {
        let nonce = try AES.GCM.Nonce(data: iv)
        let aad = "\(recordId)|\(modifiedDate)".data(using: .utf8)!
        let tag = ciphertext.suffix(16)
        let cipher = ciphertext.dropLast(16)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipher, tag: tag)
        let plaintext = try AES.GCM.open(box, using: key, authenticating: aad)
        return try JSONDecoder().decode(EncryptedPayload.self, from: plaintext)
    }
}

// 加密字段容器
struct EncryptedPayload: Codable {
    var notes: String?
    var url: String?
    var location: String?
    var alarms: [Alarm]?
    var recurrenceRules: [RecurrenceRule]?
    // CalendarEvent 额外字段
    var attendees: [Participant]?
}
```

---

## ConfigService.swift

```swift
struct CloudflareConfig: Codable {
    let apiURL: String
    let apiToken: String
    let keySource: KeySource  // .keychain / .environment

    enum KeySource: String, Codable {
        case keychain
        case environment
    }

    // 配置文件路径：~/.config/event/config.toml
    static func load() throws -> CloudflareConfig?
    static func save(_ config: CloudflareConfig) throws
}

actor ConfigService {
    static let shared = ConfigService()

    func loadConfig() throws -> CloudflareConfig
    func saveConfig(_ config: CloudflareConfig) throws

    // 加载加密主密钥
    func loadEncryptionKey(config: CloudflareConfig) throws -> SymmetricKey {
        switch config.keySource {
        case .keychain:
            #if os(macOS)
            return try loadFromKeychain()
            #else
            fatalError("Keychain not available on Linux")
            #endif
        case .environment:
            guard let b64 = ProcessInfo.processInfo.environment["EVENT_ENCRYPTION_KEY"],
                  let keyData = Data(base64Encoded: b64) else {
                throw EventCLIError.invalidInput("EVENT_ENCRYPTION_KEY 环境变量未设置")
            }
            return SymmetricKey(data: keyData)
        }
    }
}
```

---

## SyncService.swift（macOS 专用）

```swift
#if os(macOS)
import EventKit

actor SyncService {
    private let reminderService: ReminderService
    private let calendarService: CalendarService
    private let cloudflareClient: CloudflareClient
    private var lastSyncVersion: Int = 0

    // 监听 EventKit 变化
    func startObserving() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { try? await self?.syncNow() }
        }
    }

    // 执行双向同步
    func syncNow() async throws {
        let cloudChanges = try await fetchCloudChanges(sinceVersion: lastSyncVersion)
        let localChanges = try await collectLocalChanges()
        let resolved = resolveConflicts(local: localChanges, cloud: cloudChanges)

        // 推送本地变更
        if !resolved.toUpload.isEmpty {
            try await cloudflareClient.post("/api/v1/reminders/batch", body: resolved.toUpload)
        }
        // 应用云端变更到 EventKit
        for change in resolved.toApplyLocally {
            try await applyToEventKit(change)
        }
        // 更新同步状态
        lastSyncVersion = try await cloudflareClient.get("/api/v1/sync/version")
    }

    // LWW 冲突解决
    private func resolveConflicts(
        local: [ReminderChange],
        cloud: [ReminderChange]
    ) -> SyncResolution {
        // 比较 last_modified_date，较新的胜出
        // ...
    }
}
#endif
```

---

## SyncCommands.swift

```swift
struct SyncCommands: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "管理 Cloudflare 同步",
        subcommands: [Init.self, Status.self, Push.self, Pull.self, Daemon.self]
    )

    struct Init: ParsableCommand {
        @Option(help: "Cloudflare Workers URL") var url: String
        @Option(help: "API Token") var token: String
        @Flag(help: "生成新的加密密钥") var generateKey: Bool = false

        func run() throws {
            // 保存配置，生成并存储加密密钥
        }
    }

    struct Status: AsyncParsableCommand {
        func run() async throws {
            // 显示：上次同步时间，本地变更数量，云端版本号
        }
    }

    struct Push: AsyncParsableCommand { ... }
    struct Pull: AsyncParsableCommand { ... }

    #if os(macOS)
    struct Daemon: ParsableCommand {
        @Argument var action: DaemonAction  // start / stop / status
        func run() throws { ... }
    }
    #endif
}
```

---

## Cloudflare Workers（TypeScript）

```
cloudflare/
├── src/
│   ├── index.ts            # Hono app 入口
│   ├── routes/
│   │   ├── reminders.ts    # /api/v1/reminders 路由
│   │   ├── events.ts       # /api/v1/events 路由
│   │   └── sync.ts         # /api/v1/sync 路由
│   ├── middleware/
│   │   └── auth.ts         # Bearer Token 验证
│   └── db/
│       └── schema.sql      # D1 初始化 SQL
├── wrangler.toml
└── package.json
```

### wrangler.toml

```toml
name = "event-sync"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "DB"
database_name = "event-sync-db"
database_id = "your-database-id"

[vars]
API_TOKEN = ""  # 通过 wrangler secret put API_TOKEN 设置
```

### Hono.js 路由示例

```typescript
import { Hono } from 'hono'
import { bearerAuth } from 'hono/bearer-auth'

const app = new Hono<{ Bindings: { DB: D1Database, API_TOKEN: string } }>()

// 全局认证
app.use('/api/*', async (c, next) => {
    const token = c.req.header('Authorization')?.replace('Bearer ', '')
    if (token !== c.env.API_TOKEN) return c.json({ error: 'Unauthorized' }, 401)
    await next()
})

// 查询任务
app.get('/api/v1/reminders', async (c) => {
    const { list, completed, since_version } = c.req.query()
    let query = 'SELECT * FROM reminders WHERE deleted_at IS NULL'
    const params: any[] = []

    if (list) { query += ' AND list_name = ?'; params.push(list) }
    if (completed !== undefined) { query += ' AND is_completed = ?'; params.push(completed === 'true' ? 1 : 0) }
    if (since_version) { query += ' AND sync_version > ?'; params.push(parseInt(since_version)) }

    const result = await c.env.DB.prepare(query).bind(...params).all()
    return c.json(result.results)
})

// 批量同步
app.post('/api/v1/reminders/batch', async (c) => {
    const changes: ReminderChange[] = await c.req.json()
    const nextVersion = await getNextSyncVersion(c.env.DB)

    for (const change of changes) {
        if (change.action === 'delete') {
            await c.env.DB.prepare(
                'UPDATE reminders SET deleted_at = ?, sync_version = ? WHERE id = ?'
            ).bind(new Date().toISOString(), nextVersion, change.id).run()
        } else {
            await upsertReminder(c.env.DB, change.reminder, nextVersion)
        }
    }
    return c.json({ sync_version: nextVersion })
})
```

---

## 平台分支总结

| 功能 | macOS | Linux |
|------|-------|-------|
| 数据读写 | EventKit → D1 双向同步 | 直接操作 D1 |
| 加密密钥 | macOS Keychain | `EVENT_ENCRYPTION_KEY` 环境变量 |
| 自动同步 | `EKEventStoreChanged` 监听 | N/A（仅 API 触发） |
| 后台守护进程 | `event sync daemon start` | N/A |
| 编译条件 | `#if os(macOS)` | `#if !os(macOS)` 或 `#if os(Linux)` |
