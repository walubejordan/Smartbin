import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

Future<void> saveWeeklyReportPdf(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/SmartBin-Weekly-Report.pdf';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  await OpenFile.open(path);
}
