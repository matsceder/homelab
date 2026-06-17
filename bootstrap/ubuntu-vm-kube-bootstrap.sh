#!/bin/bash
set -e

# ============================================================
# ubuntu-vm-kube-bootstrap.sh
# Bootstrap för Ubuntu Server 24.04 VM avsedd som Kubernetes-nod.
# Innehåller allt från ubuntu-vm-bootstrap.sh plus Kubernetes-förberedelser.
# ============================================================

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
    traceroute \
    apt-transport-https \
    ca-certificates

echo "==> Enabling qemu-guest-agent"
sudo systemctl enable --now qemu-guest-agent

# ------------------------------------------------------------
# Docker + containerd
# ------------------------------------------------------------
echo "==> Installing Docker"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker

echo "==> Adding $USER to docker group"
sudo usermod -aG docker $USER

# ------------------------------------------------------------
# Swap
# ------------------------------------------------------------
echo "==> Disabling swap"
sudo swapoff -a
sudo sed -i '/\sswap\s/d' /etc/fstab

# ------------------------------------------------------------
# Kernel-moduler
# ------------------------------------------------------------
echo "==> Loading kernel modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# ------------------------------------------------------------
# Kernel-parametrar
# ------------------------------------------------------------
echo "==> Setting kernel parameters"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# ------------------------------------------------------------
# Containerd-konfiguration för Kubernetes
# ------------------------------------------------------------
echo "==> Configuring containerd for Kubernetes"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# ------------------------------------------------------------
# kubeadm, kubelet, kubectl
# ------------------------------------------------------------
echo "==> Installing kubeadm, kubelet, kubectl"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo ""
echo "Done. Log out and back in for docker group to take effect."
echo "Node is ready for kubeadm init (controller) or kubeadm join (worker)."
