import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Talks to the ESP32 over its WiFi access point and keeps the records.
class EspService extends ChangeNotifier {
  String host = '192.168.4.1';
  bool connected = false;
  bool connecting = false;
  bool demo = false;
  bool demoFault = false;
  int _demoMid = 1200, _demoHigh = 2200;
  double _demoFanOn = 32;
  FanMode _demoFanMode = FanMode.auto;
  bool _demoFanState = false;
  bool syncing = false;
  String? error;
  LiveData? data;
  DateTime? lastSync;

  final Map<int, Reading> _readings = {};
  List<Reading>? _sorted;
  Timer? _timer;
  bool _busy = false;
  int _fails = 0;
  Set<String> _lastErrors = {};
  Level _lastLevel = Level.warmup;

  final _alerts = StreamController<String>.broadcast();
  Stream<String> get alerts => _alerts.stream;

  List<Reading> get readings =>
      _sorted ??= (_readings.values.toList()..sort((a, b) => a.epoch - b.epoch));

  List<String> get sensorErrors => data?.failingSensors ?? const [];

  // ---------------------------------------------------------------- setup
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      host = prefs.getString('host') ?? host;
    } catch (_) {}
    await _loadLocal();
  }

  // ------------------------------------------------------------ connection
  Future<void> connect(String h) async {
    host = h.trim().isEmpty ? '192.168.4.1' : h.trim();
    connecting = true;
    error = null;
    notifyListeners();
    try {
      final d = await _fetchStatus();
      data = d;
      demo = false;
      connected = true;
      _fails = 0;
      _lastErrors = d.failingSensors.toSet();
      _lastLevel = d.level;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('host', host);
      } catch (_) {}
      await _syncClock(d);
      _startPolling();
      unawaited(syncHistory());
    } catch (_) {
      connected = false;
      error = 'Could not reach the device. Join the "AmmoniaMonitor" WiFi '
          'network on your phone, then try again.';
    }
    connecting = false;
    notifyListeners();
  }

  void disconnect() {
    _timer?.cancel();
    connected = false;
    demo = false;
    demoFault = false;
    data = null;
    error = null;
    notifyListeners();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  Future<LiveData> _fetchStatus() async {
    final res = await http
        .get(Uri.http(host, '/api/status'))
        .timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return LiveData.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> _syncClock(LiveData d) async {
    try {
      final phone = toDeviceEpoch(DateTime.now());
      if ((phone - d.epoch).abs() > 5) {
        await http
            .get(Uri.http(host, '/api/settime', {'epoch': '$phone'}))
            .timeout(const Duration(seconds: 4));
        data = await _fetchStatus();
      }
    } catch (_) {}
  }

  Future<void> _tick() async {
    if (_busy || !connected) return;
    _busy = true;
    try {
      if (demo) {
        _demoTick();
      } else {
        final d = await _fetchStatus();
        _fails = 0;
        _onData(d);
      }
    } catch (_) {
      if (!demo && ++_fails >= 3) {
        connected = false;
        error = 'Connection lost. Make sure your phone is still on the '
            '"AmmoniaMonitor" WiFi.';
        _timer?.cancel();
      }
    }
    _busy = false;
    notifyListeners();
  }

  void _onData(LiveData d) {
    data = d;
    final errs = d.failingSensors.toSet();
    final fresh = errs.difference(_lastErrors);
    if (fresh.isNotEmpty) {
      _alerts.add('Sensor error: ${fresh.join(', ')}. Please check.');
    }
    _lastErrors = errs;
    if (d.level == Level.high && _lastLevel != Level.high) {
      _alerts.add('Ammonia level is HIGH. Check your tank now.');
    }
    _lastLevel = d.level;
  }

  // ------------------------------------------------------- device settings
  /// Sets the fan mode (auto / forced on / forced off). Returns true on success.
  Future<bool> setFanMode(FanMode m) async {
    if (demo) {
      _demoFanMode = m;
      _demoTick();
      notifyListeners();
      return true;
    }
    try {
      final res = await http
          .get(Uri.http(host, '/api/fan', {'mode': m.name}))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return false;
      data = await _fetchStatus();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Saves the ammonia thresholds (raw ADC) and/or the fan-on temperature.
  Future<bool> saveSettings({int? mid, int? high, double? fanOnC}) async {
    if (demo) {
      _demoMid = mid ?? _demoMid;
      _demoHigh = high ?? _demoHigh;
      _demoFanOn = fanOnC ?? _demoFanOn;
      _demoTick();
      notifyListeners();
      return true;
    }
    try {
      final q = <String, String>{
        if (mid != null) 'mid': '$mid',
        if (high != null) 'high': '$high',
        if (fanOnC != null) 'fanon': fanOnC.toStringAsFixed(1),
      };
      final res = await http
          .get(Uri.http(host, '/api/config', q))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return false;
      data = await _fetchStatus();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------- records
  Future<void> syncHistory() async {
    if (demo || !connected) return;
    syncing = true;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.http(host, '/api/history'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        var added = false;
        for (final line in const LineSplitter().convert(res.body)) {
          final r = Reading.tryParse(line);
          if (r != null && r.epoch > 1600000000) {
            _readings[r.epoch] = r;
            added = true;
          }
        }
        if (added) {
          _sorted = null;
          await _saveLocal();
        }
        lastSync = DateTime.now();
      }
    } catch (_) {}
    syncing = false;
    notifyListeners();
  }

  Future<void> clearDeviceRecords() async {
    try {
      if (!demo) {
        await http
            .get(Uri.http(host, '/api/clear'))
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    _readings.clear();
    _sorted = null;
    await _saveLocal();
    notifyListeners();
  }

  Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/ammonia_history.csv');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadLocal() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return;
      for (final line in await f.readAsLines()) {
        final r = Reading.tryParse(line);
        if (r != null) _readings[r.epoch] = r;
      }
      _sorted = null;
    } catch (_) {}
  }

  Future<void> _saveLocal() async {
    try {
      final f = await _file();
      if (f == null) return;
      final b = StringBuffer();
      for (final r in readings) {
        b.writeln(r.toCsv());
      }
      await f.writeAsString(b.toString());
    } catch (_) {}
  }

  // ------------------------------------------------------------------ demo
  void startDemo() {
    demo = true;
    connected = true;
    error = null;
    _readings.clear();
    final rnd = Random(7);
    final now = toDeviceEpoch(DateTime.now());
    final end = now - now % 1800;
    for (var i = 0; i < 48 * 14; i++) {
      final e = end - i * 1800;
      final raw = (700 +
              520 * (sin(i / 18.0) + 1) +
              rnd.nextInt(90) +
              (i % 97 < 4 ? 900 : 0))
          .round();
      _readings[e] = Reading(
        epoch: e,
        raw: raw,
        level: levelForRaw(raw, 1200, 2200),
        temp: 26.5 + 2.5 * sin(i / 9.0) + rnd.nextDouble(),
        hum: 60 + 6 * sin(i / 14.0),
      );
    }
    _sorted = null;
    _demoTick();
    _lastErrors = {};
    _lastLevel = data!.level;
    _startPolling();
    notifyListeners();
  }

  void setDemoFault(bool v) {
    demoFault = v;
    _demoTick();
    notifyListeners();
  }

  void _demoTick() {
    final s = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final raw = (900 + 700 * (sin(s / 60) + 1) + sin(s) * 25).round();
    final temp = 29 + 4 * sin(s / 90);
    if (_demoFanMode == FanMode.auto) {
      if (!demoFault && temp >= _demoFanOn) _demoFanState = true;
      if (demoFault || temp <= _demoFanOn - 2) _demoFanState = false;
    }
    final fanNow = switch (_demoFanMode) {
      FanMode.on => true,
      FanMode.off => false,
      FanMode.auto => _demoFanState,
    };
    final d = LiveData(
      raw: raw,
      doAlarm: raw > 1800,
      level: levelForRaw(raw, _demoMid, _demoHigh),
      temp: demoFault ? null : temp,
      hum: demoFault ? null : 62 + 5 * sin(s / 70),
      mqOk: true,
      dhtOk: !demoFault,
      rtcOk: true,
      lcdOk: true,
      fan: fanNow,
      buzzer: false,
      mid: _demoMid,
      high: _demoHigh,
      fanMode: _demoFanMode,
      fanOnC: _demoFanOn,
      fanOffC: _demoFanOn - 2,
      epoch: toDeviceEpoch(DateTime.now()),
      uptime: s.round() % 100000,
    );
    _onData(d);
  }
}

final EspService esp = EspService();
