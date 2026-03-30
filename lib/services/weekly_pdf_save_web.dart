import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> saveWeeklyReportPdf(Uint8List bytes) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', 'SmartBin-Weekly-Report.pdf')
    ..click();
  html.Url.revokeObjectUrl(url);
}
