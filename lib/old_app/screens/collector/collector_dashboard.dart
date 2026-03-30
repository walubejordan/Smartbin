import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../services/mqtt_service.dart';
import '../login_screen.dart';
import '../notifications_screen.dart';
import '../settings_screen.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/liquid_linear_progress_indicator.dart';
import '../../../widgets/smartbin_fill_icon.dart';
import '../../../widgets/responsive_shell.dart';
import 'map_view_screen.dart';
import 'collection_history_screen.dart';
import 'smartwaste_collector_dashboard_tab.dart';

class CollectorDashboard extends StatefulWidget {
  final Map<String, dynamic> user;

  const CollectorDashboard({super.key, required this.user});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  int _selectedIndex = 0;
  List<dynamic> _bins = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  final List<String> _titles = [
    'Collector Dashboard',
    'My Assigned Bins',
    'Bin Locations Map',
    'Collection History',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupMqtt();
    _loadUnreadCount();
  }

  void _setupMqtt() {
    final mqttService = Provider.of<MqttService>(context, listen: false);
    mqttService.onNotificationReceived = (notification) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(notification['message'] ?? 'New notification'),
          backgroundColor:
              notification['type'] == 'critical' ? Colors.red : Colors.orange,
        ),
      );
      _loadUnreadCount();
      _loadData();
    };
    mqttService.onBinStatusUpdate = (topic, data) => _loadBins();
  }

  Future<void> _loadUnreadCount() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final data = await apiService.getNotifications(isRead: false, limit: 1);
      if (!mounted) return;
      setState(() {
        _unreadCount = (data['unread_count'] ?? 0) as int;
      });
    } catch (_) {
      // Ignore badge failures.
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadBins();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadBins() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final assignedTo = widget.user['id'];
      final bins = await apiService.getBins(
        assignedTo:
            assignedTo is int ? assignedTo : int.tryParse('$assignedTo'),
      );
      if (mounted) setState(() => _bins = bins);
    } catch (e) {
      debugPrint('Bins error: $e');
    }
  }

  Future<void> _markBinCollected(int binId, String binCode) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      await apiService.collectBin(binId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$binCode marked as collected'),
            backgroundColor: Colors.green),
      );
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _logout() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    Provider.of<MqttService>(context, listen: false).disconnect();
    await apiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  List<Widget> _buildPages() {
    return [
      SmartWasteCollectorDashboardTab(
        userName: widget.user['name']?.toString() ?? 'Collector',
      ),
      _wrapSecondaryTab(_buildBinsList()),
      _wrapSecondaryTab(MapViewScreen(user: widget.user)),
      _wrapSecondaryTab(CollectionHistoryScreen(user: widget.user)),
      SettingsScreen(user: widget.user),
    ];
  }

  /// Bins / map / history wait on shared [_loadData]; settings loads independently.
  Widget _wrapSecondaryTab(Widget child) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user['name']?.toString() ?? 'Collector';
    final userEmail = widget.user['email']?.toString() ?? '';

    return ResponsiveShell(
      userName: userName,
      userEmail: userEmail,
      pageTitles: _titles,
      pages: _buildPages(),
      selectedIndex: _selectedIndex,
      onIndexChanged: (i) => setState(() => _selectedIndex = i),
      onLogout: _logout,
      unreadNotificationCount: _unreadCount,
      onNotificationsOpened: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NotificationsScreen(),
          ),
        );
        if (mounted) _loadUnreadCount();
      },
      onRefresh: _loadData,
    );
  }

  Widget _buildBinsList() {
    if (_bins.isEmpty) return const Center(child: Text('No bins assigned'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bins.length,
      itemBuilder: (context, index) => _buildBinCard(_bins[index]),
    );
  }

  Widget _buildBinCard(Map<String, dynamic> bin) {
    final fillLevel = (bin['fill_level'] ?? 0).toDouble();
    final progress = (fillLevel / 100).clamp(0.0, 1.0);
    final status = bin['status'] ?? 'normal';
    final Color statusColor = status == 'critical'
        ? Colors.red
        : (status == 'warning'
            ? Colors.orange
            : (status == 'offline' ? Colors.grey : Colors.green));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                SmartBinFillIcon(
                  fillLevel: fillLevel,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bin['bin_code'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.headerText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bin['location'],
                        style: const TextStyle(
                          color: AppColors.subText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${fillLevel.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LiquidLinearProgressIndicator(
              value: progress,
              color: statusColor,
              height: 12,
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {/* Navigate logic */},
                  icon: const FaIcon(FontAwesomeIcons.locationArrow),
                  label: const Text('Route'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      _markBinCollected(bin['id'], bin['bin_code']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Mark Collected'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
