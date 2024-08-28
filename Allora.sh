#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Allora.sh"

# 安装和配置 Allorad 的函数
function install_and_configure_allorad() {
    # 更新软件包列表
    sudo apt update -y

    # 升级已安装的软件包
    sudo apt upgrade -y

    # 安装所需的软件包
    sudo apt install -y ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl git wget make jq build-essential pkg-config lsb-release libssl-dev libreadline-dev libffi-dev gcc screen unzip lz4

    # 检查是否已安装 Python 3
    if ! command -v python3 &> /dev/null
    then
        echo "Python 3 未安装，正在安装 Python 3..."
        sudo apt install -y python3
    else
        echo "Python 3 已安装"
    fi

    # 检查是否已安装 pip
    if ! command -v pip3 &> /dev/null
    then
        echo "pip 未安装，正在安装 pip..."
        sudo apt install -y python3-pip
    else
        echo "pip 已安装"
    fi

    # 检查是否已安装 Docker
    if ! command -v docker &> /dev/null
    then
        echo "Docker 未安装，正在安装 Docker..."

        # 安装 Docker 的 GPG 密钥
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # 设置 Docker 的 APT 源
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # 更新 APT 软件包索引
        sudo apt update -y

        # 安装 Docker CE、Docker CLI 和 containerd.io
        sudo apt install -y docker-ce docker-ce-cli containerd.io

        # 配置 Docker 权限
        echo "配置 Docker 权限..."
        sudo groupadd docker
        sudo usermod -aG docker $USER

        # 验证 Docker 安装
        docker version
    else
        echo "Docker 已安装"
    fi

    # 检查是否已安装 Docker Compose
    if ! command -v docker-compose &> /dev/null
    then
        echo "Docker Compose 未安装，正在安装 Docker Compose..."

        # 获取最新版本的 Docker Compose
        VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)

        # 下载 Docker Compose 二进制文件
        curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

        # 赋予执行权限
        sudo chmod +x /usr/local/bin/docker-compose

        # 验证 Docker Compose 安装
        docker-compose --version
    else
        echo "Docker Compose 已安装"
    fi

    # 检查是否已安装 Go
    if ! command -v go &> /dev/null
    then
        echo "Go 未安装，正在安装 Go..."

        # 安装 Go
        cd $HOME
        ver="1.21.3"
        wget https://mirrors.tuna.tsinghua.edu.cn/golang/go1.21.3.linux-amd64.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
        rm "go$ver.linux-amd64.tar.gz"
        echo "export PATH=\$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
        source $HOME/.bash_profile

        # 验证 Go 安装
        go version
    else
        echo "Go 已安装"
    fi

    # 安装 Allorad
    if ! command -v allorad &> /dev/null
    then
        echo "Allorad 未安装，正在安装 Allorad..."

        # 克隆 Allorad 仓库并编译
        git clone https://github.com/allora-network/allora-chain.git
        cd allora-chain || { echo "无法进入 allora-chain 目录"; exit 1; }
        make all

        # 确保 Allorad 可执行文件路径在 PATH 中
        echo "export PATH=\$PATH:$HOME/allora-chain/bin" >> $HOME/.bash_profile
        source $HOME/.bash_profile

        # 验证 Allorad 安装
        allorad version
    else
        echo "Allorad 已安装"
    fi

    # 钱包操作
    echo "选择钱包操作："
    echo "1) 创建新钱包"
    echo "2) 导入现有钱包"
    read -p "请输入 1 或 2 进行选择: " choice

    case $choice in
        1)
            echo "创建新钱包..."
            allorad keys add testkey
            ;;
        2)
            echo "导入现有钱包(24位)..."
            allorad keys add testkey --recover
            ;;
        *)
            echo "无效选择，请输入 1 或 2。"
            ;;
    esac

    # 等待用户按任意键返回主菜单
    echo "按任意键返回主菜单..."
    read -n 1 -s
}

# 检查 Allorad 安装是否正常的函数
function check_installation() {
    cd $HOME/allora-chain || { echo "无法进入 allora-chain 目录"; exit 1; }
    
    echo "正在检查 Allorad 安装是否正常..."

    # 执行检查命令
    result=$(curl --location 'http://localhost:6000/api/v1/functions/execute' \
    --header 'Content-Type: application/json' \
    --data '{
        "function_id": "bafybeigpiwl3o73zvvl6dxdqu7zqcub5mhg65jiky2xqb4rdhfmikswzqm",
        "method": "allora-inference-function.wasm",
        "parameters": null,
        "topic": "1",
        "config": {
            "env_vars": [
                {
                    "name": "BLS_REQUEST_PATH",
                    "value": "/api"
                },
                {
                    "name": "ALLORA_ARG_PARAMS",
                    "value": "ETH"
                }
            ],
            "number_of_nodes": -1,
            "timeout": 2
        }
    }')

    # 预期结果
    expected_result='{
      "code": "200",
      "request_id": "03001a39-4387-467c-aba1-c0e1d0d44f59",
      "results": [
        {
          "result": {
            "stdout": "{\"value\":\"2564.021586281073\"}",
            "stderr": "",
            "exit_code": 0
          },
          "peers": [
            "12D3KooWG8dHctRt6ctakJfG5masTnLaKM6xkudoR5BxLDRSrgVt"
          ],
          "frequency": 100
        }
      ],
      "cluster": {
        "peers": [
          "12D3KooWG8dHctRt6ctakJfG5masTnLaKM6xkudoR5BxLDRSrgVt"
        ]
      }
    }'

    # 比较结果
    if [[ "$result" == *"$expected_result"* ]]; then
        echo "Allorad 安装正常。"
    else
        echo "Allorad 安装异常。"
        echo "检查结果: $result"
    fi

    # 等待用户按任意键返回主菜单
    echo "按任意键返回主菜单..."
    read -n 1 -s
}

function execute_work_task_1() {
    echo "正在执行工作任务 1..."

    # 克隆 basic-coin-prediction-node 仓库并进入目录
    cd $HOME || { echo "无法进入 $HOME 目录"; exit 1; }
    git clone https://github.com/allora-network/basic-coin-prediction-node || { echo "克隆仓库失败"; exit 1; }
    cd basic-coin-prediction-node || { echo "无法进入 basic-coin-prediction-node 目录"; exit 1; }

    # 删除旧的配置文件并提示用户创建新的配置文件
    rm -f config.json
    echo "请提供 addressRestoreMnemonic 和 Polkachu RPC 信息。"
    echo "请在下面的配置文件中填写这些信息："
    echo "{"
    echo "  \"addressRestoreMnemonic\": \"你的地址恢复助记词\","
    echo "  \"Polkachu RPC\": \"你的Polkachu RPC地址\""
    echo "}"
    echo "请创建新的配置文件 config.json:"
    nano config.json

    # 提示用户按任意键继续
    read -p "编辑完成后，请按任意键继续执行下一步..." -n1 -s
    echo

    # 创建目录、设置权限，并执行 init.config
    mkdir -p worker-data
    chmod +x init.config
    ./init.config || { echo "初始化配置失败"; exit 1; }

    # 构建并启动 Docker 容器
    echo "正在构建并启动 Docker 容器..."
    docker compose up --build -d || { echo "启动 Docker 容器失败"; exit 1; }

    # 提示用户按任意键返回主菜单
    read -p "Docker 容器启动完成，请按任意键返回主菜单..." -n1 -s
    echo
}

# 查看工人日志的函数
function view_worker_logs() {
    
    # 切换到指定目录
    cd /root/basic-coin-prediction-node || { echo "目录 /root/basic-coin-prediction-node 不存在"; return 1; }
    
    # 查看工人日志
    echo "正在查看工人日志..."
    docker compose logs -f worker
    
    # 等待用户按任意键继续到查看 Inference 日志
    echo "按任意键继续查看 Inference 日志..."
    read -n 1 -s
    
    # 查看 Inference 日志
    echo "正在查看 Inference 日志..."
    docker compose logs -f inference
    
    # 等待用户按任意键继续到查看 Inference 请求
    echo "按任意键继续查看 ETH 请求的返回结果..."
    read -n 1 -s
    
    # 使用 curl 查看 ETH 请求的返回结果
    echo "正在查看 ETH 请求的返回结果..."
    curl -s http://localhost:8000/inference/ETH
   
    # 等待用户按任意键返回主菜单
    echo "按任意键返回主菜单..."
    read -n 1 -s
}

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "================================================================"
        echo "节点社区 Telegram 群组: https://t.me/niuwuriji"
        echo "节点社区 Telegram 频道: https://t.me/niuwuriji"
        echo "节点社区 Discord 社群: https://discord.gg/GbMV5EcNWF"
        echo "退出脚本，请按键盘ctrl c退出即可"
        echo "请选择要执行的操作:"
        echo "1) 安装和配置 Allorad 节点"
        echo "2) 执行工作任务 1"
        echo "3) 检查 Allorad 安装是否正常"
        echo "4) 查看日志"
        echo "5) 退出"
        echo "================================================================"
        read -r choice

        case $choice in
            1)
                install_and_configure_allorad
                ;;
            2)
                execute_work_task_1 
                ;;
            3)
                check_installation
                ;;
            4)
                view_worker_logs
                ;;
            5)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效的选项，请重新选择。"
                sleep 3
                ;;
        esac
    done
}

# 运行主菜单
main_menu
