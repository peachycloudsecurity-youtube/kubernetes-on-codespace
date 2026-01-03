#!/usr/bin/env bash
set -euo pipefail

WORKDIR="$(pwd)"
LOG_FILE="/tmp/k3s.log"

echo "[+] Working directory: ${WORKDIR}"

echo "[+] Installing k3s (if not already installed)"
if ! command -v k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | sh -
else
  echo "[+] k3s already installed, skipping install"
fi

echo "[+] Stopping any existing k3s processes"
sudo pkill -9 k3s 2>/dev/null || true
sleep 3

echo "[+] Cleaning previous k3s state"
sudo rm -rf /var/lib/rancher/k3s /run/k3s

echo "[+] Writing k3s config (native snapshotter)"
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml > /dev/null << 'EOF'
snapshotter: "native"
write-kubeconfig-mode: "644"
EOF

echo "[+] Starting k3s server"
sudo k3s server > "${LOG_FILE}" 2>&1 &

# ---- VALIDATION 1: k3s process / API started ----
echo "[+] Waiting for k3s process to start"
timeout=120
until grep -q "k3s is up and running" "${LOG_FILE}" 2>/dev/null; do
  sleep 2
  timeout=$((timeout - 2))
  if [ "$timeout" -le 0 ]; then
    echo "[!] k3s failed to start (log signal not seen)"
    tail -50 "${LOG_FILE}"
    exit 1
  fi
done

# ---- VALIDATION 2: node actually Ready ----
echo "[+] Waiting for node to become Ready"
timeout=120
until sudo k3s kubectl get nodes 2>/dev/null | grep -q " Ready "; do
  sleep 3
  timeout=$((timeout - 3))
  if [ "$timeout" -le 0 ]; then
    echo "[!] Node did not become Ready"
    sudo k3s kubectl get nodes || true
    tail -50 "${LOG_FILE}"
    exit 1
  fi
done

echo "[+] Exporting KUBECONFIG"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
if ! grep -q "KUBECONFIG=/etc/rancher/k3s/k3s.yaml" ~/.bashrc 2>/dev/null; then
  echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
fi

echo "[+] Ensuring kubectl uses k3s"
sudo ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl


echo "[+] Verifying cluster"
sudo k3s kubectl get nodes
sudo k3s kubectl get ns

echo "[✓] k3s bootstrap completed successfully"
