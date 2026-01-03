#!/usr/bin/env bash
set -euo pipefail

echo "[+] Stopping k3s processes"
sudo pkill -9 k3s 2>/dev/null || true
sleep 2

echo "[+] Removing k3s state directories"
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /run/k3s

echo "[+] Removing kubeconfig exports from shell config"
sed -i '/KUBECONFIG=\/etc\/rancher\/k3s\/k3s.yaml/d' ~/.bashrc || true

echo "[+] Cleaning up kubectl cache"
rm -rf ~/.kube/cache || true

echo "[+] Verifying k3s is stopped"
if ps aux | grep -q '[k]3s'; then
  echo "[!] Warning: k3s process still running"
else
  echo "[✓] k3s processes stopped"
fi

echo "[✓] k3s cleanup completed"
