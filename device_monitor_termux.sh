#!/data/data/com.termux/files/usr/bin/bash
# Root Needed
 
# 配置参数
API_URL="你的API"
TOKEN="你的Key"
DEVICE_ID=""  # 修改为你的设备ID
CHECK_INTERVAL=1  # 检查间隔(秒)
DEAD_TIMEOUT=600  # 10分钟 = 600秒

# 当前activity缓存
LAST_ACTIVITY=""
LAST_CHANGE_TIME=0  # 上次变化时间戳

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 通过包名获取应用名称
get_app_name_by_package() {
    local package="$1"
    
    if [ -z "$package" ] || [ "$package" = "unknown" ]; then
        echo "unknown"
        return
    fi
    
    # 使用 dumpsys package 获取 labelRes
    local label_res=$(dumpsys package "$package" 2>/dev/null | grep "labelRes" | head -n 1 | cut -d '=' -f 2 | sed 's/ //g')
    
    if [ -n "$label_res" ] && [ "$label_res" != "0x0" ]; then
        # 尝试通过 aapt 或其他方式获取实际标签
        # 但由于 Termux 可能没有 aapt，我们尝试其他方法
        local app_name=$(cmd package resolve-activity -c android.intent.category.LAUNCHER "$package" 2>/dev/null | grep 'label=' | sed 's/.*label=//' | awk -F"'" '{print $2}' | head -n 1)
        
        if [ -n "$app_name" ] && [ "$app_name" != "$package" ]; then
            echo "$app_name"
            return
        fi
    fi
    
    # 备选方案：直接从 dumpsys package 获取 label 字符串
    local app_label=$(dumpsys package "$package" 2>/dev/null | grep -E "label=" | head -n 1 | sed 's/.*label=//' | awk '{print $1}')
    
    if [ -n "$app_label" ] && [ "$app_label" != "$package" ]; then
        echo "$app_label"
        return
    fi
    
    # 如果获取失败，返回包名
    echo "$package"
}

# 获取当前前台包名和应用名称
get_current_activity() {
    # 获取 mFocusedApp 或 mFocusedWindow
    # 格式: mFocusedApp=ActivityRecord{xxx u0 com.termux/.app.TermuxActivity t2247}
    local focus_line=$(dumpsys window 2>/dev/null | grep -i 'mFocusedApp\|mFocusedWindow' | head -n 1)
    
    if [ -n "$focus_line" ]; then
        # 只提取包名，不要Activity名称
        # 从 u0 后面提取到 / 之前，格式: com.termux
        local package=$(echo "$focus_line" | grep -oE 'u[0-9]+ [a-zA-Z0-9\.]+/' | awk '{print $2}' | tr -d '/')
        
        if [ -n "$package" ]; then
            # 尝试获取应用名称
            local app_name=$(get_app_name_by_package "$package")
            echo "$app_name"
            return
        fi
    fi
    
    echo "unknown"
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
        log "✓ 上传成功: status=$status, exe=$exe"
        echo "$response" | grep -q "success" && log "  服务器响应正常"
    else
        log "✗ 上传失败"
    fi
}

# 检查网络连接
check_network() {
    curl -s --connect-timeout 3 --max-time 5 "$API_URL" >/dev/null 2>&1
    return $?
}

log "========================================="
log "设备监控脚本启动"
log "Device ID: $DEVICE_ID"
log "Server: $API_URL"
log "Check Interval: ${CHECK_INTERVAL}s"
log "========================================="

# 检查网络
if ! check_network; then
    log "警告: 无法连接到服务器，请检查网络和服务器地址"
fi

# 首次上传
CURRENT_ACTIVITY=$(get_current_activity)
upload_status "alive" "$CURRENT_ACTIVITY"
LAST_ACTIVITY="$CURRENT_ACTIVITY"
LAST_CHANGE_TIME=$(date +%s)

# 主循环
while true; do
    sleep $CHECK_INTERVAL
    
    # 获取当前activity
    CURRENT_ACTIVITY=$(get_current_activity)
    
    # 如果获取失败,使用默认值
    if [ -z "$CURRENT_ACTIVITY" ]; then
        CURRENT_ACTIVITY="unknown"
    fi
    
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_CHANGE_TIME))
    
    # 检查activity是否变化
    if [ "$CURRENT_ACTIVITY" != "$LAST_ACTIVITY" ]; then
        log "Activity变化: $LAST_ACTIVITY -> $CURRENT_ACTIVITY"
        
        # 上传状态
        upload_status "alive" "$CURRENT_ACTIVITY"
        
        # 更新缓存
        LAST_ACTIVITY="$CURRENT_ACTIVITY"
        LAST_CHANGE_TIME=$CURRENT_TIME
    else
        # 检查是否超过10分钟未变化
        if [ $TIME_DIFF -ge $DEAD_TIMEOUT ]; then
            log "警告: Activity超过10分钟未变化，标记为 dead"
            upload_status "dead" "$CURRENT_ACTIVITY"
            # 重置时间，避免重复上传
            LAST_CHANGE_TIME=$CURRENT_TIME
        else
            log "Activity未变化: $CURRENT_ACTIVITY (已 ${TIME_DIFF}s)"
        fi
    fi
done
