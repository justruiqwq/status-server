# 设备状态管理 API

## 运行项目

```bash
cargo run
```

## API 接口

### POST /api/upload

上传设备状态

**请求参数:**
```json
{
  "token": "your_secret_token_here",
  "device_id": "device_001",
  "status": "alive",
  "exe": "app.exe"
}
```

**响应示例:**
```json
{
  "success": true,
  "message": "Device device_001 status updated"
}
```

**错误响应:**
```json
{
  "success": false,
  "error": "Invalid token"
}
```

### GET /api/status/{device_id}

获取设备状态(如果设备超过5分钟未上报,则返回 dead 状态)

**响应示例:**
```json
{
  "success": true,
  "device_id": "device_001",
  "status": "alive",
  "exe": "app.exe"
}
```

**设备不存在:**
```json
{
  "success": false,
  "error": "Device device_001 not found"
}
```

## 测试示例

上传设备状态:
```bash
curl -X POST http://127.0.0.1:8080/api/upload \
  -H "Content-Type: application/json" \
  -d '{
    "token": "your_secret_token_here",
    "device_id": "device_001",
    "status": "alive",
    "exe": "monitor.exe"
  }'
```

获取设备状态:
```bash
curl http://127.0.0.1:8080/api/status/device_001
```

## 配置

修改 `src/main.rs` 中的 `VALID_TOKEN` 常量来设置你的验证 token。
