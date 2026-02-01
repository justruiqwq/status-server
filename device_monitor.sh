#!/system/bin/sh

# 配置参数
API_URL="http://your-server-ip:8080/api/upload"
TOKEN="RuiFeng@246579@Device"
DEVICE_ID="android_device_001"  # 修改为你的设备ID
CHECK_INTERVAL=30  # 检查间隔(秒)

# 当前activity缓存
LAST_ACTIVITY=""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 获取当前前台activity
get_current_activity() {
    dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp' | head -n 1 | sed 's/.*{\|}\|mCurrentFocus=\|mFocusedApp=//g' | awk '{print $NF}'
}

# 上传设备状态
upload_status() {
    local status="$1"
    local exe="$2"
    
    local json_data="{\"token\":\"$TOKEN\",\"device_id\":\"$DEVICE_ID\",\"status\":\"$status\",\"exe\":\"$exe\"}"
    
    local response=$(curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "$json_data" \
        --connect-timeout 5 \
        --max-time 10)
    
    if [ $? -eq 0 ]; then
        log "上传成功: status=$status, exe=$exe"
    else
        log "上传失败"
    fi
}

log "设备监控脚本启动 - Device ID: $DEVICE_ID"

# 主循环
while true; do
    # 获取当前activity
    CURRENT_ACTIVITY=$(get_current_activity)
    
    # 如果获取失败,使用默认值
    if [ -z "$CURRENT_ACTIVITY" ]; then
        CURRENT_ACTIVITY="unknown"
    fi
    
    # 检查activity是否变化
    if [ "$CURRENT_ACTIVITY" != "$LAST_ACTIVITY" ]; then
        log "检测到Activity变化: $LAST_ACTIVITY -> $CURRENT_ACTIVITY"
        
        # 上传状态
        upload_status "alive" "$CURRENT_ACTIVITY"
        
        # 更新缓存
        LAST_ACTIVITY="$CURRENT_ACTIVITY"
    fi
    
    # 等待下一次检查
    sleep $CHECK_INTERVAL
done
