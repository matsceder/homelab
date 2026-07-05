#!/bin/bash
# ============================================================
# verify-kube-node.sh
# Kontrollerar att ubuntu-vm-kube-bootstrap.sh gick igenom.
# Kör efter bootstrap, före kubeadm init/join.
# Ingen set -e – vi vill att alla kontroller körs även om en fallerar.
# ============================================================

FAILS=0
pass() { echo -e "  [\e[32mOK\e[0m] $1"; }
fail() { echo -e "  [\e[31mFEL\e[0m] $1"; FAILS=$((FAILS+1)); }

echo "==> Swap"
if [ -z "$(swapon --show)" ]; then
    pass "Swap är inaktiverat"
else
    fail "Swap är fortfarande aktivt"
fi

echo "==> Kernel-moduler"
for mod in overlay br_netfilter; do
    if lsmod | grep -q "^$mod"; then
        pass "$mod är laddad"
    else
        fail "$mod är inte laddad"
    fi
done

echo "==> Kernel-parametrar"
for param in net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward; do
    val=$(sysctl -n "$param" 2>/dev/null)
    if [ "$val" = "1" ]; then
        pass "$param = 1"
    else
        fail "$param = $val (förväntat 1)"
    fi
done

echo "==> Containerd"
if systemctl is-active --quiet containerd; then
    pass "containerd körs"
else
    fail "containerd körs inte"
fi
if grep -q "SystemdCgroup = true" /etc/containerd/config.toml 2>/dev/null; then
    pass "SystemdCgroup = true"
else
    fail "SystemdCgroup är inte satt till true"
fi

echo "==> Docker"
if systemctl is-active --quiet docker; then
    pass "docker körs"
else
    fail "docker körs inte"
fi

echo "==> qemu-guest-agent"
if systemctl is-active --quiet qemu-guest-agent; then
    pass "qemu-guest-agent körs"
else
    fail "qemu-guest-agent körs inte"
fi

echo "==> Kubernetes-verktyg"
for tool in kubeadm kubelet kubectl; do
    if command -v "$tool" >/dev/null; then
        pass "$tool installerat"
    else
        fail "$tool saknas"
    fi
done

echo "==> apt-mark hold"
held=$(apt-mark showhold)
for pkg in kubelet kubeadm kubectl; do
    if echo "$held" | grep -q "^$pkg$"; then
        pass "$pkg är låst (hold)"
    else
        fail "$pkg är inte låst"
    fi
done

echo ""
if [ "$FAILS" -eq 0 ]; then
    echo -e "\e[32mAllt OK. Noden är redo för kubeadm init/join.\e[0m"
else
    echo -e "\e[31m$FAILS kontroll(er) misslyckades. Åtgärda innan du kör kubeadm.\e[0m"
    exit 1
fi
