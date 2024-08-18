#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 主菜单函数
main_menu() {
    clear
    echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
    echo "================================================================"
    echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
    echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
    echo "节点社区 Discord 社群:https://discord.gg/GbMV5EcNWF"
    echo "退出脚本，请按键盘ctrl c退出即可"
    echo "1) 安装 Allora 节点"
    echo "2) 启动节点"
    echo "3) 退出"
    read -p "请输入选项（1/2/3）: " option

    case $option in
        1)
            install_allora_node
            ;;
        2)
            start_node
            ;;
        3)
            exit 0
            ;;
        *)
            echo "无效选项，请输入 1、2 或 3。"
            sleep 2
            main_menu
            ;;
    esac
}

# 安装 Allora 节点
install_allora_node() {
    echo "正在更新和升级现有包..."
    sudo apt update && sudo apt upgrade -y

    echo "正在安装依赖项..."
    sudo apt install -y ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
        curl git wget make jq build-essential pkg-config lsb-release libssl-dev \
        libreadline-dev libffi-dev gcc screen unzip lz4

    echo "正在安装 Python3..."
    sudo apt install -y python3
    python3 --version

    echo "正在安装 pip3..."
    sudo apt install -y python3-pip
    pip3 --version

    echo "正在安装 Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    docker version

    echo "正在安装 Docker-Compose..."
    VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    chmod +x /usr/local/bin/docker-compose
    docker-compose --version

    echo "正在配置 Docker 权限..."
    sudo groupadd docker
    sudo usermod -aG docker $USER

    echo "正在安装 Go..."
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version

    echo "所有依赖项、Python3、Docker、Docker-Compose、Go 已成功安装或更新。"

    echo "是否需要检查并处理 Allora？"
    echo "1) 是"
    echo "2) 否"
    read -p "输入 1 或 2: " choice

    case $choice in
        1)
            handle_allora
            ;;
        2)
            echo "跳过 Allora 处理。"
            ;;
        *)
            echo "无效选择，请输入 1 或 2。"
            sleep 2
            install_allora_node
            ;;
    esac

    # 钱包恢复或新建选择
    echo "请选择操作："
    echo "1) 恢复钱包"
    echo "2) 新建钱包"
    read -p "输入 1 或 2: " wallet_choice

    case $wallet_choice in
        1)
            echo "请输入助记词密码进行恢复："
            allorad keys add testkey --recover
            ;;
        2)
            echo "正在新建钱包..."
            allorad keys add testkey
            ;;
        *)
            echo "无效选择，请输入 1 或 2。"
            ;;
    esac

    echo "操作已完成。请重新登录以使 Docker 权限和 Go 环境变量更改生效。"
    read -p "按任意键返回到主菜单..." -n1 -s
    main_menu
}

# 处理 Allora
handle_allora() {
    if [ -d "$HOME/allora-chain" ]; then
        echo "检测到 Allora 已安装。是否删除旧文件并重新克隆？"
        echo "1) 删除旧文件并重新克隆"
        echo "2) 保留旧文件"
        read -p "输入 1 或 2: " sub_choice
        case $sub_choice in
            1)
                echo "正在删除旧文件并重新克隆 Allora..."
                cd $HOME && rm -rf allora-chain
                ;;
            2)
                echo "保留旧文件，不进行重新克隆。"
                ;;
            *)
                echo "无效选择，请输入 1 或 2。"
                sleep 2
                handle_allora
                ;;
        esac
    else
        echo "Allora 未安装，正在克隆..."
    fi

    git clone https://github.com/allora-network/allora-chain.git
    cd allora-chain && make all
    allorad version
}

# 启动节点
start_node() {
    echo "正在下载和配置 basic-coin-prediction-node..."

    cd $HOME
    git clone https://github.com/allora-network/basic-coin-prediction-node
    cd basic-coin-prediction-node

    echo "拉取并替换文件..."
    # 拉取 https://github.com/wuya51/Allora.git 仓库
    git clone https://github.com/wuya51/Allora.git /root/Allora

    # 替换对应文件
    cp /root/Allora/config.json ./config.json
    cp /root/Allora/model.py ./model.py
    cp /root/Allora/app.py ./app.py
    cp /root/Allora/requirements.txt ./requirements.txt

    # 清理临时仓库
    rm -rf /root/Allora

    echo "配置文件将在 nano 编辑器中打开。请按需修改 config.json 文件。"
    nano config.json

    echo "编辑 app.py 文件以进行进一步配置。"
    nano app.py

    echo "运行 Worker..."
    chmod +x init.sh
    ./init.sh

    echo "配置完成后，请按任意键继续..."
    read -p "按任意键返回到主菜单..." -n1 -s
    main_menu
}

# 运行主菜单
main_menu
