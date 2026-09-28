import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'uvvisspec.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _device = UvVisSpecDevice();
  List<double> _wl = [];
  List<double> _sp = [];
  double _ir = 0.0;
  bool _isHold = true;
  String _statusText = '';
  bool _hasIllum = false;
  bool _hasRefl = false;
  bool _hasDark = false;
  bool _hasReflectance = false;
  List<double> _reflectance = [];
  int _sampleCount = 0;
    AppSettings _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _device.initialize();
    _hasIllum = false;
    _hasRefl = false;
    _hasDark = false;
    _hasReflectance = false;
    _reflectance = [];
    _wl = [];
    _sp = [];
    _ir = 0.0;
    _statusText = '';
    _sampleCount = 0;

    _device.resultStream.listen((result) {
      if (!_isHold) {
        setState(() {
          _wl = result.wl;
          _sp = result.sp;
          _ir = result.ir;
        });
      }
    });
    _device.statusStream.listen((status) {
      setState(() {
        if (status.detached) _showDisconnectDialog();
      });
    });
    _device.reflectanceStream.listen((result) {
      setState(() {
        _hasIllum = result.hasIllum;
        _hasRefl = result.hasRefl;
        _hasDark = result.hasDark;
        _hasReflectance = result.hasReflectance;
        _sampleCount = result.sampleCount;
        if (result.hasReflectance) {
          _reflectance = result.reflectance;
          _wl = result.wl;
        }
      });
    });
  }

  @override
  void dispose() {
    _device.deinitialize();
    super.dispose();
  }

    List<FlSpot> _getChartSpots() {
      if (_hasReflectance && _reflectance.isNotEmpty) {
        return List.generate(_wl.length, (i) => FlSpot(_wl[i], _reflectance[i]));
      }
      if (_wl.isEmpty || _sp.isEmpty) return [];
      return List.generate(_wl.length, (i) => FlSpot(_wl[i], _sp[i]));
    }

  Future<void> _openSettings() async {
    final result = await Navigator.push<AppSettings>(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(settings: _settings)),
    );
    if (result != null) {
      setState(() => _settings = result);
    }
  }
  Future<void> _onIllum() async {
    var ok = await _showConfirmDialog('WHITE取得', '白色光を取得します。\nアルミ板を開口部にセットしてください。');
    if (!ok) return;
    setState(() => _statusText = 'WHITE取得中...');
    var res = await _device.captureIllum();
    setState(() => _statusText = res ? 'WHITE取得完了' : 'WHITE取得失敗');
  }

  Future<void> _onRefl() async {
    var ok = await _showConfirmDialog('SAMPLE取得', '試料反射光を取得します。\nアルミ板と試料を開口部にセットしてください。');
    if (!ok) return;
    setState(() => _statusText = 'SAMPLE取得中...');
    var res = await _device.captureRefl();
    setState(() => _statusText = res ? 'SAMPLE取得完了' : 'SAMPLE取得失敗');
  }

  Future<void> _onDark() async {
    var ok = await _showConfirmDialog('BLACK取得', 'ダーク光を取得します。\nメタルベルベットを開口部にセットしてください。');
    if (!ok) return;
    setState(() => _statusText = 'BLACK取得中...');
    var res = await _device.captureDark();
    setState(() => _statusText = res ? 'BLACK取得完了' : 'BLACK取得失敗');
  }

  Future<void> _onStore() async {
    var ref = _device.currentReflectance;
    if (!ref.hasIllum && !ref.hasRefl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存できるデータがありません')),
      );
      return;
    }
    var now = DateTime.now();
        var fname = _settings.useDateTime
        ? DateFormat('yyyyMMddHHmmss').format(now) + '.csv'
        : _settings.userFileName.isNotEmpty
            ? _settings.userFileName + '.csv'
            : DateFormat('yyyyMMddHHmmss').format(now) + '.csv';
    var dir = await getExternalStorageDirectory();
    dir ??= await getApplicationDocumentsDirectory();
    var file = File('${dir.path}/$fname');
    var lines = StringBuffer();

    // ヘッダー生成
    var header = 'wavelength,illum';
    for (var i = 0; i < ref.sampleCount; i++) {
      header += ',sample${i + 1}';
    }
    if (ref.hasDark) header += ',dark';
    for (var i = 0; i < ref.reflectanceList.length; i++) {
      header += ',reflectance${i + 1}';
    }
    lines.writeln(header);

    // データ生成
    for (var i = 0; i < ref.wl.length; i++) {
      var row = '${ref.wl[i].toStringAsFixed(1)}';
      row += ',${ref.hasIllum ? ref.illum[i].toStringAsExponential(4) : ""}';
      for (var j = 0; j < ref.reflList.length; j++) {
        row += ',${ref.reflList[j][i].toStringAsExponential(4)}';
      }
      if (ref.hasDark) row += ',${ref.dark[i].toStringAsExponential(4)}';
      for (var j = 0; j < ref.reflectanceList.length; j++) {
        row += ',${ref.reflectanceList[j][i].toStringAsFixed(4)}';
      }
      lines.writeln(row);
    }

    await file.writeAsString(lines.toString());
    if (mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('保存しました'),
          content: Text(fname),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    var result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
        ],
      ),
    );
    return result ?? false;
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('接続が切れました'),
        content: const Text('デバイスが切断されました。アプリを終了します。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statusChip('WHITE取得', _hasIllum),
        const Text(' → ', style: TextStyle(color: Colors.white54)),
        _statusChip('SAMPLE取得', _hasRefl),
        const Text(' → ', style: TextStyle(color: Colors.white54)),
        _statusChip('BLACK取得', _hasDark),
        const Text(' → ', style: TextStyle(color: Colors.white54)),
        _statusChip('反射率計算終了', _hasReflectance),
      ],
    );
  }

  Widget _statusChip(String label, bool done) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: done ? Colors.greenAccent : Colors.white38,
        fontWeight: done ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  // SAMPLEボタン（取得回数表示付き）
  Widget _sampleButton() {
    return ElevatedButton(
      onPressed: _onRefl,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.lightGreen,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('SAMPLE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          if (_sampleCount > 0)
            Text('$_sampleCount',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _circleButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    var spots = _getChartSpots();
    return Scaffold(
      appBar: AppBar(
        title: const Text('UVvis\u53cd\u5c04\u7387\u6e2c\u5b9a\u30a2\u30d7\u30ea',
            style: TextStyle(locale: Locale('ja', 'JP'))),
        backgroundColor: Colors.blueGrey[900],
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings)],
      ),
      backgroundColor: Colors.grey[900],
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: spots.isEmpty
                  ? const Center(child: Text('センサーを接続してください',
                      style: TextStyle(color: Colors.white54)))
                  : LineChart(LineChartData(
                      minX: 300, maxX: 800, minY: 0,
                      maxY: _hasReflectance ? 1.0 : (_sp.isNotEmpty ? _sp.reduce((a, b) => a > b ? a : b) * 1.1 : null),
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          axisNameWidget: const Text('nm',
                              style: TextStyle(color: Colors.white70)),
                          sideTitles: SideTitles(
                            showTitles: true, interval: 100,
                            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                                style: const TextStyle(color: Colors.white70, fontSize: 10)),
                          ),
                        ),
                       leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (v, _) => Text(
                                _hasReflectance
                                    ? v.toStringAsFixed(1)
                                    : v.toStringAsExponential(1),
                                style: const TextStyle(color: Colors.white70, fontSize: 9)),
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots, isCurved: false,
                          color: Colors.blue, barWidth: 1.5,
                          dotData: FlDotData(show: false),
                        ),
                      ],
                    )),
            ),
          ),
          const Text('放射照度', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(_ir.toStringAsFixed(4),
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const Text('W·m⁻²', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          _buildStatusIndicator(),
          if (_statusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_statusText,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _circleButton('WHITE', Colors.green, _onIllum),
              _sampleButton(),
              _circleButton('BLACK', Colors.grey, _onDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _circleButton((_isHold || _hasReflectance) ? 'LIVE' : 'HOLD', Colors.blue, () {
                setState(() {
                  _isHold = !_isHold;
                  if (!_isHold) _hasReflectance = false;
                });
                if (_isHold) {
                  _device.measStop();
                } else {
                  _device.measStart();
                }
              }),
              _circleButton('STORE', Colors.orange, _onStore),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
