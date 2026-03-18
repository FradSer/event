# BDD 规格说明

## 需求追踪矩阵

| 需求 ID | 场景 |
|---------|------|
| R1 | Mac 端读写（F-1 Reminders, F-2 Calendar） |
| R2 | Linux 端读写（F-3 Reminders, F-4 Calendar） |
| R3 | 跨平台编译（E-1） |
| R4 | E2EE 加密（S-1, S-2） |
| R5 | Mac 自动同步（F-5） |
| R6 | sync 命令（F-6） |
| R7 | 冲突解决（C-1, C-2, C-3） |
| R8 | Workers CRUD API（F-3, F-4） |
| R9 | Bearer Token 认证（S-3） |
| R10 | 离线操作（E-2） |
| R11 | 密钥管理（S-1, S-4） |

---

## Feature: Mac 端操作（F-1）

```gherkin
Feature: Mac 端通过 EventKit 管理任务
  作为 Mac 用户
  我希望 event CLI 直接操作 Apple Reminders
  以便数据同时出现在 Apple 生态和云端

  Background:
    Given 用户已在 Mac 上安装 event CLI
    And 用户已授予 EventKit 权限
    And 用户已通过 event sync init 配置 Cloudflare

  Scenario: 在 Mac 上创建任务后同步到云端（F-1-1）
    Given 云端数据库当前有 0 条任务
    When 用户运行 event reminders create --title "买牛奶" --list "购物"
    Then EventKit 中创建了一条新 Reminder
    And 该任务在 5 秒内同步到 Cloudflare D1
    And D1 中的 title 字段为 "买牛奶"
    And D1 中的 encrypted_payload 不为空
    And D1 中的 encrypted_iv 不为空

  Scenario: 在 Mac 上查询任务（F-1-2）
    Given EventKit 中有 3 条 "工作" 列表的任务
    When 用户运行 event reminders list --list "工作"
    Then 输出包含所有 3 条任务
    And 数据来源为 EventKit（不发起 HTTP 请求）

  Scenario: 在 Mac 上删除任务（F-1-3）
    Given EventKit 中存在 ID 为 "ABC123" 的任务
    And 该任务已同步到 D1
    When 用户运行 event reminders delete --id "ABC123"
    Then EventKit 中该任务被删除
    And D1 中该记录的 deleted_at 字段被设置
    And D1 中该记录仍然存在（软删除）
```

---

## Feature: Linux 端操作（F-3）

```gherkin
Feature: Linux 端通过 Cloudflare D1 管理任务
  作为云端 AI Agent（运行于 Linux）
  我希望 event CLI 直接操作 Cloudflare D1
  以便在非 macOS 环境中管理日历和任务

  Background:
    Given 用户已在 Linux 上安装 event CLI（Swift on Linux 编译）
    And 环境变量 CLOUDFLARE_API_URL 已设置
    And 环境变量 CLOUDFLARE_API_TOKEN 已设置
    And 环境变量 EVENT_ENCRYPTION_KEY 已设置

  Scenario: Linux 端查询任务（F-3-1）
    Given D1 中有 2 条 "工作" 列表的未完成任务
    When 用户运行 event reminders list --list "工作"
    Then CLI 向 Cloudflare Workers 发起 GET /api/v1/reminders?list=工作 请求
    And 输出包含 2 条任务
    And encrypted_payload 字段已在本地解密后呈现

  Scenario: Linux 端创建任务（F-3-2）
    Given D1 中 "工作" 列表有 2 条任务
    When 用户运行 event reminders create --title "写报告" --list "工作" --notes "机密内容"
    Then CLI 向 Cloudflare Workers 发起 POST /api/v1/reminders 请求
    And 请求体中的 title 字段为明文 "写报告"
    And 请求体中的 encrypted_payload 包含加密后的 notes "机密内容"
    And D1 中新增一条记录
    And 返回新任务的 ID

  Scenario: Linux 端更新任务完成状态（F-3-3）
    Given D1 中存在 ID 为 "XYZ456" 的未完成任务
    When 用户运行 event reminders update --id "XYZ456" --completed
    Then CLI 向 Workers 发起 PUT /api/v1/reminders/XYZ456 请求
    And D1 中该记录的 is_completed 字段更新为 1
    And D1 中该记录的 last_modified_date 更新为当前时间
    And D1 中该记录的 sync_version 递增
```

---

## Feature: 双向同步（F-5）

```gherkin
Feature: Mac 和 Linux 之间数据双向同步
  作为使用多设备的用户
  我希望在任一端的修改都能同步到另一端
  以便始终看到最新数据

  Scenario: Mac 修改任务，Linux 读到最新（F-5-1）
    Given Mac 和 Linux 都有 ID 为 "T001" 的任务，title 为 "开会"
    And 两端的 sync_version 均为 5
    When Mac 用户运行 event reminders update --id "T001" --title "开周会"
    And Mac 端自动触发同步
    Then D1 中 "T001" 的 title 更新为 "开周会"，sync_version 为 6
    When Linux 用户运行 event reminders list
    Then 输出中 "T001" 的 title 为 "开周会"

  Scenario: Linux 创建任务，Mac 同步后可见（F-5-2）
    Given Mac 和 D1 已同步，sync_version = 10
    When Linux 用户运行 event reminders create --title "云端任务"
    And D1 中新任务 sync_version = 11
    And Mac 用户运行 event sync pull
    Then Mac EventKit 中出现新任务 "云端任务"
    And event reminders list 显示该任务
```

---

## Feature: 冲突解决（C-1）

```gherkin
Feature: Last-Write-Wins 冲突解决
  作为系统
  我希望在两端同时修改时自动选择最新版本
  以避免数据丢失

  Scenario: 两端同时修改同一任务，Mac 版本更新（C-1-1）
    Given ID 为 "T002" 的任务在 Mac 和 D1 上 last_modified_date 均为 "2026-03-19 10:00:00"
    When Mac 在 "2026-03-19 10:01:00" 修改 title 为 "Mac 版本"
    And Linux 在 "2026-03-19 10:00:30" 修改 title 为 "Linux 版本"
    And Mac 触发同步
    Then D1 中 "T002" 的 title 为 "Mac 版本"（因为时间戳更新）
    And Linux 下次查询时读到 "Mac 版本"

  Scenario: 云端已删除，本地有较新修改（C-2）
    Given D1 中 "T003" 的 deleted_at = "2026-03-19 09:00:00"
    When Mac 在 "2026-03-19 10:00:00" 修改该任务（本地修改时间更新）
    And Mac 触发同步
    Then 冲突解决选择保留 Mac 的修改
    And D1 中 "T003" 的 deleted_at 被清除
    And 该任务恢复可见

  Scenario: 本地已删除，云端有较新修改（C-3）
    Given Mac 在 "2026-03-19 09:00:00" 删除了 "T004"
    And 云端在 "2026-03-19 10:00:00" 修改了 "T004"（修改时间更新）
    When Mac 触发同步
    Then 冲突解决选择保留云端的修改
    And Mac EventKit 中恢复 "T004"
    And 本地删除操作被撤销
```

---

## Feature: 端到端加密（S-1）

```gherkin
Feature: 敏感字段端到端加密
  作为注重隐私的用户
  我希望 notes, url, location 等敏感内容在离开设备前加密
  以防 Cloudflare 服务器读取隐私数据

  Scenario: 创建含 notes 的任务时加密存储（S-1-1）
    Given 用户已配置加密主密钥
    When 用户创建任务，notes 为 "这是机密内容"
    Then D1 中该任务的 notes 字段为 NULL（未明文存储）
    And D1 中 encrypted_payload 字段不为空
    And encrypted_payload 的内容无法直接读取为明文
    And encrypted_iv 字段包含有效的 base64 编码 IV

  Scenario: 读取任务时自动解密（S-1-2）
    Given D1 中存在加密的任务（含 encrypted_payload）
    When 用户运行 event reminders list
    Then 输出中 notes 字段显示为解密后的明文
    And 解密使用本地主密钥

  Scenario: 无法使用错误密钥解密（S-1-3）
    Given D1 中存在用密钥 A 加密的任务
    When 用户使用密钥 B 运行 event reminders list
    Then CLI 报告解密失败错误
    And 不显示损坏的数据

  Scenario: AAD 防篡改保护（S-1-4）
    Given D1 中存在加密任务，record_id = "T005"
    When 攻击者将该加密内容复制到另一条记录 record_id = "T006"
    And 用户尝试读取 "T006"
    Then 解密失败（AAD 验证不通过，因为 record_id 不匹配）
```

---

## Feature: 认证（S-3）

```gherkin
Feature: API 认证保护
  作为系统管理员
  我希望只有持有有效 Token 的客户端能访问 API
  以防未授权访问

  Scenario: 有效 Token 可正常访问（S-3-1）
    Given 用户已配置正确的 API Token
    When 用户运行任何 event 命令（Linux 端）
    Then HTTP 请求包含 Authorization: Bearer <token>
    And Workers 返回 200 成功响应

  Scenario: 无效 Token 被拒绝（S-3-2）
    Given 用户配置了错误的 API Token
    When 用户运行 event reminders list（Linux 端）
    Then Workers 返回 401 Unauthorized
    And CLI 报告认证失败错误
    And 不显示任何数据

  Scenario: 缺少 Token 被拒绝（S-3-3）
    Given 用户未配置 API Token
    When 用户运行 event reminders list（Linux 端）
    Then CLI 报告配置缺失错误
    And 提示用户运行 event sync init
```

---

## Feature: 离线操作（E-2）

```gherkin
Feature: 网络断开时 Mac 端仍可操作
  作为 Mac 用户
  我希望在没有网络时仍能管理本地数据
  以避免网络故障影响正常使用

  Scenario: 网络断开时 Mac 仍可读写（E-2-1）
    Given 网络已断开
    When 用户运行 event reminders list
    Then 从 EventKit 返回数据（不依赖网络）
    When 用户创建新任务
    Then 任务创建成功（写入 EventKit）
    And 同步失败被静默处理（不报错给用户）
    And 同步失败事件记录到本地日志

  Scenario: 网络恢复后自动补同步（E-2-2）
    Given 网络断开期间 Mac 创建了 3 条新任务
    When 网络恢复
    And EKEventStoreChanged 触发同步
    Then 这 3 条任务被推送到 D1
    And D1 的 sync_version 递增 3

  Scenario: Linux 端网络断开时报错（E-2-3）
    Given Linux 端网络已断开
    When 用户运行 event reminders list
    Then CLI 报告网络连接失败错误
    And 错误信息提示检查网络或 Cloudflare Workers 状态
```

---

## Feature: Mac 端日历操作（F-2）

```gherkin
Feature: Mac 端通过 EventKit 管理日历事件
  作为 Mac 用户
  我希望 event CLI 直接操作 Apple Calendar
  以便日历事件同时出现在 Apple 生态和云端

  Background:
    Given 用户已在 Mac 上安装 event CLI
    And 用户已授予 EventKit 日历权限
    And 用户已通过 event sync init 配置 Cloudflare

  Scenario: 在 Mac 上查询日历事件（F-2-1）
    Given Apple Calendar 中本周有 3 个事件
    When 用户运行 event calendar list --start "2026-03-16" --end "2026-03-22"
    Then 输出包含 3 个事件
    And 数据来源为 EventKit（不发起 HTTP 请求）

  Scenario: 在 Mac 上创建日历事件后同步（F-2-2）
    Given 云端数据库当前有 0 个日历事件
    When 用户通过 Apple Calendar 创建一个新事件"团队会议"
    And Mac 端 EKEventStoreChanged 触发自动同步
    Then D1 calendar_events 表中新增该事件
    And D1 中 title 为 "团队会议"
    And D1 中 encrypted_payload 包含加密的 notes 和 location
```

---

## Feature: Linux 端日历操作（F-4）

```gherkin
Feature: Linux 端通过 Cloudflare D1 管理日历事件
  作为云端 AI Agent（运行于 Linux）
  我希望 event CLI 能查询和创建日历事件
  以便在非 macOS 环境中管理日程

  Background:
    Given Linux 端已配置 Cloudflare 环境变量

  Scenario: Linux 端查询本周日历事件（F-4-1）
    Given D1 中本周有 2 个"工作"日历的事件
    When 用户运行 event calendar list --start "2026-03-16" --end "2026-03-22"
    Then CLI 向 Workers 发起 GET /api/v1/events?start=2026-03-16&end=2026-03-22 请求
    And 输出包含 2 个事件
    And encrypted_payload 已在本地解密，location 和 notes 可读

  Scenario: Linux 端创建日历事件（F-4-2）
    Given D1 中"工作"日历有 1 个事件
    When 用户运行 event calendar create --title "项目评审" --start "2026-03-20 14:00:00" --end "2026-03-20 15:00:00" --notes "内部机密会议"
    Then CLI 向 Workers 发起 POST /api/v1/events 请求
    And 请求体中 title 为明文 "项目评审"
    And 请求体中 encrypted_payload 包含加密后的 notes "内部机密会议"
    And D1 新增该事件记录
    And Mac 下次同步后 Apple Calendar 出现该事件

  Scenario: Linux 端查询全天事件（F-4-3）
    Given D1 中有一个全天事件，is_all_day = 1
    When 用户运行 event calendar list --start "2026-03-20" --end "2026-03-20"
    Then 该事件出现在输出中
    And 日期格式为 "yyyy-MM-dd"（无时间部分）
```

---

## Feature: 初始化配置（F-6）

```gherkin
Feature: 通过 event sync init 一键完成所有基建搭建
  作为新用户
  我希望只需登录一次 Cloudflare，然后运行一条命令
  以便自动完成所有配置，无需手动操作 Cloudflare 控制台

  Background:
    Given 用户已安装 wrangler CLI
    And 用户已运行 wrangler login（完成 OAuth 授权）

  Scenario: 首次初始化（F-6-1）
    Given 用户首次运行 event sync init
    Then CLI 通过 Cloudflare API 自动创建 D1 数据库 "event-sync-db"
    And CLI 自动初始化数据库 Schema
    And CLI 将 Worker 代码上传并部署到 Cloudflare
    And CLI 随机生成 Bearer Token 并写入 Worker secret（用户不可见）
    And CLI 生成 AES-256 加密主密钥并存入 macOS Keychain
    And Worker URL 保存到 ~/.config/event/config.toml
    And 输出包含 Linux Agent 所需的三个环境变量：
      - CLOUDFLARE_API_URL
      - CLOUDFLARE_API_TOKEN
      - EVENT_ENCRYPTION_KEY

  Scenario: 初始化时 wrangler 未登录（F-6-2）
    Given 用户未运行 wrangler login
    When 用户运行 event sync init
    Then CLI 报告错误"请先运行 wrangler login"
    And 不执行任何 Cloudflare 操作

  Scenario: 重复初始化复用已有数据库（F-6-3）
    Given 用户已完成过 event sync init
    And D1 数据库 "event-sync-db" 已存在
    When 用户再次运行 event sync init
    Then CLI 复用已有的 D1 数据库（不重新创建）
    And CLI 重新部署 Worker（更新代码）
    And CLI 复用 Keychain 中的加密密钥（不重新生成）
    And 重新输出 Linux Agent 环境变量

  Scenario: 查看同步状态（F-6-4）
    Given 用户已完成 event sync init
    When 用户运行 event sync status
    Then 输出包含：
      - Cloudflare Workers URL
      - 上次同步时间
      - 本地待同步变更数量
      - 当前云端 sync_version
```
