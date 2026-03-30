import 'package:flutter/material.dart';

import 'admin/dashboard_screen.dart' show AdminDashboardScreen;
import 'collector/collector_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  /// Admin dashboard shortcuts (shell tab indices).
  final VoidCallback? onAdminAddBin;
  final VoidCallback? onAdminAssign;
  final VoidCallback? onAdminReports;
  final VoidCallback? onAdminDownloadReport;

  /// Collector shell tab switches (IndexedStack indices).
  final VoidCallback? onCollectorOpenMap;
  final VoidCallback? onCollectorOpenHistory;
  final VoidCallback? onCollectorOpenAlerts;

  const DashboardScreen({
    super.key,
    required this.user,
    this.onAdminAddBin,
    this.onAdminAssign,
    this.onAdminReports,
    this.onAdminDownloadReport,
    this.onCollectorOpenMap,
    this.onCollectorOpenHistory,
    this.onCollectorOpenAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = user['role']?.toString() == 'admin';
    if (!isAdmin) {
      return CollectorDashboard(
        user: user,
        onOpenMap: onCollectorOpenMap,
        onOpenHistory: onCollectorOpenHistory,
        onOpenAlerts: onCollectorOpenAlerts,
      );
    }
    return AdminDashboardScreen(
      user: user,
      onAddBin: onAdminAddBin,
      onAssign: onAdminAssign,
      onReports: onAdminReports,
      onDownloadReport: onAdminDownloadReport,
    );
  }
}
