import 'package:flutter/material.dart';
import 'uvvisspec.dart';
import 'uvvisspecapp.dart';

enum MeasureMode { irradiance, insectsIrradiance, ppfd }
enum IntegrateLigthIntensityRange { all, uv, b, g, r, fr, vis, custom }

class SettingsPage extends StatefulWidget {
  //const SettingsPage({Key? key}) : super(key: key);
  SettingsPage(this.settings);
  Settings settings;
  @override
  State<StatefulWidget> createState() {
    return SettingsPageState();
  }
}

class SettingsPageState extends State<SettingsPage> {
  var _unitSel = Unit.w;
  var _filterSel = FilterSpectralIntensityType.None;
  var _wlSumMin = "";
  var _wlSumMax = "";
  var _wlRangeValues = const RangeValues(0.31, 0.8);
  var _measureModeSel = MeasureMode.irradiance;
  var _integrateRangeSel = IntegrateLigthIntensityRange.all;
  // var _wlSumMinEditingController = TextEditingController (text: "");
  // var _wlSumMaxEditingController = TextEditingController (text: "");
  var _exposuretime = "";
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    final settings = widget.settings;
    _wlSumMin = settings.sumRangeMin.toInt().toString();
    _wlSumMax = settings.sumRangeMax.toInt().toString();
    // _wlSumMinEditingController = TextEditingController(text: _wlSumMin);
    // _wlSumMaxEditingController = TextEditingController(text: _wlSumMax);
    _wlRangeValues = RangeValues(
        settings.sumRangeMin / 1000.0, settings.sumRangeMax / 1000.0);
    setState(() {
      _unitSel = settings.unit;
      _filterSel = settings.filter;
      _exposuretime = settings.deviceExposureTime;
      _measureModeSel = settings.measureMode;
      _integrateRangeSel = settings.integrateLigthIntensityRange;
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Settings s = Settings();
        s.unit = _unitSel;
        s.sumRangeMin = double.parse(_wlSumMin);
        s.sumRangeMax = double.parse(_wlSumMax);
        s.deviceExposureTime = _exposuretime;
        s.filter = _filterSel;
        s.measureMode = _measureModeSel;
        s.integrateLigthIntensityRange = _integrateRangeSel;
        Navigator.of(context).pop(s);

        return Future.value(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('設定'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Column(
                children: [
                  Card(
                    child: Column(
                      children: <Widget>[
                        const Text("測定モード"),
                        RadioListTile(
                            title: const Text("放射照度"),
                            value: MeasureMode.irradiance,
                            groupValue: _measureModeSel,
                            onChanged: (value) => {
                                  setState(() {
                                    _measureModeSel = MeasureMode.irradiance;
                                    _unitSel = Unit.w;
                                    _filterSel =
                                        FilterSpectralIntensityType.None;
                                  })
                                }),
                        RadioListTile(
                            title: const Text("昆虫照度"),
                            value: MeasureMode.insectsIrradiance,
                            groupValue: _measureModeSel,
                            onChanged: (value) => {
                                  setState(() {
                                    _measureModeSel =
                                        MeasureMode.insectsIrradiance;
                                    _unitSel = Unit.photon;
                                  })
                                }),
                        // RadioListTile(
                        //     title: const Text("PPFD"),
                        //     value: MeasureMode.ppfd,
                        //     groupValue: _measureModeSel,
                        //     onChanged: (value) => {
                        //           setState(() {
                        //             _measureModeSel = MeasureMode.ppfd;
                        //             _unitSel = Unit.mol;
                        //             _filterSel =
                        //                 FilterSpectralIntensityType.None;
                        //           })
                        //         }),
                      ],
                    ),
                  ),
                  Card(
                    child: Column(
                      children: <Widget>[
                        const Text("測定波長範囲"),
                        Column(
                          children: <Widget>[
                            RadioListTile(
                              title: const Text("310-800nm"),
                              value: IntegrateLigthIntensityRange.all,
                              groupValue: _integrateRangeSel,
                              onChanged: (value) {
                                setState(() {
                                  _wlRangeValues = const RangeValues(0.31, 0.8);
                                  _wlSumMin = (_wlRangeValues.start * 1000)
                                      .toInt()
                                      .toString();
                                  _wlSumMax = (_wlRangeValues.end * 1000)
                                      .toInt()
                                      .toString();
                                  _integrateRangeSel =
                                      IntegrateLigthIntensityRange.all;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text("400-700nm (VIS)"),
                              value: IntegrateLigthIntensityRange.vis,
                              groupValue: _integrateRangeSel,
                              onChanged: (value) {
                                setState(() {
                                  _wlRangeValues = const RangeValues(0.4, 0.7);
                                  _wlSumMin = (_wlRangeValues.start * 1000)
                                      .toInt()
                                      .toString();
                                  _wlSumMax = (_wlRangeValues.end * 1000)
                                      .toInt()
                                      .toString();
                                  _integrateRangeSel =
                                      IntegrateLigthIntensityRange.vis;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text("310-400nm (UV)"),
                              value: IntegrateLigthIntensityRange.uv,
                              groupValue: _integrateRangeSel,
                              onChanged: (value) {
                                setState(() {
                                  _wlRangeValues = const RangeValues(0.31, 0.4);
                                  _wlSumMin = (_wlRangeValues.start * 1000)
                                      .toInt()
                                      .toString();
                                  _wlSumMax = (_wlRangeValues.end * 1000)
                                      .toInt()
                                      .toString();
                                  _integrateRangeSel =
                                      IntegrateLigthIntensityRange.uv;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text("400-500nm (B)"),
                              value: IntegrateLigthIntensityRange.b,
                              groupValue: _integrateRangeSel,
                              onChanged: (value) {
                                setState(() {
                                  _wlRangeValues = const RangeValues(0.4, 0.5);
                                  _wlSumMin = (_wlRangeValues.start * 1000)
                                      .toInt()
                                      .toString();
                                  _wlSumMax = (_wlRangeValues.end * 1000)
                                      .toInt()
                                      .toString();
                                  _integrateRangeSel =
                                      IntegrateLigthIntensityRange.b;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text("500-600nm (G)"),
                              value: IntegrateLigthIntensityRange.g,
                              groupValue: _integrateRangeSel,
                              onChanged: (value) {
                                setState(() {
                                  _wlRangeValues = const RangeValues(0.5, 0.6);
                                  _wlSumMin = (_wlRangeValues.start * 1000)
                                      .toInt()
                                      .toString();
                                  _wlSumMax = (_wlRangeValues.end * 1000)
                                      .toInt()
                                      .toString();
                                  _integrateRangeSel =
                                      IntegrateLigthIntensityRange.g;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text("600-700nm (R)"),
                              value: IntegrateLigthIntensityRange.r,
                              groupValue: _integrateRangeSel,
                              onChanged: (value) {
                                setState(() {
                                  _wlRangeValues = const RangeValues(0.6, 0.7);
                                  _wlSumMin = (_wlRangeValues.start * 1000)
                                      .toInt()
                                      .toString();
                                  _wlSumMax = (_wlRangeValues.end * 1000)
                                      .toInt()
                                      .toString();
                                  _integrateRangeSel =
                                      IntegrateLigthIntensityRange.r;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text("700-800nm（FR)"),
                              value: IntegrateLigthIntensityRange.fr,
                              groupValue: _integrateRangeSel,
                              onChanged: (value) {
                                setState(() {
                                  _wlRangeValues = const RangeValues(0.7, 0.8);
                                  _wlSumMin = (_wlRangeValues.start * 1000)
                                      .toInt()
                                      .toString();
                                  _wlSumMax = (_wlRangeValues.end * 1000)
                                      .toInt()
                                      .toString();
                                  _integrateRangeSel =
                                      IntegrateLigthIntensityRange.fr;
                                });
                              },
                            ),
                            RadioListTile(
                              title: const Text("カスタム"),
                              value: IntegrateLigthIntensityRange.custom,
                              groupValue: _integrateRangeSel,
                              onChanged: (value) {
                                setState(() {
                                  _integrateRangeSel =
                                      IntegrateLigthIntensityRange.custom;
                                });
                              },
                            ),
                            Visibility(
                                visible: _integrateRangeSel ==
                                    IntegrateLigthIntensityRange.custom,
                                child: Column(
                                  children: <Widget>[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          children: [
                                            const Text("短波長端"),
                                            Text(
                                              _wlSumMin,
                                              style:
                                                  const TextStyle(fontSize: 20),
                                            ),
                                          ],
                                        ),
                                        ElevatedButton(
                                          child: const Text('Reset'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueGrey,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _wlRangeValues =
                                                  const RangeValues(0.31, 0.8);
                                              _wlSumMin =
                                                  (_wlRangeValues.start * 1000)
                                                      .toInt()
                                                      .toString();
                                              _wlSumMax =
                                                  (_wlRangeValues.end * 1000)
                                                      .toInt()
                                                      .toString();
                                              // _integrateRangeSel =
                                              //     IntegrateLigthIntensityRange
                                              //         .all;
                                            });
                                          },
                                        ),
                                        Column(
                                          children: [
                                            const Text("長波長端"),
                                            Text(
                                              _wlSumMax,
                                              style:
                                                  const TextStyle(fontSize: 20),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Center(
                                      //width: 230,
                                      child: RangeSlider(
                                        values: _wlRangeValues,
                                        activeColor: Colors.blueGrey,
                                        inactiveColor: Colors.blueGrey.shade800,
                                        onChanged: (values) {
                                          if (_integrateRangeSel !=
                                              IntegrateLigthIntensityRange
                                                  .custom) {
                                            return;
                                          }
                                          setState(() {
                                            _wlRangeValues = values;
                                            _wlSumMin =
                                                (_wlRangeValues.start * 1000)
                                                    .toInt()
                                                    .toString();
                                            _wlSumMax =
                                                (_wlRangeValues.end * 1000)
                                                    .toInt()
                                                    .toString();
                                          });
                                        },
                                        min: 0.31,
                                        max: 0.8,
                                        divisions: 49,
                                      ),
                                    ),
                                  ],
                                )),
                          ],
                        )
                      ],
                    ),
                  ),
                  Visibility(
                    child: Card(
                      child: Column(
                        children: <Widget>[
                          const Text("視感度・昆虫感度"),
                          RadioListTile(
                              title: const Text("なし"),
                              value: FilterSpectralIntensityType.None,
                              groupValue: _filterSel,
                              onChanged: (value) => {
                                    setState(() => {
                                          _filterSel =
                                              FilterSpectralIntensityType.None
                                        })
                                  }),
                          RadioListTile(
                              title: const Text("UV誘引光"),
                              value: FilterSpectralIntensityType.AllInsects,
                              groupValue: _filterSel,
                              onChanged: (value) => {
                                    setState(() => {
                                          _filterSel =
                                              FilterSpectralIntensityType
                                                  .AllInsects
                                        })
                                  }),
                          RadioListTile(
                              title: const Text("アザミウマ"),
                              value: FilterSpectralIntensityType.Azamiuma,
                              groupValue: _filterSel,
                              onChanged: (value) => {
                                    setState(() => {
                                          _filterSel =
                                              FilterSpectralIntensityType
                                                  .Azamiuma
                                        })
                                  }),
                          RadioListTile(
                              title: const Text("ハチ"),
                              value: FilterSpectralIntensityType.Hachi,
                              groupValue: _filterSel,
                              onChanged: (value) => {
                                    setState(() => {
                                          _filterSel =
                                              FilterSpectralIntensityType.Hachi
                                        })
                                  }),
                          RadioListTile(
                              title: const Text("ガ全般"),
                              value: FilterSpectralIntensityType.Ga350,
                              groupValue: _filterSel,
                              onChanged: (value) => {
                                    setState(() => {
                                          _filterSel =
                                              FilterSpectralIntensityType.Ga350
                                        })
                                  }),
                          RadioListTile(
                              title: const Text("タバコスズメガ、ヒトリガ、オオタバコガ、コナガ"),
                              value: FilterSpectralIntensityType.Ga550,
                              groupValue: _filterSel,
                              onChanged: (value) => {
                                    setState(() => {
                                          _filterSel =
                                              FilterSpectralIntensityType.Ga550
                                        })
                                  }),
                          RadioListTile(
                              title: const Text("ハスモンヨトウ"),
                              value: FilterSpectralIntensityType.Ga350550,
                              groupValue: _filterSel,
                              onChanged: (value) => {
                                    setState(() => {
                                          _filterSel =
                                              FilterSpectralIntensityType
                                                  .Ga350550
                                        })
                                  }),
                          RadioListTile(
                              title: const Text("視感度"),
                              value: FilterSpectralIntensityType.Y,
                              groupValue: _filterSel,
                              onChanged: (value) => {
                                    setState(() => {
                                          _filterSel =
                                              FilterSpectralIntensityType.Y
                                        })
                                  }),
                        ],
                      ),
                    ),
                    visible: _measureModeSel == MeasureMode.insectsIrradiance
                        ? true
                        : false,
                  ),
                  // Card(
                  //   child: Column(
                  //   children: <Widget>[
                  //     const Text("露光時間"),
                  // RadioListTile(title: const Text("AUTO"), value: "AUTO", groupValue: _exposuretime, onChanged: (value) => { setState(()=>{_exposuretime = value.toString()})}),
                  // RadioListTile(title: const Text("100us"), value: "100us", groupValue: _exposuretime, onChanged: (value) => { setState(()=>{_exposuretime = value.toString()})}),
                  // RadioListTile(title: const Text("1ms"), value: "1ms", groupValue: _exposuretime, onChanged: (value) => { setState(()=>{_exposuretime = value.toString()})}),
                  // RadioListTile(title: const Text("10ms"), value: "10ms", groupValue: _exposuretime, onChanged: (value) => { setState(()=>{_exposuretime = value.toString()})}),
                  // RadioListTile(title: const Text("100ms"), value: "100ms", groupValue: _exposuretime, onChanged: (value) => { setState(()=>{_exposuretime = value.toString()})}),
                  //   ],
                  // ),
                  // ),
                  Card(
                      child: ListTile(
                        title: const Text("このアプリの情報について"),
                        onTap: (){
                          showLicensePage(
                            context: context,
                            applicationName: "虫用分光放射照度計CP160",
                            applicationVersion: "1.0.0",
                            // applicationIcon: MyAppIcon(),
                            applicationLegalese:
                                "\u{a9} 2023 NOBUO ELECTRONICS CO., LTD.",
                          );
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
