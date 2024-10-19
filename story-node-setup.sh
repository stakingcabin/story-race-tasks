#!/bin/bash

set -e

# edit as your need
MONIKER="story-node"
# ref: https://polkachu.com/testnets/story/snapshots  change according latest snapshot
RPC_ENDPOINT=https://story-testnet-rpc.polkachu.com:443
SNAPSHOT_URL="https://snapshots.polkachu.com/testnet-snapshots/story/story_1537011.tar.lz4"


log_green() { echo -e "\033[0;32m$1\033[0m"; }
log_blue() { echo -e "\033[0;34m$1\033[0m"; }
log_red() { echo -e "\033[0;31m$1\033[0m"; }


os_check() {
    if [[ "$(uname -a)" != *"Ubuntu"* ]]; then
        echo “Only Ubuntu is tested.”
        exit 1
    fi
}

install_bins() {
	log_green "install binarys"
    wget https://github.com/piplabs/story-geth/releases/download/v0.9.4/geth-linux-amd64
    chmod +x geth-linux-amd64
    sudo mv geth-linux-amd64 /usr/local/bin/geth
    wget -qO- https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.11.0-aac4bfe.tar.gz | tar xzf -
    sudo mv story-*/story /usr/local/bin && rm -rf story-*
}

create_el_service() {
    if [ ! -f /etc/systemd/system/geth.service ]; then
        echo "Creating geth.service..."
        sudo tee /etc/systemd/system/geth.service > /dev/null << EOF
[Unit]
Description=geth daemon
After=network-online.target

[Service]
User=ubuntu
ExecStart=geth --iliad --syncmode full
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    fi
}

create_cl_service() {
    if [ ! -f /etc/systemd/system/story.service ]; then
        echo "Creating story.service..."
        sudo tee /etc/systemd/system/story.service > /dev/null << EOF
[Unit]
Description=story daemon
After=network-online.target

[Service]
User=ubuntu
WorkingDirectory=$HOME/.story/story
ExecStart=story run
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    fi
}

initialize_story() {
	log_green "initialize story chain data"
	story init --network iliad --moniker $MONIKER
	PEERS=$(curl -sS $RPC_ENDPOINT/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)
	sed -i.bak -e "s/^seeds *=.*/seeds = \"$PEERS\"/" "$HOME/.story/story/config/config.toml"
}

process_snapshot_data() {
	mkdir ~/snapshot
	cd ~/snapshot
    wget -O snapshot.tar.lz4 $SNAPSHOT_URL
	lz4 -dc < snapshot.tar.lz4 | tar xvf -
	cp ~/.story/story/data/priv_validator_state.json data/
	rm -rf ~/.story/story/data
	mv data ~/.story/story/
	sudo rm -rf ~/snapshot
}

os_check
install_bins
initialize_story
process_snapshot_data
create_el_service
create_cl_service
sudo systemctl daemon-reload
sudo systemctl enable geth --now
sudo systemctl enable story --now