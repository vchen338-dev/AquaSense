/*
  ESP32 Ammonia Monitor  (v4 - anti-ghost-data sensor checks)

  Hardware: MQ-137 + DHT22 + DS3231 RTC + 16x2 I2C LCD + fan relay + buzzer relay

  Libraries (Library Manager):
    - LiquidCrystal_I2C (Frank de Brabander)
    - RTClib (Adafruit)
    - DHT sensor library (Adafruit) + Adafruit Unified Sensor
  (WiFi, WebServer and LittleFS come with the ESP32 board package)

  Pins:
    MQ-137 AO  -> GPIO34 (ADC1, input only)  [use a voltage divider if module is 5V]
    MQ-137 DO  -> GPIO27
    DHT22 data -> GPIO4
    SDA        -> GPIO21 (RTC + LCD)
    SCL        -> GPIO22 (RTC + LCD)
    Fan relay  -> GPIO25 (CH1)
    Buzzer     -> GPIO26 (CH2)

  Alarm behaviour:
    NH3 HIGH         -> rapid beep (100ms on / 100ms off)
    sensor fault     -> 2 short beeps every 2 seconds
    NH3 MID          -> slow beep (200ms on / 800ms off)
    DHT22 temp high  -> fan ON (with hysteresis)

  Unplugged-sensor tip: an analog pin with nothing on it "floats" and reads random
  values. Solder a 10k resistor from GPIO34 to GND (or use your 5V->3.3V voltage
  divider, whose bottom resistor does the same job). Then a pulled-out AO wire reads ~0
  and the 2-beeps-every-2-seconds fault fires instantly.

  WiFi: the ESP32 creates its own network
    SSID: AmmoniaMonitor   Password: 12345678   IP: 192.168.4.1
  API:
    GET /api/status            live data as JSON
    GET /api/history           CSV log (epoch,raw,level,temp,hum), one row / 30 min
    GET /api/settime?epoch=N   set RTC (N = local time expressed as unix seconds)
    GET /api/clear             erase the stored log
    GET /api/config            read settings; add ?mid=1200&high=2200&fanon=32 to change them
    GET /api/fan?mode=auto|on|off   fan control (auto = temperature controlled)
  Settings are saved in flash (Preferences) and survive power loss.
*/

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <RTClib.h>
#include <DHT.h>
#include <WiFi.h>
#include <WebServer.h>
#include <LittleFS.h>
#include <Preferences.h>

// ---------------- Pins ----------------
#define PIN_MQ_AO   34
#define PIN_MQ_DO   27
#define PIN_DHT      4
#define PIN_FAN     25
#define PIN_BUZZER  26

// Relay polarity (you flipped it to false earlier). true = LOW turns relay ON.
#define RELAY_ACTIVE_LOW false

// ---------------- WiFi ----------------
#define AP_SSID     "AmmoniaMonitor"
#define AP_PASS     "12345678"        // min 8 characters

// ---------------- Default thresholds (the app can change them) ----------------
#define DEF_NH3_MID_ADC     1200
#define DEF_NH3_HIGH_ADC    2200
#define DEF_TEMP_FAN_ON_C   32.0
#define FAN_HYSTERESIS_C    2.0     // fan turns off this many degrees below the ON temp

#define MQ_FAULT_LOW      30
#define MQ_FAULT_HIGH   4090

// ---- Ghost-data protection (a floating/unplugged analog pin reads random values) ----
#define MQ_NOISE_MAX     250     // max-min spread inside one 40 ms sample burst; above = noisy/unplugged
#define MQ_JUMP_MAX     1200     // change between two 2 s reads that real gas cannot cause
#define MQ_FAULT_SET       2     // bad reads in a row before the fault is raised (4 s)
#define MQ_FAULT_CLEAR     8     // good reads in a row before the fault is cleared (16 s)
#define CHECK_DO_FLOAT  true     // detect an unplugged module by testing the DO pin (see doFloating)
// Level changes must be confirmed by consecutive reads so one random spike cannot cause an alarm
#define CONFIRM_HIGH       3     // 6 s above the HIGH level
#define CONFIRM_MID        2     // 4 s above the MID level
#define CONFIRM_DOWN       3     // 6 s below before the level drops

#define MQ_WARMUP_MS    60000UL

// ---------------- Logging ----------------
#define LOG_INTERVAL_S  1800UL        // 30 minutes
#define LOG_FILE        "/log.csv"
#define LOG_FILE_OLD    "/log_old.csv"
#define LOG_MAX_BYTES   60000

#define LCD_ADDR        0x27          // try 0x3F if the LCD stays blank

// ---------------- Objects ----------------
LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);
RTC_DS3231 rtc;
DHT dht(PIN_DHT, DHT22);
WebServer server(80);
Preferences prefs;

// ---------------- State ----------------
enum NH3Level { NH3_UNKNOWN, NH3_LOW, NH3_MID, NH3_HIGH };
enum FanMode  { FAN_AUTO, FAN_FORCE_ON, FAN_FORCE_OFF };

// Settings (loaded from flash in setup)
int     nh3Mid   = DEF_NH3_MID_ADC;
int     nh3High  = DEF_NH3_HIGH_ADC;
float   fanOnC   = DEF_TEMP_FAN_ON_C;
FanMode fanMode  = FAN_AUTO;

int       mqRaw       = 0;
bool      mqDO_alarm  = false;
float     temperature = NAN;
float     humidity    = NAN;
bool      mqFault     = false;
bool      dhtFault    = false;
bool      rtcOk       = false;    // RTC chip answered on I2C
bool      rtcFault    = false;    // missing or lost power
bool      lcdOk       = false;
bool      fanOn       = false;
bool      buzzerOn    = false;
NH3Level  level       = NH3_UNKNOWN;
int       mqSpread    = 0;        // noise inside the last sample burst
int       mqPrev      = -1;       // previous 2 s reading (for jump detection)
uint8_t   mqBad = 0, mqGood = 0;
bool      mqLatched   = false;
NH3Level  confirmed   = NH3_LOW;  // confirmed (debounced) level
NH3Level  cand        = NH3_LOW;
uint8_t   candCount   = 0;

unsigned long lastSensorRead = 0;
unsigned long lastLcd        = 0;
unsigned long lastPage       = 0;
uint8_t       page           = 0;
uint8_t       dhtFailCount   = 0;
uint32_t      lastLogSlot    = 0xFFFFFFFF;

// ---------------- Helpers ----------------
void relayWrite(uint8_t pin, bool on) {
  digitalWrite(pin, (RELAY_ACTIVE_LOW ? !on : on) ? HIGH : LOW);
}

// 40 samples over ~40 ms (covers two 50/60 Hz mains cycles). Returns the mean
// and the spread (max-min). A real MQ output is steady, a floating pin is not.
int readMQ(int &spread) {
  long sum = 0;
  int mn = 4095, mx = 0;
  for (int i = 0; i < 40; i++) {
    int v = analogRead(PIN_MQ_AO);
    sum += v;
    if (v < mn) mn = v;
    if (v > mx) mx = v;
    delay(1);
  }
  spread = mx - mn;
  return sum / 40;
}

// Is the DO wire connected to a powered module?
// A connected module drives DO (high with no gas, low with gas), so it ignores our
// internal pull resistors. A floating pin simply follows them: HIGH with pull-up and
// LOW with pull-down. Gas (LOW) never looks floating because it stays LOW on pull-up.
bool doFloating() {
  pinMode(PIN_MQ_DO, INPUT_PULLUP);
  delayMicroseconds(300);
  bool up = digitalRead(PIN_MQ_DO);
  pinMode(PIN_MQ_DO, INPUT_PULLDOWN);
  delayMicroseconds(300);
  bool dn = digitalRead(PIN_MQ_DO);
  pinMode(PIN_MQ_DO, INPUT);
  return up && !dn;
}

bool i2cPresent(uint8_t addr) {
  Wire.beginTransmission(addr);
  return Wire.endTransmission() == 0;
}

const char *levelText() {
  switch (level) {
    case NH3_LOW:  return "LOW";
    case NH3_MID:  return "MID";
    case NH3_HIGH: return "HIGH";
    default:       return mqFault ? "ERR" : "WARM";
  }
}

// lower-case token used by the app / CSV
const char *levelToken() {
  switch (level) {
    case NH3_LOW:  return "low";
    case NH3_MID:  return "mid";
    case NH3_HIGH: return "high";
    default:       return mqFault ? "fault" : "warmup";
  }
}

uint32_t nowEpoch() {
  return rtcOk ? rtc.now().unixtime() : 0;
}

// ---------------- Settings ----------------
const char *fanModeToken() {
  return fanMode == FAN_FORCE_ON ? "on" : (fanMode == FAN_FORCE_OFF ? "off" : "auto");
}

void loadSettings() {
  prefs.begin("ammonia", true);
  nh3Mid  = prefs.getInt("mid", DEF_NH3_MID_ADC);
  nh3High = prefs.getInt("high", DEF_NH3_HIGH_ADC);
  fanOnC  = prefs.getFloat("fanon", DEF_TEMP_FAN_ON_C);
  fanMode = (FanMode)prefs.getUChar("fanmode", FAN_AUTO);
  prefs.end();
  if (nh3Mid < 50 || nh3High <= nh3Mid || nh3High > 4090) {
    nh3Mid = DEF_NH3_MID_ADC; nh3High = DEF_NH3_HIGH_ADC;
  }
  if (isnan(fanOnC) || fanOnC < 20 || fanOnC > 60) fanOnC = DEF_TEMP_FAN_ON_C;
  if (fanMode > FAN_FORCE_OFF) fanMode = FAN_AUTO;
}

void saveSettings() {
  prefs.begin("ammonia", false);
  prefs.putInt("mid", nh3Mid);
  prefs.putInt("high", nh3High);
  prefs.putFloat("fanon", fanOnC);
  prefs.putUChar("fanmode", (uint8_t)fanMode);
  prefs.end();
}

// Decide the fan state from the mode (+ temperature in auto) and drive the relay
void applyFan() {
  if (fanMode == FAN_FORCE_ON) {
    fanOn = true;
  } else if (fanMode == FAN_FORCE_OFF) {
    fanOn = false;
  } else if (!dhtFault && !isnan(temperature)) {
    if (!fanOn && temperature >= fanOnC)                     fanOn = true;
    if (fanOn  && temperature <= fanOnC - FAN_HYSTERESIS_C)  fanOn = false;
  } else {
    fanOn = false;
  }
  relayWrite(PIN_FAN, fanOn);
}

// ---------------- Logging ----------------
void rotateLogIfNeeded() {
  File f = LittleFS.open(LOG_FILE, FILE_READ);
  if (!f) return;
  size_t sz = f.size();
  f.close();
  if (sz > LOG_MAX_BYTES) {
    LittleFS.remove(LOG_FILE_OLD);
    LittleFS.rename(LOG_FILE, LOG_FILE_OLD);
  }
}

void appendLog(uint32_t epoch) {
  rotateLogIfNeeded();
  File f = LittleFS.open(LOG_FILE, FILE_APPEND);
  if (!f) return;
  char t[12] = "", h[12] = "";
  if (!isnan(temperature)) snprintf(t, sizeof(t), "%.1f", temperature);
  if (!isnan(humidity))    snprintf(h, sizeof(h), "%.1f", humidity);
  f.printf("%lu,%d,%s,%s,%s\n", (unsigned long)epoch, mqRaw, levelToken(), t, h);
  f.close();
}

void checkLogging() {
  if (!rtcOk || rtcFault) return;
  if (millis() < MQ_WARMUP_MS) return;
  uint32_t ep = nowEpoch();
  uint32_t slot = ep / LOG_INTERVAL_S;
  if (slot != lastLogSlot) {
    lastLogSlot = slot;
    appendLog(ep);
    Serial.println("Logged reading");
  }
}

// ---------------- Sensors ----------------
void readSensors() {
  // MQ-137
  mqRaw = readMQ(mqSpread);
  bool floatingDO = CHECK_DO_FLOAT && doFloating();
  mqDO_alarm = (digitalRead(PIN_MQ_DO) == LOW);

  bool hardBad = (mqRaw < MQ_FAULT_LOW || mqRaw > MQ_FAULT_HIGH);      // stuck at a rail
  bool softBad = floatingDO || (mqSpread > MQ_NOISE_MAX) ||
                 (mqPrev >= 0 && abs(mqRaw - mqPrev) > MQ_JUMP_MAX);   // unplugged / ghost data
  mqPrev = mqRaw;
  if (hardBad || softBad) {
    mqGood = 0;
    if (mqBad < 255) mqBad++;
    if (hardBad && mqBad < MQ_FAULT_SET) mqBad = MQ_FAULT_SET;         // rail faults are instant
    if (mqBad >= MQ_FAULT_SET) mqLatched = true;
  } else {
    mqBad = 0;
    if (mqGood < 255) mqGood++;
    if (mqLatched && mqGood >= MQ_FAULT_CLEAR) mqLatched = false;      // must stay clean to recover
  }
  mqFault = mqLatched;

  // DHT22
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (isnan(t) || isnan(h)) {
    if (dhtFailCount < 255) dhtFailCount++;
    if (dhtFailCount >= 3) {
      dhtFault = true;
      temperature = NAN;
      humidity = NAN;
    }
  } else {
    dhtFailCount = 0;
    dhtFault = false;
    temperature = t;
    humidity = h;
  }

  // RTC + LCD presence
  rtcOk = i2cPresent(0x68);
  rtcFault = !rtcOk || rtc.lostPower();
  lcdOk = i2cPresent(LCD_ADDR);

  // Ammonia level (debounced: a change must repeat before it is accepted)
  if (mqFault || millis() < MQ_WARMUP_MS) {
    level = NH3_UNKNOWN;
    confirmed = NH3_LOW; cand = NH3_LOW; candCount = 0;
  } else {
    NH3Level inst = (mqRaw >= nh3High) ? NH3_HIGH : (mqRaw >= nh3Mid ? NH3_MID : NH3_LOW);
    if (inst == confirmed) {
      candCount = 0;
    } else {
      if (inst == cand) candCount++; else { cand = inst; candCount = 1; }
      uint8_t need = (inst > confirmed) ? (inst == NH3_HIGH ? CONFIRM_HIGH : CONFIRM_MID)
                                        : CONFIRM_DOWN;
      if (candCount >= need) { confirmed = inst; candCount = 0; }
    }
    level = confirmed;
  }

  // Fan: manual override or automatic (temperature with hysteresis)
  applyFan();
}

// ---------------- Buzzer (non-blocking) ----------------
bool buzzerShouldBeOn(unsigned long now) {
  bool anyFault = mqFault || dhtFault;

  if (level == NH3_HIGH) {
    return (now % 200) < 100;
  }
  if (anyFault) {
    unsigned long p = now % 2000;
    return (p < 100) || (p >= 200 && p < 300);
  }
  if (level == NH3_MID) {
    return (now % 1000) < 200;
  }
  return false;
}

// ---------------- LCD ----------------
void padPrint(const char *s) {
  char buf[17];
  snprintf(buf, sizeof(buf), "%-16s", s);
  lcd.print(buf);
}

void updateLcd() {
  if (!lcdOk) return;
  char l1[24], l2[24];

  if (level == NH3_HIGH) {
    lcd.setCursor(0, 0); padPrint("!! NH3 HIGH !!");
    snprintf(l2, sizeof(l2), "ADC:%4d Fan:%s", mqRaw, fanOn ? "ON" : "OFF");
    lcd.setCursor(0, 1); padPrint(l2);
    return;
  }

  if (page == 0) {
    snprintf(l1, sizeof(l1), "NH3:%-4s %4d", levelText(), mqRaw);
    if (dhtFault) snprintf(l2, sizeof(l2), "DHT22 FAULT");
    else          snprintf(l2, sizeof(l2), "%.1fC %.0f%% F:%s", temperature, humidity, fanOn ? "ON" : "--");
  } else if (page == 1) {
    if (rtcFault) {
      snprintf(l1, sizeof(l1), "RTC: set time!");
      snprintf(l2, sizeof(l2), "open the app");
    } else {
      DateTime n = rtc.now();
      snprintf(l1, sizeof(l1), "%04d-%02d-%02d", n.year(), n.month(), n.day());
      snprintf(l2, sizeof(l2), "%02d:%02d:%02d", n.hour(), n.minute(), n.second());
    }
  } else if (page == 2) {
    snprintf(l1, sizeof(l1), "MQ:%s DHT:%s", mqFault ? "ERR" : "OK", dhtFault ? "ERR" : "OK");
    snprintf(l2, sizeof(l2), "Fan:%s%s DO:%s", fanOn ? "ON" : "OFF",
             fanMode == FAN_AUTO ? "" : "*", mqDO_alarm ? "GAS" : "OK");
  } else {
    snprintf(l1, sizeof(l1), "WiFi:%s", AP_SSID);
    snprintf(l2, sizeof(l2), "%s", WiFi.softAPIP().toString().c_str());
  }

  lcd.setCursor(0, 0); padPrint(l1);
  lcd.setCursor(0, 1); padPrint(l2);
}

// ---------------- Web API ----------------
const char *b(bool v) { return v ? "true" : "false"; }

void handleStatus() {
  char t[12], h[12];
  if (isnan(temperature)) strcpy(t, "null"); else snprintf(t, sizeof(t), "%.1f", temperature);
  if (isnan(humidity))    strcpy(h, "null"); else snprintf(h, sizeof(h), "%.1f", humidity);

  char buf[600];
  snprintf(buf, sizeof(buf),
    "{\"raw\":%d,\"do\":%s,\"level\":\"%s\",\"temp\":%s,\"hum\":%s,"
    "\"mqOk\":%s,\"dhtOk\":%s,\"rtcOk\":%s,\"lcdOk\":%s,\"noise\":%d,"
    "\"fan\":%s,\"buzzer\":%s,\"mid\":%d,\"high\":%d,"
    "\"fanMode\":\"%s\",\"fanOnC\":%.1f,\"fanOffC\":%.1f,"
    "\"epoch\":%lu,\"uptime\":%lu}",
    mqRaw, b(mqDO_alarm), levelToken(), t, h,
    b(!mqFault), b(!dhtFault), b(!rtcFault), b(lcdOk), mqSpread,
    b(fanOn), b(buzzerOn), nh3Mid, nh3High,
    fanModeToken(), fanOnC, fanOnC - FAN_HYSTERESIS_C,
    (unsigned long)nowEpoch(), millis() / 1000UL);
  server.send(200, "application/json", buf);
}

void streamFile(const char *path) {
  File f = LittleFS.open(path, FILE_READ);
  if (!f) return;
  uint8_t chunk[512];
  while (f.available()) {
    size_t n = f.read(chunk, sizeof(chunk));
    if (n == 0) break;
    server.sendContent((const char *)chunk, n);
  }
  f.close();
}

void handleHistory() {
  server.setContentLength(CONTENT_LENGTH_UNKNOWN);
  server.send(200, "text/plain", "");
  streamFile(LOG_FILE_OLD);
  streamFile(LOG_FILE);
  server.sendContent("");   // end of chunked response
}

void handleSetTime() {
  if (!server.hasArg("epoch")) {
    server.send(400, "application/json", "{\"ok\":false}");
    return;
  }
  uint32_t ep = (uint32_t)strtoul(server.arg("epoch").c_str(), nullptr, 10);
  if (ep < 1600000000UL || !rtcOk) {
    server.send(400, "application/json", "{\"ok\":false}");
    return;
  }
  rtc.adjust(DateTime(ep));
  rtcFault = false;
  server.send(200, "application/json", "{\"ok\":true}");
}

void handleClear() {
  LittleFS.remove(LOG_FILE);
  LittleFS.remove(LOG_FILE_OLD);
  server.send(200, "application/json", "{\"ok\":true}");
}

// GET /api/config                         -> current settings
// GET /api/config?mid=1200&high=2200&fanon=32 -> change any of them
void handleConfig() {
  int   m = nh3Mid, h = nh3High;
  float f = fanOnC;
  if (server.hasArg("mid"))   m = server.arg("mid").toInt();
  if (server.hasArg("high"))  h = server.arg("high").toInt();
  if (server.hasArg("fanon")) f = server.arg("fanon").toFloat();

  if (m < 50 || h > 4090 || h < m + 50 || f < 20.0f || f > 60.0f) {
    server.send(400, "application/json", "{\"ok\":false,\"error\":\"out of range\"}");
    return;
  }
  bool changed = (m != nh3Mid) || (h != nh3High) || (fabsf(f - fanOnC) > 0.01f);
  nh3Mid = m; nh3High = h; fanOnC = f;
  if (changed) { saveSettings(); applyFan(); }

  char buf[160];
  snprintf(buf, sizeof(buf),
    "{\"ok\":true,\"mid\":%d,\"high\":%d,\"fanOnC\":%.1f,\"fanMode\":\"%s\"}",
    nh3Mid, nh3High, fanOnC, fanModeToken());
  server.send(200, "application/json", buf);
}

// GET /api/fan?mode=auto|on|off
void handleFan() {
  String m = server.arg("mode");
  if      (m == "on")   fanMode = FAN_FORCE_ON;
  else if (m == "off")  fanMode = FAN_FORCE_OFF;
  else if (m == "auto") fanMode = FAN_AUTO;
  else {
    server.send(400, "application/json", "{\"ok\":false}");
    return;
  }
  saveSettings();
  applyFan();
  char buf[96];
  snprintf(buf, sizeof(buf), "{\"ok\":true,\"fanMode\":\"%s\",\"fan\":%s}",
           fanModeToken(), b(fanOn));
  server.send(200, "application/json", buf);
}

void handleNotFound() {
  server.send(404, "text/plain", "not found");
}

// ---------------- Setup / Loop ----------------
void setup() {
  Serial.begin(115200);
  loadSettings();

  pinMode(PIN_MQ_DO, INPUT);
  pinMode(PIN_FAN, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  relayWrite(PIN_FAN, false);
  relayWrite(PIN_BUZZER, false);

  analogReadResolution(12);
  analogSetPinAttenuation(PIN_MQ_AO, ADC_11db);

  Wire.begin(21, 22);
  lcdOk = i2cPresent(LCD_ADDR);
  if (lcdOk) {
    lcd.init();
    lcd.backlight();
    lcd.setCursor(0, 0); lcd.print("Ammonia Monitor");
    lcd.setCursor(0, 1); lcd.print("Starting...");
  }

  dht.begin();

  rtcOk = rtc.begin();
  if (!rtcOk) {
    Serial.println("RTC not found");
    rtcFault = true;
  } else if (rtc.lostPower()) {
    // placeholder time; the app corrects it on first connect
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  }

  if (!LittleFS.begin(true)) {
    Serial.println("LittleFS mount failed");
  }

  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());

  server.on("/api/status",  HTTP_GET, handleStatus);
  server.on("/api/history", HTTP_GET, handleHistory);
  server.on("/api/settime", HTTP_GET, handleSetTime);
  server.on("/api/clear",   HTTP_GET, handleClear);
  server.on("/api/config",  HTTP_GET, handleConfig);
  server.on("/api/fan",     HTTP_GET, handleFan);
  server.onNotFound(handleNotFound);
  server.begin();

  delay(1500);
  if (lcdOk) lcd.clear();
  readSensors();
}

void loop() {
  unsigned long now = millis();

  server.handleClient();

  if (now - lastSensorRead >= 2000) {
    lastSensorRead = now;
    readSensors();
    checkLogging();
    Serial.printf("NH3 raw=%d DO=%d level=%s T=%.1f H=%.1f fan=%d mqFault=%d dhtFault=%d\n",
                  mqRaw, mqDO_alarm, levelText(), temperature, humidity, fanOn, mqFault, dhtFault);
  }

  if (now - lastPage >= 3000) {
    lastPage = now;
    page = (page + 1) % 4;
  }

  if (now - lastLcd >= 500) {
    lastLcd = now;
    updateLcd();
  }

  buzzerOn = buzzerShouldBeOn(now);
  relayWrite(PIN_BUZZER, buzzerOn);
}
