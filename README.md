# AquaSense — Project Backup

> **Backup repository** for **AquaSense**, an application-based ammonia monitoring device for small-scale aquaculture farms.
> *Cagayan State University, Carig Campus · College of Information and Computing Sciences · BS Computer Science · October 2026*

This repository exists to **keep a safe, restorable copy of the AquaSense project**: the Flutter mobile app source, and a written record of the hardware build and wiring so the prototype can be rebuilt if anything is lost.

---

## What is backed up

| Part | Status | Where |
|------|--------|-------|
| Mobile app (Flutter / Dart) | ✅ Included | `lib/`, `android/`, `assets/`, `pubspec.yaml` |
| Hardware build + wiring notes | ✅ Documented below | [Hardware backup](#hardware-backup) |
| ESP32 firmware (Arduino IDE sketch) | ✅ Included | `firmware/ESP_Code.ino` |

---

## About the project

Ammonia is the main metabolic waste of fish; low levels stress them and harm gills, high levels kill. Commercial water-quality systems are costly, so AquaSense proposes a low-cost prototype that:

1. Detects ammonia gas released from water samples in an enclosed test chamber.
2. Shows near-real-time readings in a mobile app.
3. Warns the user (app alerts, on-device buzzer) when readings pass a set threshold.
4. Stores previous readings for monitoring and comparison.

> The MQ-137 is a gas sensor: it is an **indicator** of ammonia, not a direct water measurement. The app reports a raw ADC value and a derived 0–100 index.

## App

Built with **Flutter / Dart** (SDK `>=3.3.0 <4.0.0`). The app talks directly to the ESP32 over its own Wi-Fi access point — **no internet needed**.

Screens: **Home · Sensors · Control · Records · Settings**, plus a built-in assistant and a **demo mode** (simulated data) for use without hardware.

Dependencies: `http`, `shared_preferences`, `path_provider`, `intl`, `table_calendar`.

### Build and run

```bash
flutter pub get
flutter run                 # debug on a connected Android device
flutter build apk --release # output: build/app/outputs/flutter-apk/app-release.apk
```

To regenerate the launcher icons: `dart run flutter_launcher_icons`.

### Connect to the device

1. Power the sensor box.
2. On the phone, join the Wi-Fi network **`AmmoniaMonitor`**.
3. Open AquaSense and connect (default host `192.168.4.1`).

No device? Use **demo mode** from the connect screen.

## Data backup (readings)

Readings are stored in two places, so nothing is lost when the app closes:

- **On the sensor box** — a CSV on the ESP32's flash memory.
- **On the phone** — `ammonia_history.csv` in the app documents folder, updated each time the app syncs history from the device.

Record format (one reading per line):

```
epoch,raw,level,temp,hum
```

`level` is one of `low`, `mid`, `high`, `fault`, `warmup`. `epoch` is local time written as Unix seconds (the RTC convention). Merging is by `epoch`, so syncing repeatedly never creates duplicates.

⚠️ **Settings → Clear all records** deletes both the phone copy and the device copy. Copy the CSV somewhere safe first.

## Hardware backup

**Components:** ESP32 dev board, MQ-137 gas sensor, DHT22 (temp/humidity), DS3231 RTC, SSD1306 OLED / I2C LCD, buzzer, relay, 12 V fan, 12 V AC-to-DC supply, buck converter (12 V → 5 V), jumper wires, plastic enclosure.

**Wiring:**

| Part | Connection |
|------|-----------|
| AC supply | Live→Live, Earth→Earth, Neutral→Neutral (via AC inlet on back cover) |
| Buck converter | In: supply +/−. **Set output to 5 V before connecting the ESP32.** |
| ESP32 / DHT22 | Buck + → ESP32 5V and DHT22 VCC; buck − → ESP32 GND and DHT22 GND (common ground) |
| RTC (DS3231) | VCC → ESP32 3.3V, GND → common ground |
| Fan | + → supply +, − → Relay Channel 1 |
| Buzzer | + → supply +, − → Relay Channel 2 (controlled by GPIO 26) |
| MQ-137 | AO → GPIO 34, DO → GPIO 27, VCC → buck +, GND → common ground (on quick-release connectors) |
| I2C LCD | VCC → supply, GND → common ground, SDA → GPIO 21, SCL → GPIO 22 (bus shared with RTC) |

**Buzzer patterns:** slow beep = medium ammonia · rapid beeps = high ammonia · two beeps every two seconds = sensor failure.

**Assembly order:** enclosure + AC power → fan + buck converter → DHT22 + RTC → buzzer → AC inlet cutout → front cover (LCD + MQ-137 connectors) → test all wiring with a multimeter → program ESP32 (Arduino IDE, Wi-Fi AP mode) and install the app → reinstall ESP32 and close the enclosure.

> ⚠️ Mains voltage is involved. Check every wire with a multimeter and inspect for shorts before powering on.

## Firmware

`firmware/ESP_Code.ino` is the full ESP32 sketch (v4, Arduino IDE with the ESP32 board package). Libraries (Library Manager): `LiquidCrystal_I2C`, `RTClib`, `DHT sensor library` + `Adafruit Unified Sensor`. `WiFi`, `WebServer`, `LittleFS` and `Preferences` ship with the board package.

What it does:

- Reads the MQ-137 (averaged over 40 samples) and the DHT22 every 2 s, and shows live data on the 16x2 I2C LCD (address `0x27`, try `0x3F` if blank), rotating through 4 pages.
- **Ghost-data protection:** an unplugged or floating MQ-137 is flagged as a sensor fault (noise, sudden-jump and DO-pin checks). Level changes must repeat on consecutive reads before an alarm is raised. Add a 10k resistor from GPIO 34 to GND so a pulled-out wire reads ~0.
- **Levels:** `low` / `mid` / `high` from raw ADC thresholds (defaults 1200 / 2200), with a 60 s sensor warm-up.
- **Buzzer:** high = rapid beep, sensor fault = 2 short beeps every 2 s, mid = slow beep.
- **Fan:** auto (turns on at the set temperature, default 32 °C, off 2 °C lower) or forced on/off from the app.
- **Wi-Fi AP** `AmmoniaMonitor` at `192.168.4.1` serving the [Device API](#device-api) below.
- **Logging:** one reading every 30 minutes to `/log.csv` on flash (rotates at about 60 KB). Thresholds and fan mode are saved in flash and survive power loss.

| Pin | Use |
|-----|-----|
| GPIO 34 / 27 | MQ-137 AO / DO |
| GPIO 4 | DHT22 data |
| GPIO 21 / 22 | I2C SDA / SCL (RTC + LCD) |
| GPIO 25 | Fan relay (CH1) |
| GPIO 26 | Buzzer relay (CH2) |

Relay polarity is set by `RELAY_ACTIVE_LOW` (currently `false`).

> ⚠️ The Wi-Fi password is hard-coded as `12345678` (`AP_PASS`). Change it for any real deployment.

## Device API

The app calls these HTTP endpoints on the ESP32 (implemented in `firmware/ESP_Code.ino`):

| Endpoint | Purpose |
|----------|---------|
| `GET /api/status` | Live data: raw ADC, level, temp, humidity, sensor health, fan/buzzer state, thresholds, clock |
| `GET /api/history` | Stored readings, CSV lines |
| `GET /api/settime?epoch=` | Sync device clock from the phone |
| `GET /api/fan?mode=auto\|on\|off` | Fan mode |
| `GET /api/config?mid=&high=&fanon=` | Alarm thresholds (raw ADC) and fan-on temperature |
| `GET /api/clear` | Erase stored records |

## Repository layout

```
lib/            Flutter app (main, esp_service, models, assistant, pages/…)
firmware/       ESP32 Arduino sketch
android/        Android project (app name "AquaSense")
assets/icon/    Launcher icons
pubspec.yaml    Dependencies
```

## Team

Concepcion, Jason Keith A. · Fariñas, Mark James M. · Galera, Venz Jochen B. · Co, Gie-Anne Carla S. · Espino, Josaine L. · Lozano, Joyce T. · Lamer, Rhea E.

Cagayan State University, College of Information and Computing Sciences
