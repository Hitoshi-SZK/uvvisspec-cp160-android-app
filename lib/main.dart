import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'uvvisspec.dart';
import 'settings.dart';
import 'result_storage.dart';
import 'uvvisspecapp.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const Home(),
      theme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(color: Colors.blueGrey),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }
}

class HomeState extends State<Home> {
  final ResultStorage storage = ResultStorage();
  final UvVisSpecDevice device = UvVisSpecDevice();
  final ResultConverter resultConverter = ResultConverter();

  var _peekPower = 0.0;
  var _peekWavelength = 0.0;
  var _irradiance = 0.0;
  var _unit = "W\u2219m\u207B\u00B2";

  late List<double> _spectralData = List.generate(50, (index) => 1.0);
  late List<double> _spectralWl = List.generate(50, (index) => 0.0);
  late ResultReport _currentResult = ResultReport();
  var _settings = Settings();
  var _showWarning = true;
  var _measuring = false;
  var _connected = false;
  var _timer;

  @override
  void initState() {
    super.initState();

    resultConverter.initialize();

    device.statusStream.listen((event) async {
      if (event.detached) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (x) => AlertDialog(
            content: const Text('デバイスが切断されました.\r\nアプリを終了します.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  SystemNavigator.pop();
                },
              ),
            ],
          ),
        );

        await Future.delayed(const Duration(seconds: 5));
        Navigator.of(context).pop();
        SystemNavigator.pop();
      }
      setState(() {
        _connected = event.connected;
        _measuring = event.measurestarted;

        if (event.devicewarn || event.deviceerror) {
          _showWarning = true;
          return;
        }
        _showWarning = false;
      });
    });
    device.resultStream.listen((event) async {
      _currentResult = await resultConverter.convert(event, _settings);

      var p1 = [..._currentResult.sp];
      var wl1 = [..._currentResult.wl];
      var pp1 = _currentResult.pp;
      var ir1 = _currentResult.ir;
      var pwl1 = _currentResult.pwl;
      var vmax = p1.reduce(max);
      for (var i = 0; i < p1.length; i++) {
        p1[i] /= vmax;
      }

      setState(() {
        _spectralData = p1;
        _spectralWl = wl1;
        _irradiance = ir1;
        _peekWavelength = pwl1;
        _peekPower = pp1;
      });
    });

    device.initialize();
  }

  @override
  void dispose() {
    super.dispose();
    Future(() async {
      await device.measStop();
      await device.deinitialize();
    });
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    var integratedLightIntensityLabel = "放射照度";
    switch (_settings.measureMode) {
      case MeasureMode.irradiance:
        integratedLightIntensityLabel = "放射照度";
        break;
      case MeasureMode.insectsIrradiance:
        integratedLightIntensityLabel = "光子数密度";
        break;
      case MeasureMode.ppfd:
        integratedLightIntensityLabel = "光量子束密度";
        break;
    }
    if (_settings.sumRangeMin == 310 && _settings.sumRangeMax == 800) {
    } else if (_settings.sumRangeMin == 310 && _settings.sumRangeMax == 400) {
      integratedLightIntensityLabel += " 310 - 400 nm (UV)";
    } else if (_settings.sumRangeMin == 400 && _settings.sumRangeMax == 500) {
      integratedLightIntensityLabel += " 400 - 500 nm (B)";
    } else if (_settings.sumRangeMin == 500 && _settings.sumRangeMax == 600) {
      integratedLightIntensityLabel += " 500 - 600 nm (G)";
    } else if (_settings.sumRangeMin == 600 && _settings.sumRangeMax == 700) {
      integratedLightIntensityLabel += " 600 - 700 nm (R)";
    } else if (_settings.sumRangeMin == 700 && _settings.sumRangeMax == 800) {
      integratedLightIntensityLabel += " 700 - 800 nm (FR)";
    } else if (_settings.sumRangeMin == 400 && _settings.sumRangeMax == 700) {
      integratedLightIntensityLabel += " 400 - 700 nm";
    } else {
      integratedLightIntensityLabel += " (" +
          _settings.sumRangeMin.toInt().toString() +
          " - " +
          _settings.sumRangeMax.toInt().toString() +
          " nm)";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('虫用分光放射照度計CP160'),
        actions: <Widget>[
          //(_connected) ? const Icon(Icons.check_circle_outline) : const Icon(Icons.highlight_off_outlined),
          (_showWarning) ? const Icon(Icons.warning) : const SizedBox.shrink(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await device.measStop();
              var prevExp = _settings.deviceExposureTime;
              _settings = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SettingsPage(_settings)));

              setState(() {
                _unit = unitMap[_settings.unit]!;
              });

              if (_settings.deviceExposureTime != prevExp) {
                await device.changeExposureTime(_settings.deviceExposureTime);
              }
              //debugPrint(_settings.deviceExposureTime);

              await device.measStart();
            },
          ),
        ],
      ),
      body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
            Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  SizedBox(
                      width: width,
                      height: height / 100 * 30,
                      child: Card(
                        child: SpectralLineChart.create(
                            _spectralWl,
                            _spectralData,
                            _settings.sumRangeMin,
                            _settings.sumRangeMax),
                      )),
                  SizedBox(
                    height: height / 100 * 15,
                    width: width,
                    child: Card(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Visibility(
                              child: Text(
                                filterNameMap[_settings.filter].toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                              visible: _settings.measureMode ==
                                  MeasureMode.insectsIrradiance),
                          Text(
                            integratedLightIntensityLabel,
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            _irradiance == 0 ? "0"
                                :_irradiance * 1000 < 1
                                ? _irradiance.toStringAsExponential(3)
                                : _irradiance > 1000
                                    ? _irradiance.toStringAsExponential(3)
                                    : _irradiance.toStringAsPrecision(4),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 34,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          Text(_unit, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: height / 100 * 13,
                    width: width,
                    child: Card(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text(
                            "ピーク光強度",
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _peekPower == 0 ? "0"
                                : _peekPower * 1000 < 1
                                ? _peekPower.toStringAsExponential(3)
                                : _peekPower > 1000
                                    ? _peekPower.toStringAsExponential(3)
                                    : _peekPower.toStringAsPrecision(4),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          Text(_unit + "\u2219nm\u207B\u00B9",
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: height / 100 * 13,
                    width: width,
                    child: Card(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          const Text(
                            "ピーク波長",
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _peekWavelength.toStringAsFixed(0),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          const Text("nm", style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: ElevatedButton(
                      onPressed: () async {
                        await device.measStop();

                        var res = await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (x) => AlertDialog(
                                  content:
                                      const Text('ダーク補正をします.\r\n遮光してください.'),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () =>
                                          Navigator.of(context).pop(0),
                                    ),
                                    TextButton(
                                      child: const Text('OK'),
                                      onPressed: () =>
                                          Navigator.of(context).pop(1),
                                    ),
                                  ],
                                ));

                        if (res == 1) {
                          showDialog(
                              context: context,
                              builder: (x) {
                                return AlertDialog(
                                  content: Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: const <Widget>[
                                            Padding(
                                                child: SizedBox(
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 3),
                                                    width: 32,
                                                    height: 32),
                                                padding: EdgeInsets.only(
                                                    bottom: 16)),
                                            Padding(
                                                child: Text(
                                                  'しばらくお待ちください...',
                                                  style:
                                                      TextStyle(fontSize: 16),
                                                  textAlign: TextAlign.center,
                                                ),
                                                padding:
                                                    EdgeInsets.only(bottom: 4))
                                          ])),
                                );
                              });

                          await device.dark();

                          Navigator.of(context).pop();

                          // dialog = const AlertDialog(
                          //   content: Text('ダーク補正しました.'),
                          // );
                          // await showDialog(context: context, builder: (x) => dialog);
                        }
                        await device.measStart();
                      },
                      child: const Text("DARK"),
                      style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.white38),
                    ),
                  ),
                  SizedBox(
                    height: 90,
                    width: 90,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {});
                        if (_measuring) {
                          await device.measStop();
                          return;
                        }
                        await device.measStart();
                      },
                      child:
                          !_measuring ? const Text("MEAS") : const Text("HOLD"),
                      style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: EdgeInsets.zero,
                          backgroundColor: !_measuring
                              ? Colors.green
                              : Colors.blue.shade800),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: ElevatedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final filename =
                            '${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}${now.hour.toString().padLeft(2, "0")}${now.minute.toString().padLeft(2, "0")}${now.second.toString().padLeft(2, "0")}';
                        _currentResult.measureDatetime = now.toString();
                        try {
                          await storage.write(filename, _currentResult);
                          var dialog = const AlertDialog(
                            content: Text("保存しました."),
                          );
                          await showDialog(context: context, builder: (x) => dialog);
                        } catch (e) {
                          var dialog = AlertDialog(
                            content: Text("保存に失敗しました。\n$e"),
                          );
                          await showDialog(context: context, builder: (x) => dialog);
                        }
                      },
                      child: const Text("STORE"),
                      style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ])),
    );
  }
}

class SpectralLineChart extends StatelessWidget {
  final List<LinearSpectral> data;
  final bool animate;
  final double sumRangeMin;
  final double sumRangeMax;

  SpectralLineChart(this.data, this.animate, this.sumRangeMin, this.sumRangeMax);

  factory SpectralLineChart.create(List<double> wl, List<double> opticalPower,
      double sumRangeMin, double sumRangeMax) {
    List<LinearSpectral> l = [];
    for (var i = 0; i < wl.length; i++) {
      l.add(LinearSpectral(wl[i], opticalPower[i]));
    }
    return SpectralLineChart(l, false, sumRangeMin, sumRangeMax);
  }

  @override
Widget build(BuildContext context) {
  final spots =
      data.map((sp) => FlSpot(sp.waveLength, sp.opticalPower)).toList();

  final maxY = data.isEmpty
      ? 1.0
      : data.map((e) => e.opticalPower).reduce((a, b) => a > b ? a : b) * 1.1;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: LineChart(
      LineChartData(
        minX: 290.0,
        maxX: 810.0,
        minY: 0,
        maxY: maxY == 0 ? 1.0 : maxY,
        clipData: const FlClipData.none(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            axisNameWidget:
                const Text('nm', style: TextStyle(color: Colors.white, fontSize: 15)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 100,
              getTitlesWidget: (value, meta) {
                if (value < 300 || value > 800) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.blue,
            barWidth: 4,
            dotData: const FlDotData(show: false),
            belowBarData:
                BarAreaData(show: true, color: Colors.blue.withOpacity(0.3)),
          ),
        ],
        extraLinesData: ExtraLinesData(
          verticalLines: [
            VerticalLine(
              x: sumRangeMin,
              color: Colors.white,
              strokeWidth: 2,
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                style: const TextStyle(color: Colors.white),
                labelResolver: (line) => sumRangeMin.toInt().toString(),
              ),
            ),
            VerticalLine(
              x: sumRangeMax,
              color: Colors.white,
              strokeWidth: 2,
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                style: const TextStyle(color: Colors.white),
                labelResolver: (line) => sumRangeMax.toInt().toString(),
              ),
            ),
          ],
        ),
      ),
      duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
    ),
  );
}
}

class LinearSpectral {
  final double waveLength;
  final double opticalPower;

  LinearSpectral(this.waveLength, this.opticalPower);
}

