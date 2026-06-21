#!/bin/bash
# ============================================================
# VPS 初始化工具 (Init CLI) v2
# 风格参考 eooce/ssh_tool，紧凑两列菜单
# 用法：chmod +x init.sh && ./init.sh
# 适用：Debian/Ubuntu (apt)
# ============================================================

export LANG=en_US.UTF-8

re='\e[0m'
red='\e[1;91m'
white='\e[1;97m'
green='\e[1;32m'
yellow='\e[1;33m'
purple='\e[1;35m'
skyblue='\e[1;96m'

SCRIPT_VERSION="v2.0"
SCRIPT_URL="https://raw.githubusercontent.com/alivedou/vps-init/main/init.sh"

# ====================== 前置检查 ======================

if [ "$EUID" -ne 0 ]; then
    echo -e "${red}请用 root 运行：sudo ./init.sh${re}"
    exit 1
fi
if ! command -v apt &> /dev/null; then
    echo -e "${red}仅支持 Debian/Ubuntu (apt 系统)${re}"
    exit 1
fi

# ====================== Init 系统检测 ======================

INIT_TYPE="systemd"
if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ] && systemctl is-system-running &>/dev/null; then
    SVC_ENABLE_START() { systemctl enable --now "$1" 2>&1; }
    SVC_RESTART()      { systemctl restart "$1" 2>&1; }
    SVC_RELOAD()       { systemctl reload "$1" 2>/dev/null || systemctl restart "$1"; }
    SVC_STATUS()       { systemctl is-active "$1" 2>/dev/null; }
    SVC_DISABLE()      { systemctl disable --now "$1" 2>&1; }
elif command -v service &> /dev/null; then
    SVC_ENABLE_START() { service "$1" start 2>&1; update-rc.d "$1" defaults 2>/dev/null || true; }
    SVC_RESTART()      { service "$1" restart 2>&1; }
    SVC_RELOAD()       { service "$1" reload 2>/dev/null || service "$1" restart 2>&1; }
    SVC_STATUS()       { service "$1" status 2>&1 | grep -qE "active|running" && echo active || echo inactive; }
    SVC_DISABLE()      { service "$1" stop 2>&1; update-rc.d "$1" remove 2>/dev/null || true; }
    INIT_TYPE="sysv"
else
    SVC_ENABLE_START() { return 0; }
    SVC_RESTART()      { return 0; }
    SVC_RELOAD()       { return 0; }
    SVC_STATUS()       { echo "unknown"; }
    SVC_DISABLE()      { return 0; }
    INIT_TYPE="none"
fi

# ====================== 通用工具函数 ======================

# Y/N 确认
confirm() {
    local prompt="$1"
    read -p "$(echo -e "${red}${prompt} (Y/N): ${re}")" ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# 多包管理器安装（多包、空格分隔）
pkg_install() {
    local pkg
    for pkg in "$@"; do
        if dpkg -s "$pkg" &>/dev/null 2>&1; then
            echo -e "  ${green}✓ $pkg 已安装${re}"
        else
            echo -e "  ${yellow}→ 正在安装 $pkg...${re}"
            if DEBIAN_FRONTEND=noninteractive apt install -y "$pkg" >/dev/null 2>&1; then
                echo -e "  ${green}✓ $pkg 装好${re}"
            else
                echo -e "  ${red}✗ $pkg 装失败${re}"
            fi
        fi
    done
}

pkg_remove() {
    local pkg
    for pkg in "$@"; do
        echo -e "  ${yellow}→ 正在卸载 $pkg...${re}"
        if DEBIAN_FRONTEND=noninteractive apt remove -y "$pkg" >/dev/null 2>&1; then
            echo -e "  ${green}✓ $pkg 已卸载${re}"
        else
            echo -e "  ${red}✗ $pkg 卸载失败${re}"
        fi
    done
}

# 系统信息
show_sysinfo() {
    local ipv4 country isp cpu_arch cpu_cores mem disk kernel os
    ipv4=$(curl -s -m 2 ipv4.ip.sb 2>/dev/null)
    [ -z "$ipv4" ] && ipv4="N/A"
    country=$(curl -s -m 2 ipinfo.io/country 2>/dev/null)
    [ -z "$country" ] && country="N/A"
    # ipinfo.io/org 返回 "AS号 运营商名"，去掉 AS 号
    isp=$(curl -s -m 2 ipinfo.io/org 2>/dev/null | awk '{$1=""; sub(/^ /, ""); print}')
    [ -z "$isp" ] && isp="N/A"
    cpu_arch=$(uname -m)
    cpu_cores=$(nproc)
    # 统一转 GB，去掉 Mi/Gi 单位混乱
    mem=$(free -b | awk 'NR==2{printf "%.1f/%.1f GB (%.1f%%)", $3/1024/1024/1024, $2/1024/1024/1024, $3*100/$2}')
    disk=$(df -BG / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
    kernel=$(uname -r)
    os=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Unknown")

    echo -e "${skyblue}==================== 系统信息 ====================${re}"
    echo -e "  ${white}公网 IPv4:${re}  ${yellow}$ipv4${re}"
    echo -e "  ${white}地理位置:${re}  ${yellow}$country${re}"
    echo -e "  ${white}运营商:    ${re}  ${yellow}$isp${re}"
    echo -e "  ${white}操作系统:  ${re}  ${yellow}$os${re}"
    echo -e "  ${white}内核:      ${re}  ${yellow}$kernel${re}"
    echo -e "  ${white}CPU:      ${re}  ${yellow}$cpu_arch × $cpu_cores 核${re}"
    echo -e "  ${white}内存:      ${re}  ${yellow}$mem${re}"
    echo -e "  ${white}磁盘:      ${re}  ${yellow}$disk${re}"
    echo -e "  ${white}Init:     ${re}  ${yellow}$INIT_TYPE${re}"
    echo -e "${skyblue}==================================================${re}"
}

# 自更新
self_update() {
    echo -e "${yellow}正在从 GitHub 拉取最新版本...${re}"
    local tmp="/tmp/init_latest.sh"
    if curl -fsSL "$SCRIPT_URL" -o "$tmp" 2>/dev/null; then
        if ! diff -q "$tmp" "$0" &>/dev/null; then
            mv "$tmp" "$0"
            chmod +x "$0"
            echo -e "${green}已更新，重新启动...${re}"
            exec "$0"
        else
            rm -f "$tmp"
            echo -e "${green}已经是最新版本（${SCRIPT_VERSION}）${re}"
        fi
    else
        echo -e "${red}更新失败（网络问题或 URL 错误）${re}"
        rm -f "$tmp"
    fi
}

# 安装快捷指令
install_shortcut() {
    local script_path="/usr/local/bin/adou"
    local self
    self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    mkdir -p /usr/local/bin
    if [ ! -L "$script_path" ] || [ "$(readlink -f "$script_path" 2>/dev/null)" != "$self" ]; then
        ln -sf "$self" "$script_path" 2>/dev/null && echo -e "${green}快捷指令已设置：${yellow}adou${re}"
    fi
}

# ====================== 功能函数 ======================

do_sysinfo() { show_sysinfo; }

do_update() {
    echo -e "${yellow}正在更新系统...${re}"
    apt update -y
    apt upgrade -y
    apt autoremove -y
    echo -e "${green}系统更新完成${re}"
}

# ---- 组件管理 ----
do_component() {
    while true; do
        clear
        echo -e "${skyblue}==================== 组件管理 ====================${re}"
        echo -e "${green} 1. UFW 防火墙（22/80/443）    5. 创建 /work 目录${re}"
        echo -e "${green} 2. 基础工具（curl/git/vim）   6. 时区 → Asia/Shanghai${re}"
        echo -e "${green} 3. fail2ban                   7. 卸载指定组件${re}"
        echo -e "${green} 4. 安装指定工具               8. 选项说明${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${skyblue} 0. 返回主菜单${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        read -p $'\033[1;91m请选择: \033[0m' c
        case $c in
            1) do_ufw ;;
            2) do_basics ;;
            3) do_fail2ban ;;
            4) read -p "包名（空格分隔）: " pkgs; [ -n "$pkgs" ] && pkg_install $pkgs ;;
            5) mkdir -p /work && chmod 755 /work && echo -e "${green}/work 已创建${re}" ;;
            6) do_timezone ;;
            7) read -p "包名（空格分隔）: " pkgs; [ -n "$pkgs" ] && confirm "确定卸载？" && pkg_remove $pkgs ;;
            8) echo -e "${yellow}1. UFW       — 安装并启用防火墙，放行 22/80/443"
               echo -e "2. 基础工具   — 安装 curl git vim nano htop tmux 等常用工具"
               echo -e "3. fail2ban  — 防暴力破解，自动封禁异常 IP"
               echo -e "4. 安装工具   — 手动输入包名安装（apt）"
               echo -e "5. /work     — 创建 /work 目录（放项目用）"
               echo -e "6. 时区      — 设为上海时区（Asia/Shanghai）"
               echo -e "7. 卸载组件   — 手动输入包名卸载${re}" ;;
            0) return ;;
            *) echo -e "${red}无效选择${re}"; continue ;;
        esac
        echo ""; read -p "按回车继续..." _
    done
}

do_ufw() {
    pkg_install ufw
    ufw default deny incoming >/dev/null 2>&1
    ufw default allow outgoing >/dev/null 2>&1
    ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1
    ufw allow 80/tcp comment 'HTTP' >/dev/null 2>&1
    ufw allow 443/tcp comment 'HTTPS' >/dev/null 2>&1
    ufw --force enable >/dev/null 2>&1
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw status verbose
        echo -e "${green}UFW 已启用${re}"
    else
        echo -e "${red}UFW 启用失败（容器环境无 iptables 权限）${re}"
    fi
}

do_basics() {
    pkg_install curl wget git vim nano htop tmux jq rsync unzip ca-certificates gnupg locales screen
    sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
    sed -i 's/^# *zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
    locale-gen >/dev/null 2>&1
    echo -e "${green}基础工具 + locale 已就绪${re}"
}

do_fail2ban() {
    pkg_install fail2ban
    cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
EOF
    SVC_ENABLE_START fail2ban
    SVC_RESTART fail2ban
    echo -e "${green}fail2ban 已启用（5 次失败封 1 小时）${re}"
}

do_timezone() {
    pkg_install tzdata
    if timedatectl set-timezone Asia/Shanghai 2>/dev/null; then
        echo -e "${green}时区（systemd）: $(date)${re}"
    else
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
        echo "Asia/Shanghai" > /etc/timezone
        echo -e "${green}时区（fallback）: $(date)${re}"
    fi
}

# ---- Docker 环境 ----
do_docker() {
    while true; do
        clear
        echo -e "${skyblue}==================== Docker 环境 ====================${re}"
        if command -v docker &>/dev/null; then
            local ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
            echo -e "  ${green}Docker 状态: 已安装 v${ver}${re}"
        else
            echo -e "  ${red}Docker 状态: 未安装${re}"
        fi
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${green} 1. 安装 Docker CE              5. 一键清理（停/删容器）${re}"
        echo -e "${green} 2. 配置镜像加速                6. 清理镜像/卷/网络${re}"
        echo -e "${green} 3. 查看 Docker 信息            7. 卸载 Docker 环境（含所有数据）${re}"
        echo -e "${green} 4. 查看已装镜像/容器${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${skyblue} 0. 返回主菜单${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        read -p $'\033[1;91m请选择: \033[0m' c
        case $c in
            1) do_install_docker ;;
            2) do_docker_mirror ;;
            3) docker info 2>/dev/null | head -30 ;;
            4) echo -e "${yellow}容器:${re}"; docker ps -a 2>/dev/null; echo; echo -e "${yellow}镜像:${re}"; docker images 2>/dev/null ;;
            5)
                echo -e "  ${yellow}查询容器中...${re}"
                if ! timeout 5 docker info &>/dev/null; then
                    echo -e "  ${red}Docker daemon 没响应（5s 超时）${re}"
                    echo -e "  手动检查：${green}docker ps -a${re} 或 ${green}dockerd${re}"
                    continue
                fi
                list=$(timeout 10 docker ps -a --format "{{.ID}}|{{.Names}}|{{.Status}}" 2>/dev/null)
                if [ -z "$list" ]; then
                    echo -e "  ${green}当前没有容器，无需清理${re}"
                    continue
                fi
                echo -e "  ${yellow}当前容器：${re}"
                i=0
                while IFS='|' read -r cid cname cstat; do
                    [ -z "$cid" ] && continue
                    ((i++))
                    echo "  [${i}] ${cname} (${cid}) - ${cstat}"
                done <<< "$list"
                total=$i
                echo ""
                read -p "  输入序号（空格分隔多选，a=全部，q=取消）: " sel
                if [ -z "$sel" ] || [ "$sel" = "q" ]; then
                    echo "  已取消"; continue
                fi
                if [ "$sel" = "a" ] || [ "$sel" = "all" ]; then
                    if confirm "确定删除全部 ${total} 个容器？"; then
                        timeout 30 docker stop $(timeout 5 docker ps -q) 2>/dev/null
                        timeout 30 docker rm $(timeout 5 docker ps -aq) 2>/dev/null
                        echo -e "  ${green}已清理全部${re}"
                    fi
                    continue
                fi
                for n in $sel; do
                    if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
                        echo -e "  ${red}无效序号: $n${re}"
                        continue
                    fi
                    line=$(echo "$list" | sed -n "${n}p")
                    cid=$(echo "$line" | cut -d'|' -f1)
                    cname=$(echo "$line" | cut -d'|' -f2)
                    if confirm "确定删除 [${n}] ${cname}？"; then
                        timeout 15 docker stop "$cid" 2>/dev/null
                        timeout 15 docker rm "$cid" 2>/dev/null && \
                            echo -e "  ${green}✓ [${n}] ${cname} 已删除${re}" || \
                            echo -e "  ${red}✗ ${cname} 删除失败${re}"
                    fi
                done
                ;;
            6) confirm "确定清理无用资源？" && docker system prune -af --volumes 2>/dev/null && echo -e "${green}已清理${re}" ;;
            7) confirm "确定卸载 Docker 环境？（会删除所有容器/镜像/卷/配置，rm -rf /var/lib/docker）" && pkg_remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && rm -rf /etc/docker /var/lib/docker ;;
            0) return ;;
            *) echo -e "${red}无效选择${re}"; continue ;;
        esac
        echo ""; read -p "按回车继续..." _
    done
}

do_install_docker() {
    if command -v docker &>/dev/null; then
        echo -e "${yellow}Docker 已装：$(docker --version)${re}"
        return
    fi
    # 官方一键脚本：内部自动处理 gpg key + apt 源
    echo -e "  ${yellow}→ 正在通过 get.docker.com 装 Docker...${re}"
    if ! curl -fsSL https://get.docker.com | sh; then
        echo -e "${red}Docker 安装失败（网络问题？）${re}"
        return 1
    fi
    SVC_ENABLE_START docker
    sleep 2
    if docker info &>/dev/null; then
        echo -e "  ${green}✓ Docker daemon 运行中${re}"
    else
        echo -e "  ${yellow}Docker 装上了但 daemon 未自动启动${re}"
        echo -e "  手动启动："
        echo -e "    ${green}service docker start${re}  (SysV 兼容)"
        echo -e "    ${green}systemctl start docker${re}  (systemd)"
        echo -e "  或前台调试：${green}dockerd${re}"
    fi
    do_docker_mirror
}

do_docker_mirror() {
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    SVC_RESTART docker
    echo -e "${green}镜像加速已配置（含日志限制）${re}"
}

# ---- SSH 加固 ----
do_ssh() {
    while true; do
        clear
        echo -e "${skyblue}==================== SSH 加固 ====================${re}"
        local ssh_port root_login
        ssh_port=$(grep "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
        ssh_port=${ssh_port:-22}
        root_login=$(grep "^PermitRootLogin " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
        root_login=${root_login:-yes}
        echo -e "  ${white}当前端口: ${yellow}$ssh_port${re}    ${white}root 登录: ${yellow}$root_login${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${green} 1. 创建非 root 用户            5. 备份 sshd_config${re}"
        echo -e "${green} 2. 禁用 root 密码登录          6. 还原 sshd_config${re}"
        echo -e "${green} 3. 修改 SSH 端口               7. 重启 sshd${re}"
        echo -e "${green} 4. 放行新端口到 UFW"
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${skyblue} 0. 返回主菜单${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        read -p $'\033[1;91m请选择: \033[0m' c
        case $c in
            1) do_create_user ;;
            2) do_disable_root_pw ;;
            3) do_change_ssh_port ;;
            4) read -p "要放行的端口: " p; [ -n "$p" ] && ufw allow "$p/tcp" comment "Custom" 2>/dev/null && echo -e "${green}已放行 $p${re}" ;;
            5) cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)" && echo -e "${green}已备份${re}" ;;
            6) local bak=$(ls -t /etc/ssh/sshd_config.bak.* 2>/dev/null | head -1); [ -n "$bak" ] && confirm "从 $bak 还原？" && cp "$bak" /etc/ssh/sshd_config && SVC_RELOAD sshd && echo -e "${green}已还原${re}" || echo -e "${red}无备份${re}" ;;
            7) SVC_RELOAD sshd && echo -e "${green}sshd 已重载${re}" ;;
            0) return ;;
            *) echo -e "${red}无效选择${re}"; continue ;;
        esac
        echo ""; read -p "按回车继续..." _
    done
}

do_create_user() {
    read -p "新用户名: " u
    if [ -z "$u" ]; then echo "已取消"; return; fi
    if id "$u" &>/dev/null; then
        echo -e "${yellow}用户 $u 已存在${re}"
    else
        adduser --gecos "" "$u"
        usermod -aG sudo,docker "$u"
        echo -e "${green}用户 $u 已创建并加入 sudo + docker 组${re}"
    fi
}

do_disable_root_pw() {
    echo -e "${red}警告：禁用前请确保已配置好 SSH 密钥！${re}"
    if [ ! -s /root/.ssh/authorized_keys ]; then
        echo -e "${red}未检测到 /root/.ssh/authorized_keys 有效内容！${re}"
        confirm "仍然继续？" || return
    fi
    cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
    grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
    if sshd -t; then
        SVC_RELOAD sshd
        echo -e "${green}已禁用 root 密码登录（保留密钥登录）${re}"
    else
        echo -e "${red}配置有误，未重载${re}"
    fi
}

do_change_ssh_port() {
    read -p "新 SSH 端口（留空跳过）: " p
    if [ -z "$p" ]; then return; fi
    if ! [[ "$p" =~ ^[0-9]+$ ]] || [ "$p" -lt 1 ] || [ "$p" -gt 65535 ]; then
        echo -e "${red}端口无效${re}"; return
    fi
    cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
    sed -i "s/^#\?Port .*/Port $p/" /etc/ssh/sshd_config
    grep -q "^Port $p" /etc/ssh/sshd_config || echo "Port $p" >> /etc/ssh/sshd_config
    command -v ufw &>/dev/null && ufw allow "$p/tcp" comment 'SSH-custom' 2>/dev/null
    if sshd -t; then
        SVC_RELOAD sshd
        echo -e "${green}端口已改为 $p${re}"
        echo -e "${red}⚠ 重新连接用：ssh -p $p root@<IP>${re}"
    else
        echo -e "${red}配置有误，未应用${re}"
    fi
}

# ---- 实用脚本 ----
do_scripts() {
    while true; do
        clear
        echo -e "${skyblue}==================== 实用脚本 ====================${re}"
        echo -e "${white}以下脚本来自第三方作者，本站仅提供快捷入口${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${green} 1. 硬件检测（xykt/HardwareQuality）${re}"
        echo -e "${yellow}    └ CPU/内存/磁盘/网络综合跑分${re}"
        echo -e "${green} 2. IP 质量（xykt/IPQuality）${re}"
        echo -e "${yellow}    └ IP 黑名单/欺诈分/出口类型检测${re}"
        echo -e "${green} 3. 流媒体解锁（xykt/RegionRestrictionCheck）${re}"
        echo -e "${yellow}    └ 检测 Netflix/Disney+/YouTube 等解锁情况${re}"
        echo -e "${green} 4. 自定义脚本（输入 URL）${re}"
        echo -e "${yellow}    └ 手动粘贴任意脚本直链运行${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${skyblue} 0. 返回主菜单${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        read -p $'\033[1;91m请选择: \033[0m' c
        case $c in
            1) bash <(curl -fsSL https://raw.githubusercontent.com/xykt/HardwareQuality/main/hardware.sh) ;;
            2) bash <(curl -fsSL https://raw.githubusercontent.com/xykt/IPQuality/main/ip.sh) ;;
            3) bash <(curl -fsSL https://raw.githubusercontent.com/xykt/RegionRestrictionCheck/main/check.sh) ;;
            4) read -p "脚本直链 URL: " url; [ -n "$url" ] && bash <(curl -fsSL "$url") ;;
            0) return ;;
            *) echo -e "${red}无效选择${re}"; continue ;;
        esac
        echo ""; read -p "按回车继续..." _
    done
}

# ---- 一键全装 ----
do_all() {
    echo -e "${yellow}一键全装：更新 + 基础工具 + 时区 + UFW + fail2ban + Docker${re}"
    echo -e "${yellow}不含 SSH 加固（避免断连）${re}"
    confirm "确定开始？将持续数分钟" || return
    do_update
    do_basics
    do_timezone
    do_ufw
    do_fail2ban
    do_install_docker
    echo -e "${green}全装完成！SSH 加固请进菜单 5 单独操作${re}"
}

# ---- 防火墙管理 ----
do_firewall() {
    while true; do
        clear
        echo -e "${skyblue}==================== 防火墙管理 ====================${re}"
        if command -v ufw &>/dev/null; then
            local st=$(ufw status 2>/dev/null | head -1)
            echo -e "  ${white}UFW 状态: ${yellow}$st${re}"
        else
            echo -e "  ${red}UFW 未安装${re}"
        fi
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${green} 1. 放行端口                   4. 删除规则${re}"
        echo -e "${green} 2. 拒绝端口                   5. 重载 UFW${re}"
        echo -e "${green} 3. 查看规则                   6. 启用/禁用 UFW${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${skyblue} 0. 返回主菜单${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        read -p $'\033[1;91m请选择: \033[0m' c
        case $c in
            1) read -p "放行端口（如 8080 或 8000:9000/tcp）: " r; [ -n "$r" ] && { read -p "备注（可选，如 Web 服务，留空跳过）: " remark; if [ -n "$remark" ]; then ufw allow "$r" comment "$remark" 2>/dev/null; else ufw allow "$r" 2>/dev/null; fi; ufw reload 2>/dev/null && echo -e "${green}已放行 $r${re}"; } ;;
            2) read -p "拒绝端口: " r; [ -n "$r" ] && { read -p "备注（可选，留空跳过）: " remark; if [ -n "$remark" ]; then ufw deny "$r" comment "$remark" 2>/dev/null; else ufw deny "$r" 2>/dev/null; fi; ufw reload 2>/dev/null && echo -e "${green}已拒绝 $r${re}"; } ;;
            3) ufw status numbered 2>/dev/null ;;
            4) read -p "要删除的规则编号: " n; [ -n "$n" ] && ufw delete "$n" 2>/dev/null && ufw reload 2>/dev/null && echo -e "${green}已删除${re}" ;;
            5) ufw reload 2>/dev/null && echo -e "${green}已重载${re}" ;;
            6) if ufw status 2>/dev/null | grep -q "Status: active"; then ufw disable 2>/dev/null && echo -e "${yellow}已禁用${re}"; else ufw --force enable 2>/dev/null && echo -e "${green}已启用${re}"; fi ;;
            0) return ;;
            *) echo -e "${red}无效选择${re}"; continue ;;
        esac
        echo ""; read -p "按回车继续..." _
    done
}

# ---- 服务管理 ----
do_service() {
    while true; do
        clear
        echo -e "${skyblue}==================== 服务管理 ====================${re}"
        echo -e "  ${white}输入服务名（nginx, docker, sshd, ufw, fail2ban...）${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${green} 1. 查看状态    3. 启动    5. 启用开机自启${re}"
        echo -e "${green} 2. 停止        4. 重启    6. 禁用开机自启${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        echo -e "${skyblue} 0. 返回主菜单${re}"
        echo -e "${purple}------------------------------------------------------${re}"
        read -p $'\033[1;91m请选择: \033[0m' c
        case $c in
            0) return ;;
            *) read -p "服务名: " svc
               [ -z "$svc" ] && continue
               case $c in
                   1) echo -e "状态: ${yellow}$(SVC_STATUS $svc)${re}" ;;
                   2) service "$svc" stop 2>/dev/null && echo -e "${green}已停止${re}" || echo -e "${red}停止失败${re}" ;;
                   3) SVC_ENABLE_START "$svc" ;;
                   4) SVC_RESTART "$svc" ;;
                   5) systemctl enable "$svc" 2>/dev/null || update-rc.d "$svc" defaults 2>/dev/null; echo -e "${green}已启用自启${re}" ;;
                   6) systemctl disable "$svc" 2>/dev/null || update-rc.d "$svc" remove 2>/dev/null; echo -e "${green}已禁用自启${re}" ;;
               esac ;;
        esac
        echo ""; read -p "按回车继续..." _
    done
}

# ====================== 主菜单 ======================

main_menu() {
    install_shortcut  # 首次运行自动创建 init 快捷指令
    while true; do
        clear
        local ipv4=$(curl -s -m 2 ipv4.ip.sb 2>/dev/null)
        [ -z "$ipv4" ] && ipv4="offline"
        local now=$(date "+%Y-%m-%d %H:%M:%S")
        local os=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "Unknown")

        echo -e "${skyblue}    IP: ${yellow}$ipv4${skyblue}    时间: ${yellow}$now${re}"
        echo -e "\033[0;97m-----------------By'adou-----------------\033[0m"
        echo -e "\033[0;97m仓库: https://github.com/alivedou/vps-init\033[0m"
        echo ""
        echo -e "                 ${yellow}VPS 初始化工具 ${SCRIPT_VERSION}${re}"
        echo -e "${yellow}系统: $os | Init: $INIT_TYPE${re}"
        echo -e "${skyblue}快捷指令 ${yellow}adou${skyblue}（下次直接输入 adou 启动）${re}"
        echo "-------------------------------------------------------------------"
        echo -e "${green} 1. 系统信息                   5. SSH 加固 ▶${re}"
        echo -e "${green} 2. 系统更新                   6. 一键全装（基础）${re}"
        echo -e "${green} 3. 组件管理 ▶                 7. 防火墙管理 ▶${re}"
        echo -e "${green} 4. Docker 环境 ▶              8. 服务管理 ▶${re}"
        echo -e "${green}                               9. 实用脚本 ▶${re}"
        echo "-------------------------------------------------------------------"
        echo -e "${green}00. 脚本更新${red}                  88. 退出脚本${re}"
        echo -e "${yellow}-------------------------------------------------------------------${re}"
        read -p $'\033[1;91m请输入你的选择: \033[0m' choice

        case $choice in
            1) do_sysinfo; echo ""; read -p "按回车返回主菜单..." _ ;;
            2) do_update; echo ""; read -p "按回车返回主菜单..." _ ;;
            3) do_component ;;
            4) do_docker ;;
            5) do_ssh ;;
            6) do_all; echo ""; read -p "按回车返回主菜单..." _ ;;
            7) do_firewall ;;
            8) do_service ;;
            9) do_scripts ;;
            00) self_update; echo ""; read -p "按回车返回主菜单..." _ ;;
            88) echo -e "${green}Bye!${re}"; exit 0 ;;
            *) echo -e "${red}无效选择${re}"; continue ;;
        esac
    done
}

main_menu
