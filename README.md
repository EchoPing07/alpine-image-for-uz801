# alpine-image-for-uz801

为 UZ801 设备定制的 Alpine Linux 系统镜像。

超低系统占用；支持 CPU 超频；去除蜂窝网络模块释放内存。

## 环境要求

- **Linux**（物理机或虚拟机均可）
- **Windows**（已内置 adb/fastboot 工具，无需额外安装）
- UZ801 设备

## 刷入 Alpine

> [!WARNING]
> 以下操作可能会破坏您的设备，使其无法启动。谨慎行事，风险自负！确保开始前已对原始固件进行备份！

### Windows

从 [Releases](https://github.com/EchoPing07/alpine-image-for-uz801/releases) 页面下载最新的 Windows 刷机包，解压后双击 `一键刷入.bat`，按照提示操作即可。

也可以克隆本仓库后直接运行：
```
git clone https://github.com/EchoPing07/alpine-image-for-uz801.git
cd alpine-image-for-uz801
一键刷入.bat
```

刷机流程为三段式：刷写 aboot 并重启 → 刷写所有分区并重启 → 刷写 boot 和根文件系统并重启。每阶段重启后需等待设备自动重新进入 Fastboot 模式，如未自动进入请手动操作。

### Linux

克隆本仓库，执行 flash.sh 脚本，按照提示刷入即可：
```
git clone https://github.com/EchoPing07/alpine-image-for-uz801.git && cd alpine-image-for-uz801 && chmod +x ./flash.sh && ./flash.sh
```

## 登录 Alpine

- 查看 Alpine 设备 IP 信息：
  ```
  ip addr
  ```
  示例输出：
  ```
  3: usb0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether ea:66:5e:5c:a0:f6 brd ff:ff:ff:ff:ff:ff
  ```

- 如上所示 `usb0` 没有 IP 地址，则执行以下命令，否则略过：
  ```
  dhclient usb0
  ip addr show usb0
  ```

- SSH 登录（默认密码：`uz801`）：
  ```
  ssh root@192.168.5.1
  ```

- 连接 Wi-Fi：SSH 登录后执行 `nmtui`，先删除 Wi-Fi 下的热点，然后连接自己的 Wi-Fi 即可。

## 自定义配置

#### LED 灯设置
```
vi /etc/local.d/00-leds.start
```

#### 开机执行脚本
```
vi /etc/local.d/10-myservice.start
```

#### 关机执行脚本
```
vi /etc/local.d/10-myservice.stop
```

## 自动发布

本仓库配置了 GitHub Actions 工作流，创建 Release 时会自动构建并上传两个刷机包：

- `alpine-uz801-linux-<时间戳>.zip` — 包含 Linux 刷机脚本及全部固件文件
- `alpine-uz801-windows-<时间戳>.zip` — 包含 Windows 刷机脚本、adb/fastboot 工具及全部固件文件

## 致谢

参考项目：[OpenStick-Builder](https://github.com/kinsamanka/OpenStick-Builder)、[alpine-image-for-uz801](https://github.com/kshipeng/alpine-image-for-uz801)
