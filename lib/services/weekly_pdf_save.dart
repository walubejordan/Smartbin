import 'dart:typed_data';

import 'weekly_pdf_save_stub.dart'
    if (dart.library.io) 'weekly_pdf_save_io.dart'
    if (dart.library.html) 'weekly_pdf_save_web.dart' as impl;

/// Saves the weekly PDF (opens on mobile/desktop; browser download on web).
Future<void> saveWeeklyReportPdf(Uint8List bytes) =>
    impl.saveWeeklyReportPdf(bytes);
