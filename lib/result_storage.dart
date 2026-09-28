import 'dart:convert';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:uvvisspec_insects_app/settings.dart';
import 'uvvisspecapp.dart';

class ResultStorage {
  Future<void> write(String filename, ResultReport result) async {
    final wl = result.wl;
    final sp = result.sp;
    final len = sp.length;
    final mdt = result.measureDatetime;
    final unit = result.mode == MeasureMode.irradiance
        ? "放射照度[W・m^-2]"
        : result.mode == MeasureMode.insectsIrradiance
            ? "光子数密度[photons・m^-2・S^-1]"
            : "光量子束密度[μmol・m^-2・S^-1]";
    var name = result.filterName;

    final buffer = StringBuffer();
    buffer.write('測定日, $mdt\r\n');
    if (name != "") {
      buffer.write('昆虫タイプ, $name\r\n');
    }
    buffer.write('波長[nm], $unit\r\n');
    for (var i = 0; i < len; i++) {
      buffer.write('${wl[i]},${sp[i]}\r\n');
    }

    final csvBytes = utf8.encode(buffer.toString());
    final bomBytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...csvBytes]);

    await FileSaver.instance.saveToDownloads(
      name: filename,
      bytes: bomBytes,
      fileExtension: 'csv',
      mimeType: MimeType.other,
    );
  }
}