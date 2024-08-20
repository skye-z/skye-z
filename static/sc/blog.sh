#!/bin/bash

# 检查是否以root用户执行
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# 设置服务名称和描述
SERVICE_NAME="betax-blog"
SERVICE_DESCRIPTION="BetaX Blog"

# 获取系统架构
if [[ $(uname -m) == "aarch64" ]]; then
    ARCH="arm64"
else
    ARCH="amd64"
fi

# 设置可执行文件的下载 URL 和版本
APP_VERSION=$(curl -sL https://api.github.com/repos/skye-z/betax-blog/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
if [ -z "$APP_VERSION" ]; then
    echo "Failed to retrieve the latest BetaX Blog version."
    exit 1
fi
APP_DOWNLOAD_URL="https://github.com/skye-z/betax-blog/releases/download/${APP_VERSION}/betax-blog-linux-${ARCH}"

# 设置工作目录
WORKING_DIRECTORY="/opt/betax-blog"

# 创建 Systemd 服务单元文件
create_systemd_service() {
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    echo "[Unit]" > $SERVICE_FILE
    echo "Description=${SERVICE_DESCRIPTION}" >> $SERVICE_FILE
    echo "After=docker.service" >> $SERVICE_FILE
    echo "" >> $SERVICE_FILE
    echo "[Service]" >> $SERVICE_FILE
    echo "ExecStart=${WORKING_DIRECTORY}/betax-blog --port=$PORT >> /var/log/betax-blog.log 2>&1" >> $SERVICE_FILE
    echo "WorkingDirectory=${WORKING_DIRECTORY}" >> $SERVICE_FILE
    echo "Restart=always" >> $SERVICE_FILE
    echo "" >> $SERVICE_FILE
    echo "[Install]" >> $SERVICE_FILE
    echo "WantedBy=multi-user.target" >> $SERVICE_FILE
}

# 安装公共逻辑
install_common() {
    # 创建工作目录
    sudo mkdir -p $WORKING_DIRECTORY

    # 下载或复制 BetaX Blog 可执行文件
    if [ "$1" == "online" ]; then
        curl --silent -LJ $APP_DOWNLOAD_URL -o ${WORKING_DIRECTORY}/betax-blog
    elif [ "$1" == "offline" ]; then
        cp betax-blog-linux-${ARCH} ${WORKING_DIRECTORY}/betax-blog
    fi

    # 赋予可执行权限
    chmod +x ${WORKING_DIRECTORY}/betax-blog

    # 创建 Systemd 服务单元文件
    create_systemd_service

    # 重载 Systemd 配置
    sudo systemctl daemon-reload

    # 启动服务
    sudo systemctl start $SERVICE_NAME

    echo "BetaX Blog service installed successfully!"
}

get_port_from_user() {
    read -p "Please enter the port number (default is 9800): " PORT
    if [ -z "$PORT" ]; then
        PORT=9800
    fi
}

install_online() {
    get_port_from_user
    install_common online
}

install_offline() {
    get_port_from_user
    if [ -f "betax-blog-linux-${ARCH}" ]; then
        install_common offline
    else
        echo "Error: Offline installation file 'betax-blog-linux-${ARCH}' not found. Please download it manually to the current directory."
        exit 1
    fi
}

uninstall() {
    # 停止服务
    sudo systemctl stop $SERVICE_NAME

    # 禁用开机自启
    sudo systemctl disable $SERVICE_NAME

    # 删除工作目录
    sudo rm -rf $WORKING_DIRECTORY

    # 删除 Systemd 服务文件
    sudo rm -f $SERVICE_FILE

    # 重载 Systemd 配置
    sudo systemctl daemon-reload

    echo "BetaX Blog service uninstalled successfully!"
}

enable_autostart() {
    # 启用开机自启
    sudo systemctl enable $SERVICE_NAME

    echo "Autostart enabled for BetaX Blog service!"
}

disable_autostart() {
    # 禁用开机自启
    sudo systemctl disable $SERVICE_NAME

    echo "Autostart disabled for BetaX Blog service!"
}

# 显示选项
echo "Select an option:"
echo "1. Install BetaX Blog (Online)"
echo "2. Install BetaX Blog (Offline)"
echo "3. Uninstall BetaX Blog"
echo "4. Enable Autostart"
echo "5. Disable Autostart"
read -p "Enter option number: " option

# 根据选项执行相应操作
case $option in
    1) install_online;;
    2) install_offline;;
    3) uninstall;;
    4) enable_autostart;;
    5) disable_autostart;;
    *) echo "Invalid option";;
esac
