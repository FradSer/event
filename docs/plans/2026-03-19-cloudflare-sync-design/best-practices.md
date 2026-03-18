# 最佳实践与注意事项

## 安全

### 密钥管理

**macOS（Keychain）**
```swift
// 存储主密钥到 Keychain
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "com.event.encryption-key",
    kSecAttrAccount as String: "master",
    kSecValueData as String: keyData,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
]
```
- 使用 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`：只在设备解锁时可用，且不备份到 iCloud
- 不要使用 `kSecAttrAccessibleAlways`（即使锁屏也可读）

**Linux（环境变量）**
```bash
# 生成主密钥
openssl rand -base64 32

# 设置环境变量（推荐加入 ~/.bashrc 或密钥管理系统）
export EVENT_ENCRYPTION_KEY="<base64-encoded-256-bit-key>"
```
- 不要将密钥硬编码到配置文件
- 生产环境使用密钥管理服务（AWS Secrets Manager、Vault 等）

### API Token 安全

```toml
# config.toml 不存储 token 明文（改用系统凭据）
# macOS: 存储到 Keychain
# Linux: 通过环境变量 CLOUDFLARE_API_TOKEN
```

Cloudflare Workers 端：
```bash
# 使用 wrangler secret 设置，不在 wrangler.toml 明文暴露
wrangler secret put API_TOKEN
```

### HTTPS Only

- Workers 默认强制 HTTPS
- Swift CloudflareClient 中拒绝 HTTP URL：
```swift
guard url.scheme == "https" else {
    throw EventCLIError.invalidInput("API URL 必须使用 HTTPS")
}
```

---

## 加密实现注意事项

### IV 唯一性（Critical）
- 每次加密必须生成新的随机 IV，不能重用
- AES-GCM 在同一密钥下重用 IV 会完全破坏安全性
```swift
// 正确：每次加密生成新 IV
let nonce = try AES.GCM.Nonce()  // 随机生成

// 错误：不要固定 IV 或从记录 ID 派生
// let nonce = try AES.GCM.Nonce(data: recordId.data(...))  ❌
```

### AAD（附加认证数据）
- AAD 防止密文被复制到其他记录
- AAD 不加密但会参与认证计算
- AAD 变化（如记录被篡改）会导致解密失败
```swift
let aad = "\(recordId)|\(lastModifiedDate)".data(using: .utf8)!
```

### 加密字段选择原则
| 字段 | 是否加密 | 理由 |
|------|----------|------|
| title | 否 | 用于云端查询、AI 处理 |
| notes | 是 | 可能含敏感内容 |
| url | 是 | 可能含私人链接 |
| location | 是 | 地理位置隐私敏感 |
| alarms | 是 | 打包入 encrypted_payload |
| list_name | 否 | 用于过滤查询 |
| due_date | 否 | 用于时间范围查询 |
| is_completed | 否 | 用于状态过滤 |
| priority | 否 | 数值，不含隐私内容 |

---

## Swift on Linux 注意事项

### Foundation 差异
```swift
// URLSession 在 Swift on Linux 5.9+ 已内置支持 async/await
// 无需额外依赖

// 注意：某些 Foundation API 在 Linux 行为不同
// 使用 ISO 8601 日期格式，避免 locale 依赖
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
```

### CryptoKit vs swift-crypto
```swift
// 统一导入方式（在 Package.swift 中通过条件依赖处理）
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto  // swift-crypto，API 与 CryptoKit 完全兼容
#endif
```

### EventKit 条件编译
```swift
// 所有 EventKit 相关代码必须包裹在条件编译中
#if os(macOS)
import EventKit

actor ReminderService: RemindersBackend {
    // macOS 专用实现
}
#endif
```

---

## 性能

### 批量同步优化
```swift
// 不要逐条同步，使用批量 API
// 推荐：每次同步最多 100 条，分批处理
let batchSize = 100
let batches = changes.chunked(into: batchSize)
for batch in batches {
    try await client.post("/api/v1/reminders/batch", body: batch)
}
```

### D1 查询优化
```sql
-- 始终使用索引字段过滤
-- 避免全表扫描
SELECT * FROM reminders
WHERE list_name = ?          -- 使用 idx_reminders_list
  AND deleted_at IS NULL
  AND sync_version > ?        -- 使用 idx_reminders_version
LIMIT 100;
```

### 增量同步（避免全量拉取）
```swift
// 只拉取上次同步后的变更
let changes = try await client.get(
    "/api/v1/reminders",
    queryItems: [URLQueryItem(name: "since_version", value: "\(lastSyncVersion)")]
)
```

### Workers 免费额度管理
- 免费套餐：10 万次请求/天
- 单用户日常使用 < 1000 次，完全在免费额度内
- 避免轮询：使用事件驱动（EKEventStoreChanged）

---

## 错误处理

### 网络错误分类
```swift
enum SyncError: LocalizedError {
    case networkUnavailable          // 网络断开，Mac 端静默
    case authenticationFailed        // Token 无效
    case encryptionKeyMissing        // 密钥未配置
    case decryptionFailed(id: String) // 单条解密失败
    case conflictResolutionFailed    // 冲突解决异常

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "网络不可用，本地操作已保存，将在网络恢复后同步"
        case .authenticationFailed:
            return "认证失败，请检查 API Token（event sync init --token <new-token>）"
        case .encryptionKeyMissing:
            return "加密密钥未配置，请运行 event sync init"
        case .decryptionFailed(let id):
            return "记录 \(id) 解密失败，可能使用了不同的加密密钥"
        }
    }
}
```

### Mac 端静默同步失败
```swift
// 同步失败不应影响用户的日常操作
func syncInBackground() {
    Task {
        do {
            try await syncService.syncNow()
        } catch SyncError.networkUnavailable {
            // 静默处理，记录日志
            logger.info("Sync skipped: network unavailable")
        } catch {
            // 其他错误记录到 stderr
            fputs("Sync warning: \(error.localizedDescription)\n", stderr)
        }
    }
}
```

---

## Cloudflare D1 最佳实践

### 事务使用
```typescript
// 批量写入使用事务，确保原子性
await db.batch([
    db.prepare('UPDATE reminders SET ... WHERE id = ?').bind(...),
    db.prepare('UPDATE sync_state SET ... WHERE device_id = ?').bind(...),
])
```

### sync_version 全局递增
```typescript
// 使用数据库自增版本号，避免时钟漂移问题
async function getNextSyncVersion(db: D1Database): Promise<number> {
    const result = await db.prepare(
        'INSERT INTO sync_version (version) VALUES (NULL) RETURNING version'
    ).first<{ version: number }>()
    return result!.version
}
```

### 软删除不立即清理
```sql
-- 软删除记录保留 30 天，以处理长时间离线的设备
-- 定期清理（可通过 Cloudflare Cron Trigger 执行）
DELETE FROM reminders
WHERE deleted_at IS NOT NULL
  AND deleted_at < datetime('now', '-30 days');
```

---

## 测试策略

### 单元测试（不依赖网络）
- `EncryptionService` 加密/解密正确性
- 冲突解决逻辑（`SyncService.resolveConflicts`）
- `CloudflareReminderService` 的 DTO → Model 转换

### 集成测试（Mock HTTP）
- 使用 `URLProtocol` Mock 拦截 HTTP 请求
- 测试 `CloudflareClient` 的请求格式和认证头

### 端到端测试（需要真实 Cloudflare）
- 仅在 CI 中运行，需要设置测试用 Cloudflare 账户
- 测试完整同步流程

### BDD 场景执行
- 使用 XCTest + 自定义 Scenario DSL 实现 BDD 场景
- 场景文件：`Tests/eventTests/Sync/`

---

## 部署检查清单

### Cloudflare 初始化
```bash
# 1. 创建 D1 数据库
wrangler d1 create event-sync-db

# 2. 获取数据库 ID，更新 wrangler.toml

# 3. 初始化 Schema
wrangler d1 execute event-sync-db --file=cloudflare/src/db/schema.sql

# 4. 设置 API Token
wrangler secret put API_TOKEN

# 5. 部署 Workers
cd cloudflare && wrangler deploy

# 6. 验证部署
curl -H "Authorization: Bearer <token>" https://event-sync.workers.dev/api/v1/sync/version
```

### Mac 初始化
```bash
# 1. 初始化同步配置（生成并保存密钥）
event sync init --url https://event-sync.workers.dev --token <token>

# 2. 首次全量同步
event sync push   # 推送本地所有数据到云端
```

### Linux 初始化
```bash
# 1. 设置环境变量
export CLOUDFLARE_API_URL="https://event-sync.workers.dev"
export CLOUDFLARE_API_TOKEN="<token>"
export EVENT_ENCRYPTION_KEY="<base64-key>"  # 与 Mac 端相同密钥

# 2. 验证连接
event sync status
```
