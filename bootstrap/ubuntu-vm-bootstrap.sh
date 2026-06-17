#!/bin/bash
set -e

echo "==> Updating package index"
sudo apt update

echo "==> Installing base packages"
sudo apt install -y \
    qemu-guest-agent \
    curl \
    wget \
    git \
    htop \
    tmux \
    fzf \
    ufw \
    dnsutils \
    traceroute

echo "==> Enabling qemu-guest-agent"
sudo systemctl enable --now qemu-guest-agent

echo "==> Installing Docker"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker

echo "==> Adding $USER to docker group"
sudo usermod -aG docker $USER

echo ""
echo "Done. Log out and back in for docker group to take effect."