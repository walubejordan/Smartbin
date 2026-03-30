import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_service.dart';
import 'weekly_pdf_save.dart';

/// Fetches the weekly PDF, shows a blocking dialog, saves/opens the file, snackbars.
Future<void> downloadWeeklyReportPdf(BuildContext context) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Generating Report...',
                style: Theme.of(ctx).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  try {
    final api = Provider.of<ApiService>(context, listen: false);
    final bytes = await api.downloadWeeklyPdfReport();
    if (!context.mounted) return;
    nav.pop();
    await saveWeeklyReportPdf(bytes);
    if (!context.mounted) return;
    messenger?.showSnackBar(
      const SnackBar(content: Text('Report downloaded')),
    );
  } catch (e) {
    if (context.mounted) nav.pop();
    if (context.mounted) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not download report: $e')),
      );
    }
  }
}
