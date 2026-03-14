# Token 导入 API 文档

## 概述

提供通过 HTTP API 导入 Claude 账号 Token 的功能，支持前端文件上传和外部系统集成。

---

## API 端点

### 导入账号

**端点：** `POST /auth/accounts/import`

**描述：** 导入单个账号的 Token 数据

**请求头：**
```
Content-Type: application/json
```

**请求体：**
```json
{
  "type": "string",
  "email": "string",
  "expired": "string",
  "id_token": "string",
  "account_id": "string",
  "access_token": "string",      // 必需
  "last_refresh": "string",
  "refresh_token": "string"
}
```

**字段说明：**
- `access_token` (必需): Claude 访问令牌
- `refresh_token` (可选): 刷新令牌，用于自动续期
- 其他字段为可选元数据

**成功响应：** `200 OK`
```json
{
  "success": true,
  "account": {
    "id": "abc123",
    "email": "user@example.com",
    "status": "active",
    "usage": {
      "requests": 0,
      "tokens": 0
    },
    "proxyId": "global",
    "proxyName": "Global Default"
  }
}
```

**错误响应：** `400 Bad Request`
```json
{
  "error": "Missing access_token in token file"
}
```

或

```json
{
  "error": "Invalid token file format"
}
```

---

## 使用示例

### cURL

```bash
curl -X POST http://localhost:8338/auth/accounts/import \
  -H "Content-Type: application/json" \
  -d '{
    "access_token": "eyJhbGc...",
    "refresh_token": "v1.abc...",
    "email": "user@example.com",
    "account_id": "user-123"
  }'
```

### JavaScript (Fetch)

```javascript
const response = await fetch('http://localhost:8338/auth/accounts/import', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    access_token: 'eyJhbGc...',
    refresh_token: 'v1.abc...',
    email: 'user@example.com',
    account_id: 'user-123'
  })
});

const result = await response.json();
if (result.success) {
  console.log('导入成功:', result.account);
} else {
  console.error('导入失败:', result.error);
}
```

### Python

```python
import requests

url = 'http://localhost:8338/auth/accounts/import'
data = {
    'access_token': 'eyJhbGc...',
    'refresh_token': 'v1.abc...',
    'email': 'user@example.com',
    'account_id': 'user-123'
}

response = requests.post(url, json=data)
result = response.json()

if result.get('success'):
    print('导入成功:', result['account'])
else:
    print('导入失败:', result.get('error'))
```

---

## 批量导入

如需批量导入多个账号，可以循环调用此 API：

```javascript
async function importMultipleAccounts(tokenFiles) {
  const results = [];

  for (const tokenData of tokenFiles) {
    try {
      const response = await fetch('http://localhost:8338/auth/accounts/import', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(tokenData)
      });

      const result = await response.json();
      results.push({ success: result.success, data: result });
    } catch (error) {
      results.push({ success: false, error: error.message });
    }
  }

  return results;
}
```

---

## 前端 UI 导入

前端提供了可视化的文件上传功能：

1. 访问 Web 界面（默认 `http://localhost:8338`）
2. 点击 "📁 导入 Token 文件" 按钮
3. 选择一个或多个 `.json` 格式的 Token 文件
4. 系统自动批量导入并刷新账号列表

**支持特性：**
- 多文件选择（按住 Ctrl/Shift 选择多个文件）
- 批量导入优化（统一刷新，避免界面闪烁）
- 导入结果统计（成功/失败数量）
- 错误详情记录（控制台输出）

---

## 启动时自动导入

服务器启动时会自动扫描 `token/` 目录并导入所有 `.json` 文件：

1. 在项目根目录创建 `token/` 文件夹
2. 将 Token JSON 文件放入该目录
3. 启动服务器，自动导入所有文件
4. 导入日志输出到控制台

**示例日志：**
```
[TokenImporter] Imported account from user1@example.com.json (entryId: abc123)
[TokenImporter] Imported account from user2@example.com.json (entryId: def456)
[TokenImporter] Successfully imported 2 account(s) from token directory
```

---

## Token 文件格式

标准 Token 文件格式（与 Claude 官方导出格式兼容）：

```json
{
  "type": "session_token",
  "email": "user@example.com",
  "expired": "2024-12-31T23:59:59Z",
  "id_token": "eyJhbGc...",
  "account_id": "user-123",
  "access_token": "eyJhbGc...",
  "last_refresh": "2024-01-01T00:00:00Z",
  "refresh_token": "v1.abc..."
}
```

**最小必需字段：**
```json
{
  "access_token": "eyJhbGc..."
}
```

---

## 注意事项

1. **前端刷新**：通过 API 直接导入后，前端不会自动刷新。需要：
   - 手动点击刷新按钮
   - 或实现轮询/WebSocket 推送机制

2. **Token 安全**：
   - Token 文件包含敏感信息，请妥善保管
   - 建议将 `token/` 目录添加到 `.gitignore`
   - 不要将 Token 提交到版本控制系统

3. **导入逻辑一致性**：
   - 前端 UI 导入、API 导入、启动自动导入使用相同的后端逻辑
   - 都会调用 `pool.addAccount()` 和 `scheduler.scheduleOne()`
   - 确保 Token 刷新调度一致

4. **错误处理**：
   - 缺少 `access_token` 返回 400 错误
   - JSON 格式错误返回 400 错误
   - 重复导入会创建新的账号实例（不会去重）

---

## 相关 API

- `GET /auth/accounts` - 获取所有账号列表
- `GET /auth/accounts?quota=true` - 获取账号列表（含配额信息）
- `DELETE /auth/accounts/:id` - 删除指定账号
- `POST /auth/accounts/:id/reset-usage` - 重置账号使用统计

---

## 更新日志

- **v1.0.45** (2024-03-14)
  - 新增 `POST /auth/accounts/import` API 端点
  - 前端支持多文件批量导入
  - 统一启动自动导入和手动导入的调度逻辑
