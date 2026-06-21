# VPS Init CLI v2

新机器开机后一键配好开发环境的轻量菜单工具。
风格参考 [eooce/ssh_tool](https://github.com/eooce/ssh_tool)，紧凑两列布局。

---

## 特性

- **11 个核心功能**：基础环境、Docker、SSH 加固、防火墙、服务管理
- **5 个子菜单**：组件 / Docker / SSH / 防火墙 / 服务
- **顶部状态栏**：实时 IP + 系统时间 + 系统版本 + Init 类型
- **自更新**：菜单 `00` 从 GitHub 拉最新版
- **一键全装**：菜单 `6` 跑完整套基础环境
- **快捷指令**：装好后直接输入 `adou` 启动
- **Init 系统自适应**：systemd / sysv / none 自动降级

---

## 系统要求

- Debian / Ubuntu（apt 包管理）
- root 权限
- 可访问网络（apt 源 + 可选 GitHub）

---

## 快速开始

### 一行安装（推荐）

```bash
curl -sSfL https://raw.githubusercontent.com/alivedou/vps-init/main/init.sh -o init.sh && chmod +x init.sh && ./init.sh
```

### wget 备选

```bash
wget -qO init.sh https://raw.githubusercontent.com/alivedou/vps-init/main/init.sh && chmod +x init.sh && ./init.sh
```

### 极简系统（无 curl/wget）

```bash
apt update && apt install curl -y && curl -sSfL https://raw.githubusercontent.com/alivedou/vps-init/main/init.sh -o init.sh && chmod +x init.sh && ./init.sh
```

### 本地使用

```bash
chmod +x init.sh
sudo ./init.sh
```

---

## 主菜单

| 选项 | 功能 | 子菜单 |
|:----:|------|:------:|
| 1 | 系统信息 | - |
| 2 | 系统更新 | - |
| 3 | 组件管理 | ▶ |
| 4 | Docker 环境 | ▶ |
| 5 | SSH 加固 | ▶ |
| 6 | 一键全装（基础） | - |
| 7 | 防火墙管理 | ▶ |
| 8 | 服务管理 | ▶ |
| 00 | 脚本更新 | - |
| 88 | 退出 | - |

---

## 子菜单

### 3. 组件管理

- **1. UFW 防火墙**（22/80/443）
- **2. 基础工具**（curl / git / vim / nano / tmux / jq / rsync / unzip / locales / screen）
- **3. fail2ban**（5 次失败封 1 小时）
- **4. 安装指定工具**（空格分隔多个包名）
- **5. 创建 /work 目录**
- **6. 时区 → Asia/Shanghai**
- **7. 卸载指定组件**（带 Y/N 确认）
- **8. 选项说明**（查看每个选项的作用）
- **0. 返回主菜单**

### 4. Docker 环境

- **1. 安装 Docker CE**（含自动配置镜像加速）
- **2. 配置镜像加速**（`/etc/docker/daemon.json`，含国内镜像源 + 日志限制）
- **3. 查看 Docker 信息**（`docker info` 前 30 行）
- **4. 查看已装镜像/容器**（`docker ps -a` + `docker images`）
- **5. 一键清理**（停止并删除所有容器）
- **6. 清理镜像/卷/网络**（`docker system prune -af --volumes`）
- **7. 卸载 Docker**（带 Y/N 确认，会清空 `/etc/docker` 和 `/var/lib/docker`）
- **0. 返回主菜单**

### 5. SSH 加固

子菜单顶部会显示当前 SSH 端口和 root 登录状态。

- **1. 创建非 root 用户**（自动加入 sudo + docker 组）
- **2. 禁用 root 密码登录**（保留密钥登录，**会自动备份 sshd_config**）
- **3. 修改 SSH 端口**（自动同步 UFW 放行，**会自动备份 sshd_config**）
- **4. 放行新端口到 UFW**
- **5. 备份 sshd_config**
- **6. 还原 sshd_config**（从最新一份备份）
- **7. 重启 sshd**（用 reload，不杀进程）
- **0. 返回主菜单**

### 7. 防火墙管理

- **1. 放行端口**（支持 `8080` 或 `8000:9000/tcp`，可选备注）
- **2. 拒绝端口**（可选备注）
- **3. 查看规则**（带编号 + 备注）
- **4. 删除规则**（按编号）
- **5. 重载 UFW**
- **6. 启用/禁用 UFW**
- **0. 返回主菜单**

### 8. 服务管理

通用服务管理（先输服务名，再选操作）：

- **1. 查看状态** / **2. 停止** / **3. 启动** / **4. 重启** / **5. 启用开机自启** / **6. 禁用开机自启**
- 适用：nginx、docker、sshd、ufw、fail2ban 等任意 init 服务

---

## 一键全装（选项 6）

依次执行：

1. 系统更新（apt update + upgrade + autoremove）
2. 基础工具 + locale（en_US / zh_CN）
3. 时区 → Asia/Shanghai
4. UFW 防火墙（22/80/443）
5. fail2ban
6. Docker CE + 镜像加速

**不含** SSH 加固（避免断连），完成后进菜单 5 单独操作。

预计耗时 3-10 分钟。**首次会 Y/N 确认**。

---

## 快捷指令

第一次跑会自动在 `/usr/local/bin/adou` 创建软链接。

下次直接：

```bash
adou
```

即可启动脚本（不需切到脚本目录）。

---

## 自更新（选项 00）

从 GitHub `main` 分支拉最新 `init.sh`，比对本地：

- **不同**：自动覆盖并 `exec` 重启
- **相同**：提示"已是最新"
- **失败**：提示"网络问题或 URL 错误"，不破坏本地脚本

需先有 GitHub 仓库：`https://github.com/alivedou/vps-init`

---

## Init 系统自适应

脚本启动时检测 `/proc/1/comm`：

| 检测结果 | 服务管理命令 | 适用环境 |
|---------|------------|---------|
| `systemd` | `systemctl xxx` | 标准 VPS（阿里云、腾讯云、AWS 等） |
| `sysv` | `service xxx` + `update-rc.d` | 部分容器 VPS、LXC |
| `none` | 跳过 | 纯 chroot 容器 |

启动后**主菜单顶部状态栏**会显示当前 Init 类型。

---

## 注意事项

### SSH 加固（重要）

- **禁用 root 密码登录前**：脚本会检查 `/root/.ssh/authorized_keys` 是否有有效内容，**空的会要求二次确认**
- **改 SSH 端口后**：当前 SSH 会话不会断（脚本用 `reload` 不用 `restart`），但需在新窗口测试新端口连接
- **sshd_config 自动备份**：每次改配置前备份到 `/etc/ssh/sshd_config.bak.YYYYMMDDhhmmss`

### 容器环境

- **UFW 启用失败**：容器无 iptables 权限（`CAP_NET_ADMIN`）时 UFW 启用会失败，脚本会显式提示，不会静默
- **systemctl 失败**：脚本自动降级到 `service` 命令，仍失败则跳过

### 一键全装

- 不会**卸载**已装的服务（保留现有 Docker 等）
- 不会**重启**任何服务（除了 fail2ban 和 Docker 需要 enable）

### 路径假设

- 假设你是 **root**
- 假设磁盘只有一块（`/`），不看挂载点
- 假设 `apt` 是包管理器（**不支持 yum/dnf/apk**）

---

## 文件路径

| 用途 | 路径 |
|------|------|
| 脚本本身 | 任意位置（首次运行软链到 `/usr/local/bin/adou`） |
| 快捷指令软链接 | `/usr/local/bin/adou` |
| sshd_config 备份 | `/etc/ssh/sshd_config.bak.YYYYMMDDhhmmss` |
| fail2ban 配置 | `/etc/fail2ban/jail.local` |
| Docker daemon 配置 | `/etc/docker/daemon.json` |
| locale | `/etc/locale.gen`（启用 en_US / zh_CN） |
| 工作目录 | `/work` |

---

## 常见问题

**Q: 全新 VPS 没 curl 也没 wget 怎么办？**
A: `apt update && apt install curl -y` 先装 curl，再拉脚本。极简 Debian 快速开始里有完整命令。
A: 直接 `adou`，或者 `bash /path/to/init.sh`。

**Q: 脚本会偷偷重启服务吗？**
A: 不会。一键全装也不会重启 sshd，避免断连。改 SSH 配置后用 `reload` 不杀进程。

**Q: 我在容器 VPS 上跑会怎样？**
A: 大部分功能正常，UFW 和 systemctl 类操作会自动降级或显式提示失败。

**Q: 自更新怎么用？**
A: 主菜单 `00`，需要 GitHub 仓库有对应文件。

**Q: 怎么卸载脚本？**
A: 删文件 + `rm /usr/local/bin/adou` 即可，**不会**还原已装的服务和配置。

**Q: 能加新功能吗？**
A: 可以改脚本，所有功能函数都是独立的，加新菜单项加 case 分支即可。

---

## License

MIT

## 作者

[adou](https://github.com/alivedou) - github.com/alivedou/vps-init
