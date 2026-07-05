#!/bin/sh -e

printf "\033[31m⚠️  警告: 以下操作可能会破坏您的设备，使其无法启动。谨慎行事，风险自负！\033[0m \n"
echo "确保开始前已对原始固件进行备份！"
read -p "是否继续？([y]/n)..." user_input

if [ ! -z "$user_input" ] && [ "$user_input" != "y" ] && [ "$user_input" != "Y" ]; then
    echo "已取消操作"
    exit 0
fi

TEMP_FILES=""
cleanup() {
    echo "\n清理临时文件..."
    for temp_file in $TEMP_FILES; do
        if [ -f "$temp_file" ]; then
            rm -f "$temp_file"
            echo "已删除: $temp_file"
        fi
    done
    echo "清理完成"
    exit $1
}
trap 'cleanup $?' EXIT
trap 'cleanup 130' INT TERM

# 检查是否安装edl
if command -v edl >/dev/null 2>&1; then
    echo "✅edl 工具已安装在 $(which edl)，继续执行..."
else
    echo "🔧正在安装 edl 工具..."
    sudo apt update
    sudo apt install -y adb fastboot python3-dev python3-pip liblzma-dev git
    sudo apt purge -y modemmanager
    sudo systemctl stop ModemManager
    sudo systemctl disable ModemManager
    git clone https://github.com/bkerler/edl.git
    cd edl
    git submodule update --init --recursive
    chmod +x ./install-linux-edl-drivers.sh
    bash ./install-linux-edl-drivers.sh
    python3 setup.py build
    sudo python3 setup.py install

    # 验证edl是否安装成功
    if ! command -v edl &> /dev/null; then
        echo "❌ edl 工具安装失败！可手动安装\nhttps://github.com/bkerler/edl"
        exit 1
    else
        echo "✅edl 工具安装成功！"
    fi
fi

check_adb_device() {
    local server_output=$(adb start-server)
    local devices_output=$(adb devices)
    local device_count=$(echo "$devices_output" | grep -v "List of devices attached" | grep -v "^$" | wc -l)
    if [ "$device_count" -eq 0 ]; then
        return 1
    else
        if echo "$devices_output" | grep -q "device$"; then
            return 0
        fi
    fi
    return 4
}

check_edl_device() {
    local retries=200
    local count=1
    echo "\n开始检测 EDL (9008) 设备..."
    while [ $count -lt $retries ]; do
        if check_adb_device; then
            adb reboot edl
        fi
        if EDL_DEVICE=$(lsusb | grep -i "05c6:9008"); then
            echo "\n    ✅检测到 EDL (9008) 设备: $EDL_DEVICE"
            sleep 5
            return 0
        fi
        
        printf "\r    ⏳等待 EDL (9008) 设备连接（按 Ctrl+C 终止）... (%d/%d)" $((count + 1)) $retries
        count=$((count + 1))
        sleep 1
    done
    echo "\n    ❌等待 EDL (9008) 设备超时"
    exit 1
}

check_fastboot_device() {
    local retries=200
    local count=1
    echo "\n开始检测 Fastboot 设备..."
    echo "\n【如果已经擦除了 boot, 直接插入设备即可】"
    while [ $count -lt $retries ]; do
        if check_adb_device; then
            adb reboot bootloader
        fi
        if fastboot_device=$(fastboot devices | grep -v "^$" | cut -f1) && [ -n "$fastboot_device" ]; then
            echo "\n    📱检测到 Fastboot 设备: $fastboot_device"
            sleep 5
            return 0
        fi
        printf "\r    ⏳等待 Fastboot 设备连接（按 Ctrl+C 终止）... (%d/%d)" $((count + 1)) $retries
        count=$((count + 1))
        sleep 1
    done
    echo "\n    ❌ 等待 Fastboot 设备超时"
    exit 1
}

start_flash() {
    await_edl_disconnect
    check_fastboot_device
    for i in $(seq 10 -1 1); do
        printf "\r（%d）秒后开始刷机（按 Ctrl+C 终止）..." "$i"
        sleep 1
    done
    echo "\n开始刷机..."
    fastboot flash partition gpt_both0.bin
    fastboot flash aboot aboot.mbn
    fastboot flash hyp hyp.mbn
    fastboot flash rpm rpm.mbn
    fastboot flash sbl1 sbl1.mbn
    fastboot flash tz tz.mbn
    fastboot flash boot boot.bin
    for n in fsc fsg modem modemst1 modemst2 persist sec; do
        fastboot flash ${n} ${n}.bin
    done
    echo "\n当前时间: $(date "+%Y-%m-%d %H:%M:%S")\n时间较长: 【780秒左右】请耐心等待...\n预计时间: $(date -d "780 seconds" +"%Y-%m-%d %H:%M:%S") 完成\n"
    fastboot flash rootfs alpine_rootfs.bin
    
    echo "\n🎉 刷机完成: $(date "+%Y-%m-%d %H:%M:%S")\n5秒后重启设备..."
    sleep 5
    fastboot reboot
    exit 0
}

await_edl_disconnect() {
    local await_time=0
    while lsusb | grep -q "05c6:9008"; do
        printf "\r    ⏳请拔出设备（按 Ctrl+C 终止）(%d)..." $((await_time + 1))
        await_time=$((await_time + 1))
        sleep 1
    done
    echo "\n    ✅设备已断开"
}

f_boot() {
    await_edl_disconnect
    check_edl_device
    echo "\n⏳正在通过 EDL 擦除 boot..."
    temp_output=$(mktemp)
    TEMP_FILES="$TEMP_FILES $temp_output"
    if edl e boot > "$temp_output" 2>&1; then
        if grep -q "Erased" "$temp_output"; then
            echo "    ✅通过 EDL 擦除 boot 成功"
            rm -f "$temp_output"
            return 0
        fi
    fi
    echo "    ❌boot 擦除失败（9008模式每次使用后都要重新进入）"
    echo "    📝错误日志:"
    cat "$temp_output"
    rm -f "$temp_output"
    exit 1
}

w_aboot() {
    await_edl_disconnect
    check_edl_device
    echo "\n⏳正在通过 EDL 刷写 aboot..."
    temp_output=$(mktemp)
    TEMP_FILES="$TEMP_FILES $temp_output"
    if edl w aboot aboot.mbn > "$temp_output" 2>&1; then
        # 检查输出中是否包含成功信息
        if grep -q "Wrote aboot.mbn to sector" "$temp_output"; then
            echo "    ✅通过 EDL 刷写 aboot 成功"
            rm -f "$temp_output"
            return 0
        fi
    fi
    echo "    ❌aboot 刷写失败（9008模式每次使用后都要重新进入）"
    echo "    📝错误日志:"
    cat "$temp_output"
    rm -f "$temp_output"
    exit 1
}

backup() {
    local backup_files="fsc.bin fsg.bin modem.bin modemst1.bin modemst2.bin persist.bin sec.bin"
    local all_exist=true
    for file in $backup_files; do
        if [ ! -f "$file" ]; then
            all_exist=false
            break
        fi
    done
    if [ "$all_exist" = true ]; then
        echo "\n✅所有备份文件已存在，跳过备份步骤"
        return 0
    else
        echo "\n📱开始备份所需的原始固件【modem、persist用时较长】..."
    fi
    check_edl_device
    for n in fsc fsg modem modemst1 modemst2 persist sec; do
        echo "\n⏳正在通过 EDL 备份 ${n}..."
        temp_output=$(mktemp)
        TEMP_FILES="$TEMP_FILES $temp_output"
        if edl r ${n} ${n}.bin > "$temp_output" 2>&1; then
            if grep -q "Done" "$temp_output" || grep -q "Success" "$temp_output"; then
                echo "    ✅通过 EDL 备份 ${n} 成功"
                rm -f "$temp_output"
                await_edl_disconnect
                if check_edl_device; then
                    continue
                fi
            fi
        fi
        
        # 如果执行失败，显示错误信息
        echo "    ❌备份 ${n} 失败（9008模式每次使用后都要重新进入）"
        echo "    📝错误日志:"
        cat "$temp_output"
        rm -f "$temp_output"
        exit 1
    done
    echo "✅所有分区备份完成"
    return 0
}

main() {
    if fastboot_device=$(fastboot devices | grep -v "^$" | cut -f1) && [ -n "$fastboot_device" ]; then
        echo "\n📱检测到 Fastboot 设备: $fastboot_device"
        backup
        start_flash
    else
        backup
        w_aboot
        f_boot
        start_flash
    fi
}

main
