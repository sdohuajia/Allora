#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Allora.sh"

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "新建了一个电报群，方便大家交流：t.me/Sdohua"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1) 部署节点"
        echo "2) 查看 Worker 容器日志"
        echo "3) 查看 Main 日志"
        echo "4) 退出"
        read -p "输入选项: " option
        case $option in
            1) deploy_node;;
            2) view_worker_logs;;
            3) view_main_logs;;
            4) exit 0;;
            *) echo "无效选项，请重试";;
        esac
        read -p "按任意键继续..."
    done
}

# 部署节点
function deploy_node() {
    # 安装依赖
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl git wget make jq build-essential pkg-config lsb-release libssl-dev libreadline-dev libffi-dev gcc screen unzip lz4 python3 python3-pip

    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        docker version

        # Docker 权限
        sudo groupadd docker || true
        sudo usermod -aG docker $USER
    else
        echo -e "\e[32mDocker 已经安装。\e[0m"
    fi

    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
        sudo curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        docker-compose --version
    else
        echo -e "\e[32mDocker Compose 已经安装。\e[0m"
    fi

    # 设置 Allora 工作节点
    echo -e "\e[33m您之前运行过此 Allora 工作节点设置吗？ (yes/no)\e[0m"
    read -r has_run_before

    if [ "$has_run_before" == "yes" ]; then
        cd $HOME && cd basic-coin-prediction-node
        docker compose down -v
        docker container prune -f
        cd $HOME && rm -rf basic-coin-prediction-node
    fi

    # 克隆并配置 HuggingFace 工作节点
    cd $HOME
    git clone https://github.com/allora-network/allora-huggingface-walkthrough
    cd allora-huggingface-walkthrough
    mkdir -p worker-data
    chmod -R 777 worker-data
    cp config.example.json config.json

    # 请求钱包助记词
    echo -e "\e[33m请输入您的钱包助记词:\e[0m"
    read -r wallet_phrases

    # 请求 Coingecko API 密钥
    echo -e "\e[33m请输入您的 Coingecko API 密钥:\e[0m"
    read -r coingecko_api_key

    # 在配置中替换钱包助记词并包含主题
    cat <<EOF > config.json
{
    "wallet": {
        "addressKeyName": "testkey",
        "addressRestoreMnemonic": "$wallet_phrases",
        "alloraHomeDir": "/root/.allorad",
        "gas": "1000000",
        "gasAdjustment": 1.0,
        "nodeRpc": "https://rpc.ankr.com/allora_testnet",
        "maxRetries": 1,
        "delay": 1,
        "submitTx": false
    },
    "worker": [
        {
            "topicId": 1,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 1,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "ETH"
            }
        },
        {
            "topicId": 2,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 3,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "ETH"
            }
        },
        {
            "topicId": 3,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 5,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "BTC"
            }
        },
        {
            "topicId": 4,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 2,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "BTC"
            }
        },
        {
            "topicId": 5,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 4,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "SOL"
            }
        },
        {
            "topicId": 6,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 5,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "SOL"
            }
        },
        {
            "topicId": 7,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 2,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "ETH"
            }
        },
        {
            "topicId": 8,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 3,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "BNB"
            }
        },
        {
            "topicId": 9,
            "inferenceEntrypointName": "api-worker-reputer",
            "loopSeconds": 5,
            "parameters": {
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",
                "Token": "ARB"
            }
        }
    ]
}
EOF

    # 用钱包名称替换 testkey
    wallet_name=$(allorad keys list | grep -o 'testkey')
    sed -i "s/testkey/$wallet_name/g" config.json

    # 如果 env 文件不存在，则创建
    if [ ! -f /root/allora-huggingface-walkthrough/worker-data/env_file ]; then
        cat <<EOF > /root/allora-huggingface-walkthrough/worker-data/env_file
WALLET_PHRASES="$wallet_phrases"
INFERENCE_ENDPOINT="http://inference:8000"
TOKEN="ETH"
EOF
        echo "环境文件已创建。"
    fi

    # 设置 worker-data 目录的正确权限
    chmod -R 777 /root/allora-huggingface-walkthrough/worker-data

    # 自动导入 Coingecko API 密钥到 app.py
    sed -i "s|\"x-cg-demo-api-key\": \".*\"|\"x-cg-demo-api-key\": \"$coingecko_api_key\"|g" app.py

    # 运行 Huggingface 工作节点
    chmod +x init.config
    ./init.config
    docker compose up --build -d
}

# 查看 Worker 容器日志
function view_worker_logs() {
    cd $HOME/allora-huggingface-walkthrough && docker compose logs -f worker
}

# 查看 Main 日志
function view_main_logs() {
    cd $HOME/allora-huggingface-walkthrough && docker compose logs -f
}

# 调用主菜单函数
main_menu
