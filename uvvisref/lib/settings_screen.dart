import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppSettings {
  int sampleCount = 1;
  bool useDateTime = true;
  String userFileName = '';
}

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  const SettingsScreen({required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _sampleCount;
  late bool _useDateTime;
  late String _userFileName;
  final _fileNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sampleCount = widget.settings.sampleCount;
    _useDateTime = widget.settings.useDateTime;
    _userFileName = widget.settings.userFileName;
    _fileNameController.text = _userFileName;
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.blueGrey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.settings.sampleCount = _sampleCount;
            widget.settings.useDateTime = _useDateTime;
            widget.settings.userFileName = _userFileName;
            Navigator.pop(context, widget.settings);
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      backgroundColor: Colors.grey[900],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text('測定',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            
            Center(
              child: Text('保存ファイル名',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _useDateTime,
                  onChanged: (v) => setState(() => _useDateTime = v!),
                  activeColor: Colors.green,
                ),
                Text('データ取得時刻',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            Row(
              children: [
                Radio<bool>(
                  value: false,
                  groupValue: _useDateTime,
                  onChanged: (v) => setState(() => _useDateTime = v!),
                  activeColor: Colors.green,
                ),
                Text('ユーザー記入',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            if (!_useDateTime)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 8),
                child: TextField(
                  controller: _fileNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ファイル名を入力',
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                  onChanged: (v) => _userFileName = v,
                ),
              ),
          ],
        ),
      ),
    );
  }
}