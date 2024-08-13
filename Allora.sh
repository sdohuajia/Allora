#!/bin/bash

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "================================================================"
        echo "节点社区 Telegram 群组: https://t.me/niuwuriji"
        echo "节点社区 Telegram 频道: https://t.me/niuwuriji"
        echo "节点社区 Discord 社群: https://discord.gg/GbMV5EcNWF"
        echo "退出脚本，请按键盘ctrl+c退出即可"
        echo "请选择要执行的操作:"
        echo "1) 安装 Allora 节点"
        echo "2) 启动 Allora 节点"
        echo "3) 停止 Allora 节点"
        echo "4) 退出脚本"

        read -p "请输入选项 (1-4): " choice

        case $choice in
            1) install_allora_node ;;
            2) start_allora_node ;;
            3) stop_allora_node ;;
            4) exit 0 ;;
            *) echo "无效的选项，请重试." ;;
        esac
    done
}

# 安装 Allora 节点
function install_allora_node() {
    echo "安装 Allora 节点"

    # Check if re-running after logout
    if [ -f ~/.docker_setup_stage ]; then
        stage=$(cat ~/.docker_setup_stage)
    else
        stage="start"
    fi

    # Update and Upgrade
    if [ "$stage" == "start" ]; then
        sudo apt update && sudo apt upgrade -y

        # Install Dependencies
        sudo apt install -y ca-certificates zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev curl git wget make jq build-essential pkg-config lsb-release libssl-dev libreadline-dev libffi-dev gcc screen unzip lz4 python3 python3-pip

        # Install Docker
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        docker version

        # Install Docker Compose
        VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
        sudo curl -L "https://github.com/docker/compose/releases/download/$VER/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        docker-compose --version

        # Docker Permission
        sudo groupadd docker || true
        sudo usermod -aG docker $USER

        echo "docker" > ~/.docker_setup_stage

        # Notify user to log out and back in
        echo -e "\e[31mPlease log out and log back in to apply Docker group changes.\e[0m"
        echo -e "\e[31mThen, re-run this script to continue the setup.\e[0m"

        # Stop script execution for manual action
        exit 0
    fi

    if [ "$stage" == "docker" ]; then
        # Install Go
        sudo rm -rf /usr/local/go
        curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
        echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> $HOME/.bash_profile
        source $HOME/.bash_profile
        go version

        # Install Allorad
        git clone https://github.com/allora-network/allora-chain.git
        cd allora-chain && make all
        allorad version

        # Key management
        echo "你想创建一个新钱包还是恢复现有钱包？ (Y/N)"
        read -r wallet_option

        if [ "$wallet_option" = "Y" ]; then
            allorad keys add testkey
        else
            allorad keys add testkey --recover
        fi

        # Install workers
        cd $HOME && git clone https://github.com/allora-network/basic-coin-prediction-node
        cd basic-coin-prediction-node

        mkdir workers
        mkdir workers/worker-1 workers/worker-2 workers/worker-3 head-data
        sudo chmod -R 777 workers/worker-1 workers/worker-2 workers/worker-3 head-data

        # Create head keys
        sudo docker run -it --entrypoint=bash -v "$PWD/head-data":/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"

        # Create worker keys
        for i in {1..3}; do
            sudo docker run -it --entrypoint=bash -v "$PWD/workers/worker-$i":/data alloranetwork/allora-inference-base:latest -c "mkdir -p /data/keys && (cd /data/keys && allora-keys)"
        done

        # Copy the head-id
        HEAD_ID=$(cat head-data/keys/identity)
        echo "保存这个 HEAD_ID: $HEAD_ID"

        # Save variables
        echo "请输入 WALLET_SEED_PHRASE:"
        read -r WALLET_SEED_PHRASE

        # Create docker-compose.yml
        cat > docker-compose.yml <<EOL
version: '3'

services:
  inference:
    container_name: inference
    build:
      context: .
    command: python -u /app/app.py
    ports:
      - "8000:8000"
    networks:
      eth-model-local:
        aliases:
          - inference
        ipv4_address: 172.22.0.4
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/inference/ETH"]
      interval: 10s
      timeout: 10s
      retries: 12
    volumes:
      - ./inference-data:/app/data

  updater:
    container_name: updater
    build: .
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
    command: >
      sh -c "
      while true; do
        python -u /app/update_app.py;
        sleep 24h;
      done
      "
    depends_on:
      inference:
        condition: service_healthy
    networks:
      eth-model-local:
        aliases:
          - updater
        ipv4_address: 172.22.0.5

  head:
    container_name: head
    image: alloranetwork/allora-inference-base-head:latest
    environment:
      - HOME=/data
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "生成新的私钥..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=head --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9000 --rest-api=:5001 \
          --boot-nodes=/dns4/head-0-p2p.v2.testnet.allora.network/tcp/32130/p2p/12D3KooWGKY4z2iNkDMERh5ZD8NBoAX6oWzkDnQboBRGFTpoKNDF
    ports:
      - "5001:5001"
    volumes:
      - ./head-data:/data
    networks:
      eth-model-local:
        aliases:
          - head
        ipv4_address: 172.22.0.100

  worker-1:
    container_name: worker-1
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
      - WALLET_SEED_PHRASE=${WALLET_SEED_PHRASE}
      - HEAD_ID=${HEAD_ID}
    image: alloranetwork/allora-inference-base-worker:latest
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "生成新的私钥..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9020 --rest-api=:6001 \
          --boot-nodes=/dns4/head-0-p2p.v2.testnet.allora.network/tcp/32130/p2p/12D3KooWGKY4z2iNkDMERh5ZD8NBoAX6oWzkDnQboBRGFTpoKNDF
    ports:
      - "6001:6001"
    volumes:
      - ./workers/worker-1:/data
    networks:
      eth-model-local:
        aliases:
          - worker-1
        ipv4_address: 172.22.0.101

  worker-2:
    container_name: worker-2
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
      - WALLET_SEED_PHRASE=${WALLET_SEED_PHRASE}
      - HEAD_ID=${HEAD_ID}
    image: alloranetwork/allora-inference-base-worker:latest
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "生成新的私钥..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9021 --rest-api=:6002 \
          --boot-nodes=/dns4/head-0-p2p.v2.testnet.allora.network/tcp/32130/p2p/12D3KooWGKY4z2iNkDMERh5ZD8NBoAX6oWzkDnQboBRGFTpoKNDF
    ports:
      - "6002:6002"
    volumes:
      - ./workers/worker-2:/data
    networks:
      eth-model-local:
        aliases:
          - worker-2
        ipv4_address: 172.22.0.102

  worker-3:
    container_name: worker-3
    environment:
      - INFERENCE_API_ADDRESS=http://inference:8000
      - HOME=/data
      - WALLET_SEED_PHRASE=${WALLET_SEED_PHRASE}
      - HEAD_ID=${HEAD_ID}
    image: alloranetwork/allora-inference-base-worker:latest
    entrypoint:
      - "/bin/bash"
      - "-c"
      - |
        if [ ! -f /data/keys/priv.bin ]; then
          echo "生成新的私钥..."
          mkdir -p /data/keys
          cd /data/keys
          allora-keys
        fi
        allora-node --role=worker --peer-db=/data/peerdb --function-db=/data/function-db \
          --runtime-path=/app/runtime --runtime-cli=bls-runtime --workspace=/data/workspace \
          --private-key=/data/keys/priv.bin --log-level=debug --port=9022 --rest-api=:6003 \
          --boot-nodes=/dns4/head-0-p2p.v2.testnet.allora.network/tcp/32130/p2p/12D3KooWGKY4z2iNkDMERh5ZD8NBoAX6oWzkDnQboBRGFTpoKNDF
    ports:
      - "6003:6003"
    volumes:
      - ./workers/worker-3:/data
    networks:
      eth-model-local:
        aliases:
          - worker-3
        ipv4_address: 172.22.0.103

networks:
  eth-model-local:
    ipam:
      config:
        - subnet: 172.22.0.0/16
EOL

    # Start Docker Compose
    sudo docker-compose up -d

    # Save the stage
    echo "done" > ~/.docker_setup_stage
}

# 启动 Allora 节点
function start_allora_node() {
    echo "启动 Allora 节点"
    sudo docker-compose up -d
}

# 停止 Allora 节点
function stop_allora_node() {
    echo "停止 Allora 节点"
    sudo docker-compose down
}

# 运行主菜单函数
main_menu
