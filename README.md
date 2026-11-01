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
| ESP32 sketch (Arduino IDE) | ✅ Included — hardware test version | `firmware/ESP_Code.ino` |

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

`firmware/ESP_Code.ino` is the hardware test sketch (Arduino IDE, ESP32 board library; libraries: `DHT`, `RTClib`, `LiquidCrystal_I2C`). It currently:

- reads the DHT22 and shows temperature/humidity on the 16x2 I2C LCD (address `0x27`), alternating with the DS3231 date and time every 2 s;
- switches the fan relay (GPIO 25) on at 40 °C and off below it;
- runs a buzzer test (relay on GPIO 26, active-LOW): slow beeps, then fast beeps, repeating in a loop.

It does **not** yet include the MQ-137 reading, Wi-Fi access point, the HTTP endpoints below, or record storage, which the app needs. Upload the full firmware to `firmware/` to complete the backup.

## Device API

The app calls these HTTP endpoints on the ESP32 (they are **not** implemented in `firmware/ESP_Code.ino` yet, see Firmware above):

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
