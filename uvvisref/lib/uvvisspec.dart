import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';

class UVVisSpecDeviceResult {
  List<double> sp = [];
  List<double> wl = [];
  double ir = 0.0;
}

class UVVisSpecDeviceStatus {
  bool attached = false;
  bool detached = false;
  bool connected = false;
  bool measurestarted = false;
  bool measurestopped = false;
  bool deviceerror = false;
  bool devicewarn = false;
}

class ReflectanceResult {
  List<double> wl = [];
  List<double> illum = [];
  List<List<double>> reflList = [];  // 複数のSAMPLEデータ
  List<double> dark = [];
  List<List<double>> reflectanceList = [];  // 複数の反射率データ
  bool hasIllum = false;
  bool hasRefl = false;
  bool hasDark = false;
  bool hasReflectance = false;
  int sampleCount = 0;  // SAMPLE取得回数

  // 最後のSAMPLEデータ（グラフ表示用）
  List<double> get refl => reflList.isNotEmpty ? reflList.last : [];
  // 最後の反射率データ（グラフ表示用）
  List<double> get reflectance => reflectanceList.isNotEmpty ? reflectanceList.last : [];
}

class UvVisSpecDevice {
  UsbPort? _port;
  Transaction<String>? _transaction;
  Timer? _timer;
  var _status = UVVisSpecDeviceStatus();
  final _resultSubject = PublishSubject<UVVisSpecDeviceResult>();
  final _statusSubject = PublishSubject<UVVisSpecDeviceStatus>();
  final _reflectanceSubject = PublishSubject<ReflectanceResult>();
  bool _measuring = false;
  final _reflectanceResult = ReflectanceResult();

  Future<void> initialize() async {
    UsbSerial.usbEventStream!.listen((UsbEvent event) async {
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        _status.attached = true;
        _status.detached = false;
        _statusSubject.add(_status);
        var devices = await UsbSerial.listDevices();
        for (var device in devices) {
          var res = await _connectTo(device);
          if (res) await measStart();
        }
      }
      if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        await measStop();
        await _connectTo(null);
        _status.detached = true;
        _status.attached = false;
        _statusSubject.add(_status);
      }
    });
    var devices = await UsbSerial.listDevices();
    for (var device in devices) {
      var res = await _connectTo(device);
      if (res) await measStart();
    }
  }

  Future<void> deinitialize() async {
    await measStop();
    await _connectTo(null);
    _timer?.cancel();
  }

  Future<void> measStart() async {
    if (_status.connected == false) return;
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (_measuring) return;
      if (_status.measurestopped) { timer.cancel(); return; }
      if (_status.measurestarted) {
        _measuring = true;
        await _meas();
        await _status_check();
        _measuring = false;
      }
    });
    _status.measurestarted = true;
    _status.measurestopped = false;
    _statusSubject.add(_status);
  }

  Future<void> measStop() async {
    _status.measurestarted = false;
    _status.measurestopped = true;
    _statusSubject.add(_status);
  }

  Future<void> _meas() async {
    try {
      var res = await _transaction?.transaction(_port!,
          const AsciiEncoder().convert('MEAS\n'), const Duration(seconds: 60));
      if (res == null) { _status.detached = true; _statusSubject.add(_status); return; }
      var result = _parseSpectrum(res);
      _resultSubject.add(result);
    } catch (e) { return; }
  }

  Future<UVVisSpecDeviceResult?> _measOnce() async {
    try {
      var res = await _transaction?.transaction(_port!,
          const AsciiEncoder().convert('MEAS\n'), const Duration(seconds: 60));
      if (res == null) return null;
      return _parseSpectrum(res);
    } catch (e) { return null; }
  }

  Future<bool> captureIllum() async {
    await measStop();
    await Future.delayed(const Duration(milliseconds: 300));
    var result = await _measOnce();
    if (result == null) { await measStart(); return false; }
    var r = _correct(result.wl, result.sp);
    _reflectanceResult.illum = r[1];
    _reflectanceResult.wl = r[0];
    _reflectanceResult.hasIllum = true;
    _reflectanceResult.hasReflectance = false;
    _reflectanceResult.reflList = [];
    _reflectanceResult.reflectanceList = [];
    _reflectanceResult.sampleCount = 0;
    _reflectanceResult.hasRefl = false;
    _reflectanceResult.hasDark = false;
    _reflectanceResult.dark = [];
    _reflectanceSubject.add(_reflectanceResult);
    await measStart();
    return true;
  }

  Future<bool> captureRefl() async {
    await measStop();
    await Future.delayed(const Duration(milliseconds: 300));
    var result = await _measOnce();
    if (result == null) { await measStart(); return false; }
    var r = _correct(result.wl, result.sp);
    _reflectanceResult.wl = r[0];
    _reflectanceResult.reflList.add(r[1]);  // リストに追加
    _reflectanceResult.sampleCount++;
    _reflectanceResult.hasRefl = true;
    _reflectanceResult.hasReflectance = false;
    _reflectanceSubject.add(_reflectanceResult);
    await measStart();
    return true;
  }

  Future<bool> captureDark() async {
    await measStop();
    await Future.delayed(const Duration(milliseconds: 300));
    var result = await _measOnce();
    if (result == null) { await measStart(); return false; }
    var r = _correct(result.wl, result.sp);
    _reflectanceResult.wl = r[0];
    _reflectanceResult.dark = r[1];
    _reflectanceResult.hasDark = true;
    if (_reflectanceResult.hasIllum && _reflectanceResult.hasRefl) {
      _calcReflectance();
    }
    _reflectanceSubject.add(_reflectanceResult);
    await measStart();
    return true;
  }

  void _calcReflectance() {
    var len = _reflectanceResult.wl.length;
    _reflectanceResult.reflectanceList = [];
    // n回分の反射率を計算
    for (var refData in _reflectanceResult.reflList) {
      var ref = List.generate(len, (i) => 0.0);
      for (var i = 0; i < len; i++) {
        var illum = _reflectanceResult.illum[i];
        var refl = refData[i];
        var dark = _reflectanceResult.hasDark ? _reflectanceResult.dark[i] : 0.0;
        var denom = illum - dark;
        if (denom <= 0.0) {
          ref[i] = 0.0;
        } else {
          ref[i] = (refl - dark) / denom;
          if (ref[i] < 0.0) ref[i] = 0.0;
          if (ref[i] > 1.0) ref[i] = 1.0;
        }
      }
      _reflectanceResult.reflectanceList.add(ref);
    }
    _reflectanceResult.hasReflectance = true;
  }

  Future<void> _status_check() async {
    var res = await _transaction?.transaction(_port!,
        const AsciiEncoder().convert('ST?\n'), const Duration(seconds: 60));
    var v = res?.split('/')[1].split(':');
    if (v != null) {
      _status.devicewarn = v[0] == "W";
      _status.deviceerror = v[0] == "E";
      _statusSubject.add(_status);
    }
  }

  Stream<UVVisSpecDeviceResult> get resultStream => _resultSubject.stream;
  Stream<UVVisSpecDeviceStatus> get statusStream => _statusSubject.stream;
  Stream<ReflectanceResult> get reflectanceStream => _reflectanceSubject.stream;
  ReflectanceResult get currentReflectance => _reflectanceResult;

  UVVisSpecDeviceResult _parseSpectrum(String res) {
    var values = res.split('\r');
    var len = values.length - 1;
    var wl = <double>[];
    var p = <double>[];
    for (var i = 0; i < len; i++) {
      var v = values[i].split(':');
      wl.add(double.parse(v[0]));
      var val = double.parse(v[1]);
      p.add(val < 1e-9 ? 0.0 : val);
    }
    var r = _correct(wl, p);
    var result = UVVisSpecDeviceResult();
    result.wl = r[0];
    result.sp = r[1];
    result.ir = r[1].fold(0.0, (a, b) => a + b);
    return result;
  }

  Future<bool> _connectTo(UsbDevice? device) async {
    _transaction?.dispose();
    _transaction = null;
    _port?.close();
    _port = null;
    if (device == null) {
      _status.connected = false;
      _statusSubject.add(_status);
      return false;
    }
    _port = await device.create();
    var res = await _port?.open();
    if (res == null || res == false) {
      _status.connected = false;
      _statusSubject.add(_status);
      return false;
    }
    await _port?.setDTR(false);
    await _port?.setRTS(false);
    await _port?.setPortParameters(
        9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    _transaction = Transaction.stringTerminated(
        (_port!.inputStream) as Stream<Uint8List>, Uint8List.fromList([10]));
    await _transaction?.transaction(_port!,
        const AsciiEncoder().convert('EXP/AUTO\n'), const Duration(seconds: 60));
    _status.connected = true;
    _statusSubject.add(_status);
    return true;
  }

  List<List<double>> _correct(List<double> wl, List<double> sp) {
    var wlMax = 800;
    var wlMin = 310;
    var len = wlMax - wlMin + 1;
    var wl2 = List.generate(len, (i) => (i + wlMin).toDouble());
    var sp2 = List.generate(len, (i) => 0.0);
    for (var i = 0; i < len; i++) {
      sp2[i] = _interporateLagrange(wl2[i], wl, sp);
    }
    for (var i = 2; i < len - 2; i++) {
      sp2[i] = (sp2[i-2]*(-3) + sp2[i-1]*12 + sp2[i]*17 + sp2[i+1]*12 + sp2[i+2]*(-3)) / 35;
      if (sp2[i] < 0.0) sp2[i] = 0.0;
    }
    return [wl2, sp2];
  }

  double _interporateLagrange(double x, List<double> v1, List<double> v2) {
    if (x < v1[0]) return v2[0];
    var t1 = 2;
    for (var i = 2; i < v1.length - 1; i++) {
      t1 = i;
      if (v1[i] > x) break;
    }
    var xx = [v1[t1-2], v1[t1-1], v1[t1], v1[t1+1]];
    var yy = [v2[t1-2], v2[t1-1], v2[t1], v2[t1+1]];
    var s = 0.0;
    for (var j = 0; j < 4; j++) {
      var p = yy[j];
      for (var i = 0; i < 4; i++) {
        if (i == j) continue;
        if ((xx[j] - xx[i]) != 0.0) p *= (x - xx[i]) / (xx[j] - xx[i]);
      }
      s += p;
    }
    return s < 0 ? 0.0 : s;
  }
}
