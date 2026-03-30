import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/admin/analytics_screen.dart';
import '../screens/admin/bins_screen.dart';
import '../screens/admin/collectors_screen.dart';
import '../screens/bins_screen.dart';
import '../screens/collector/bins_screen.dart';
import '../screens/collector/history_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/map_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/settings_screen.dart';
import '../services/api_service.dart';
import '../services/weekly_report_download.dart';
import '../services/mqtt_service.dart';
import '../theme/app_colors.dart';

class _NavEntry {
  final String title;
  final IconData icon;
  /// Shorter label for crowded [BottomNavigationBar] items.
  final String? bottomLabel;
  const _NavEntry(this.title, this.icon, [this.bottomLabel]);
}

/// Responsive shell: bottom navigation (narrow) or permanent sidebar (wide).
class AppShell extends StatefulWidget {
  final Map<String, dynamic> user;

  const AppShell({super.key, required this.user});

  static const double breakpoint = 900;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  /// Subtitle for user Settings tab (e.g. "Account Details"); cleared when leaving that tab.
  String? _settingsHeaderOverride;
  late Map<String, dynamic> _user;
  final GlobalKey<MapScreenState> _mapScreenKey = GlobalKey<MapScreenState>();
  final GlobalKey<BinsScreenState> _collectorBinsKey =
      GlobalKey<BinsScreenState>();
  final GlobalKey<AdminBinsScreenState> _adminBinsKey =
      GlobalKey<AdminBinsScreenState>();

  bool get _isAdmin => _user['role']?.toString() == 'admin';

  void _openBinOnMap(double lat, double lng) {
    setState(() => _index = _kMap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapScreenKey.currentState?.zoomToBin(lat, lng);
    });
  }

  void _goBinsAndOpenAddDialog() {
    setState(() => _index = _kBins);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adminBinsKey.currentState?.openAddBinDialog();
    });
  }

  void _refreshMapAfterBinsCollect() {
    _mapScreenKey.currentState?.refreshBinData();
  }

  void _refreshBinsListAfterMapCollect() {
    _collectorBinsKey.currentState?.reload();
  }

  /// [IndexedStack] indices (must match [_stackChildren] order).
  static const int _kDashboard = 0;
  static const int _kBins = 1;
  static const int _kMap = 2;
  static const int _kNotifications = 3;
  static const int _kCollectors = 4;
  static const int _kAnalytics = 5;
  /// Unified settings (account, thresholds admin-only, theme, session); sidebar footer / mobile bar.
  static const int _kUserSettingsAdmin = 6;

  /// Collector stack: History(3), Notifications(4), User settings(5).
  static const int _kCollectorHistory = 3;
  static const int _kCollectorNotifications = 4;
  static const int _kUserSettingsCollector = 5;

  /// Collector mobile bottom bar: Home, My bins, Map, Alerts (Settings → kebab menu).
  static const List<int> _collectorMobileBottomStacks = [
    _kDashboard,
    _kBins,
    _kMap,
    _kCollectorNotifications,
  ];

  /// Admin mobile bottom bar: Home, Bins, Alerts, Team only (Settings → kebab menu).
  static const List<int> _adminMobileBottomStacks = [
    _kDashboard,
    _kBins,
    _kNotifications,
    _kCollectors,
  ];

  /// True when admin is on Map, Analytics, or Settings (not one of the four bottom tabs).
  bool get _adminOnOverflowTab =>
      _isAdmin &&
      (_index == _kMap ||
          _index == _kAnalytics ||
          _index == _kUserSettingsAdmin);

  /// Bottom bar slot 0–3 for admin; on overflow tabs use 0 with neutral styling.
  int get _adminMobileBottomSlot {
    final slot = _adminMobileBottomStacks.indexOf(_index);
    if (slot >= 0) return slot;
    return 0;
  }

  /// True when collector is on History or Settings (not one of the four bottom tabs).
  bool get _collectorOnOverflowTab =>
      !_isAdmin &&
      (_index == _kCollectorHistory || _index == _kUserSettingsCollector);

  /// Slot 0–3 for collector bottom bar; on overflow tabs use 0 with neutral styling.
  int get _collectorMobileBottomSlot {
    final slot = _collectorMobileBottomStacks.indexOf(_index);
    if (slot >= 0) return slot;
    return 0;
  }

  List<_NavEntry> get _navEntries {
    if (_isAdmin) {
      return const [
        _NavEntry('Dashboard', Icons.dashboard_outlined, 'Home'),
        _NavEntry('Bins', Icons.delete_outline),
        _NavEntry('Map', Icons.map_outlined),
        _NavEntry('Notifications', Icons.notifications_outlined, 'Alerts'),
        _NavEntry('Collectors', Icons.people_outline, 'Team'),
        _NavEntry('Analytics', Icons.insights_outlined, 'Stats'),
      ];
    }
    return const [
      _NavEntry('Dashboard', Icons.dashboard_outlined, 'Home'),
      _NavEntry('My bins', Icons.delete_outline),
      _NavEntry('Map', Icons.map_outlined),
      _NavEntry('History', Icons.history, 'History'),
      _NavEntry('Notifications', Icons.notifications_outlined, 'Alerts'),
    ];
  }

  List<Widget> get _stackChildren {
    final user = _user;
    if (_isAdmin) {
      return [
        DashboardScreen(
          user: user,
          onAdminAddBin: _goBinsAndOpenAddDialog,
          onAdminAssign: () => setState(() => _index = _kCollectors),
          onAdminReports: () => setState(() => _index = _kAnalytics),
          onAdminDownloadReport: () => downloadWeeklyReportPdf(context),
        ),
        AdminBinsScreen(
          key: _adminBinsKey,
          user: user,
          onShowBinOnMap: _openBinOnMap,
        ),
        MapScreen(key: _mapScreenKey, user: user),
        const NotificationsScreen(),
        const CollectorsScreen(),
        const AnalyticsScreen(),
        SettingsScreen(
          user: user,
          onUserUpdated: _mergeUserProfile,
          onLogout: _logout,
          isSettingsTabActive: _index == _kUserSettingsAdmin,
          onHeaderTitleChanged: (t) {
            if (!mounted) return;
            setState(() => _settingsHeaderOverride = t);
          },
        ),
      ];
    }
    return [
      DashboardScreen(
        user: user,
        onCollectorOpenMap: () => setState(() => _index = _kMap),
        onCollectorOpenHistory: () => setState(() => _index = _kCollectorHistory),
        onCollectorOpenAlerts: () =>
            setState(() => _index = _kCollectorNotifications),
      ),
      CollectorBinsScreen(
        binsListKey: _collectorBinsKey,
        user: user,
        onShowBinOnMap: _openBinOnMap,
        onCollectionComplete: _refreshMapAfterBinsCollect,
      ),
      MapScreen(
        key: _mapScreenKey,
        user: user,
        onCollectionComplete: _refreshBinsListAfterMapCollect,
      ),
      const CollectorHistoryScreen(),
      const NotificationsScreen(),
      SettingsScreen(
        user: user,
        onUserUpdated: _mergeUserProfile,
        onLogout: _logout,
        isSettingsTabActive: _index == _kUserSettingsCollector,
        onHeaderTitleChanged: (t) {
          if (!mounted) return;
          setState(() => _settingsHeaderOverride = t);
        },
      ),
    ];
  }

  int get _userSettingsIndex =>
      _isAdmin ? _kUserSettingsAdmin : _kUserSettingsCollector;

  int get _stackLength => _stackChildren.length;

  String _shellTitle(int index) {
    final entries = _navEntries;
    if (index == _userSettingsIndex) {
      return _settingsHeaderOverride ?? 'Settings';
    }
    if (index >= 0 && index < entries.length) {
      return entries[index].title;
    }
    return 'SmartBin';
  }

  void _selectHistoryTab() {
    if (_isAdmin) return;
    setState(() => _index = _kCollectorHistory);
  }

  void _mergeUserProfile(Map<String, dynamic> patch) {
    setState(() => _user.addAll(patch));
  }

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = _user['id']?.toString();
      if (id == null || id.isEmpty) return;
      final mqtt = Provider.of<MqttService>(context, listen: false);
      mqtt.connect(id).catchError((e) {
        debugPrint('MQTT connect: $e');
      });
      if (_isAdmin) {
        final api = Provider.of<ApiService>(context, listen: false);
        api.startBinMonitoring();
      }
    });
  }

  Future<void> _logout() async {
    final api = Provider.of<ApiService>(context, listen: false);
    api.stopBinMonitoring();
    final mqtt = Provider.of<MqttService>(context, listen: false);
    mqtt.disconnect();
    try {
      await api.logout();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _onMobileMenuSelected(String value) {
    if (value == 'logout') {
      _logout();
      return;
    }
    if (value == 'history' && !_isAdmin) {
      _selectHistoryTab();
      return;
    }
    if (value == 'user_settings') {
      setState(() => _index = _userSettingsIndex);
      return;
    }
    if (!_isAdmin) return;
    final int? nextIndex = switch (value) {
      'map' => _kMap,
      'analytics' => _kAnalytics,
      _ => null,
    };
    if (nextIndex != null) setState(() => _index = nextIndex);
  }

  List<Widget> _mobileAppBarMenuActions(BuildContext context) {
    return [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'More',
        onSelected: _onMobileMenuSelected,
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[];
          if (!_isAdmin) {
            items.addAll([
              PopupMenuItem(
                value: 'history',
                child: _kebabMenuRow(Icons.history, 'History'),
              ),
              PopupMenuItem(
                value: 'user_settings',
                child: _kebabMenuRow(Icons.settings, 'Settings'),
              ),
              const PopupMenuDivider(),
            ]);
          }
          if (_isAdmin) {
            items.addAll([
              PopupMenuItem(
                value: 'map',
                child: _kebabMenuRow(Icons.map_outlined, 'Map'),
              ),
              PopupMenuItem(
                value: 'analytics',
                child: _kebabMenuRow(Icons.insights_outlined, 'Analytics'),
              ),
              PopupMenuItem(
                value: 'user_settings',
                child: _kebabMenuRow(Icons.settings, 'Settings'),
              ),
              const PopupMenuDivider(),
            ]);
          }
          items.add(
            PopupMenuItem<String>(
              value: 'logout',
              child: _kebabMenuRow(Icons.logout, 'Log out', iconColor: Colors.red),
            ),
          );
          return items;
        },
      ),
    ];
  }

  static Widget _kebabMenuRow(
    IconData icon,
    String label, {
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: iconColor,
              fontWeight:
                  iconColor != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _navEntries;
    final stackIndex = _index.clamp(0, _stackLength - 1);
    final stack = IndexedStack(
      index: stackIndex,
      sizing: StackFit.expand,
      children: _stackChildren,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > AppShell.breakpoint;

        if (wide) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(
                  selectedIndex: _index,
                  entries: entries,
                  userSettingsIndex: _userSettingsIndex,
                  userName: _user['name']?.toString() ?? 'User',
                  onSelect: (i) => setState(() => _index = i),
                  onLogout: _logout,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        elevation: 0,
                        color: AppColors.scaffoldBackground,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Text(
                                  _shellTitle(stackIndex),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: stack),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_shellTitle(stackIndex)),
            actions: _mobileAppBarMenuActions(context),
            automaticallyImplyLeading: true,
          ),
          body: stack,
          bottomNavigationBar: _isAdmin
              ? Builder(
                  builder: (context) {
                    final scheme = Theme.of(context).colorScheme;
                    final muted = scheme.onSurfaceVariant;
                    final neutralBar = _adminOnOverflowTab;
                    return BottomNavigationBar(
                      currentIndex: _adminMobileBottomSlot,
                      onTap: (slot) => setState(
                        () => _index = _adminMobileBottomStacks[slot],
                      ),
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor:
                          neutralBar ? muted : scheme.primary,
                      unselectedItemColor: muted,
                      selectedFontSize: 12,
                      unselectedFontSize: 12,
                      selectedLabelStyle: TextStyle(
                        fontWeight:
                            neutralBar ? FontWeight.w500 : FontWeight.w600,
                        color: neutralBar ? muted : scheme.primary,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.dashboard_outlined),
                          activeIcon: Icon(Icons.dashboard),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.delete_outline),
                          activeIcon: Icon(Icons.delete),
                          label: 'Bins',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.notifications_outlined),
                          activeIcon: Icon(Icons.notifications),
                          label: 'Alerts',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.people_outline),
                          activeIcon: Icon(Icons.people),
                          label: 'Team',
                        ),
                      ],
                    );
                  },
                )
              : Builder(
                  builder: (context) {
                    final scheme = Theme.of(context).colorScheme;
                    final muted = scheme.onSurfaceVariant;
                    final neutralBar = _collectorOnOverflowTab;
                    return BottomNavigationBar(
                      currentIndex: _collectorMobileBottomSlot,
                      onTap: (slot) => setState(
                        () => _index = _collectorMobileBottomStacks[slot],
                      ),
                      type: BottomNavigationBarType.fixed,
                      selectedItemColor:
                          neutralBar ? muted : scheme.primary,
                      unselectedItemColor: muted,
                      selectedFontSize: 12,
                      unselectedFontSize: 12,
                      selectedLabelStyle: TextStyle(
                        fontWeight:
                            neutralBar ? FontWeight.w500 : FontWeight.w600,
                        color: neutralBar ? muted : scheme.primary,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: muted,
                      ),
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.dashboard_outlined),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.delete_outline),
                          label: 'My bins',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.map_outlined),
                          label: 'Map',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.notifications_outlined),
                          label: 'Alerts',
                        ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavEntry> entries;
  final int userSettingsIndex;
  final String userName;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.selectedIndex,
    required this.entries,
    required this.userSettingsIndex,
    required this.userName,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.primaryGreen,
                      child: Icon(Icons.recycling, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SmartBin',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.subText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      ListTile(
                        selected: selectedIndex == i,
                        selectedTileColor: AppColors.primaryGreen
                            .withValues(alpha: 0.12),
                        leading: Icon(entries[i].icon),
                        title: Text(entries[i].title),
                        onTap: () => onSelect(i),
                      ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      offset: const Offset(0, -2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      selected: selectedIndex == userSettingsIndex,
                      selectedTileColor: AppColors.primaryGreen
                          .withValues(alpha: 0.12),
                      leading: const Icon(Icons.settings),
                      title: const Text('Settings'),
                      onTap: () => onSelect(userSettingsIndex),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Log out'),
                      onTap: onLogout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

