# Android 设备监控安装说明

## 前提条件
- 设备已 Root
- 安装 BusyBox 或 curl (可以通过 Termux 或其他方式安装)
- 设备能访问服务器网络

## 安装步骤

### 1. 推送脚本到设备
```bash
adb push device_monitor.sh /data/local/tmp/
```

### 2. 修改配置
修改 `device_monitor.sh` 中的配置:
```sh
API_URL="http://192.168.1.100:8080/api/upload"  # 修改为你的服务器地址
DEVICE_ID="android_device_001"  # 修改为唯一的设备ID
CHECK_INTERVAL=30  # 检查间隔(秒)
```

### 3. 进入设备 Shell
```bash
adb shell
su  # 切换到 root
```

### 4. 设置权限并运行
```bash
cd /data/local/tmp
chmod +x device_monitor.sh
nohup ./device_monitor.sh > /data/local/tmp/monitor.log 2>&1 &
```

### 5. 查看日志
```bash
tail -f /data/local/tmp/monitor.log
```

### 6. 停止监控
```bash
ps | grep device_monitor.sh
kill <PID>
```

## 开机自启动 (可选)

### 方法1: 使用 init.d (需要支持)
```bash
# 复制脚本到 init.d 目录
cp /data/local/tmp/device_monitor.sh /system/etc/init.d/99monitor
chmod 755 /system/etc/init.d/99monitor
```

### 方法2: 使用 Magisk 模块
创建 Magisk 模块的 service.sh:
```bash
#!/system/bin/sh
/data/local/tmp/device_monitor.sh &
```

## 测试

1. 启动脚本后切换不同的 APP
2. 在服务器端查询设备状态:
```bash
curl http://localhost:8080/api/status/android_device_001
```

## 故障排查

### 如果 curl 不存在
```bash
# 使用 wget 替代 (修改脚本中的 upload_status 函数)
wget -qO- --post-data="$json_data" \
  --header="Content-Type: application/json" \
  "$API_URL"
```

### 使用 Termux (推荐)
```bash
# 在 Termux 中安装
pkg install curl
pkg install termux-api

# 运行脚本
sh device_monitor.sh
```

## 多设备部署

每台设备使用不同的 `DEVICE_ID`:
- android_device_001
- android_device_002
- android_device_003
...
