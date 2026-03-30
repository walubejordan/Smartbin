import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/preferences_keys.dart';
import 'profile_settings_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_mode.dart';

/// Unified settings: Account (nested form), optional System thresholds (admin),
/// Theme, and Session. Opened only from the shell sidebar footer (or mobile bar).
class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final void Function(Map<String, dynamic> patch) onUserUpdated;
  final VoidCallback onLogout;

  /// When this tab is not selected, nested "Account Details" view resets.
  final bool isSettingsTabActive;

  /// Updates shell / AppBar title: `null` → "Settings", non-null → e.g. "Account Details".
  final ValueChanged<String?>? onHeaderTitleChanged;

  const SettingsScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
    required this.isSettingsTabActive,
    this.onHeaderTitleChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _accountDetails = false;
  double _fillAlertPercent = 80;
  bool _prefsLoaded = false;

  bool get _isAdmin =>
      widget.user['role']?.toString().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    if (_isAdmin) {
      _loadPrefs();
    } else {
      _prefsLoaded = true;
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getInt(PreferencesKeys.adminFillLevelAlertThreshold);
      if (mounted) {
        setState(() {
          if (v != null && v >= 0 && v <= 100) {
            _fillAlertPercent = v.toDouble();
          }
          _prefsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _prefsLoaded = true);
    }
  }

  Future<void> _saveFillThreshold(double v) async {
    setState(() => _fillAlertPercent = v);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(PreferencesKeys.adminFillLevelAlertThreshold, v.round());
    } catch (_) {}
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSettingsTabActive &&
        !widget.isSettingsTabActive &&
        _accountDetails) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _accountDetails = false);
        widget.onHeaderTitleChanged?.call(null);
      });
    }
  }

  @override
  void dispose() {
    widget.onHeaderTitleChanged?.call(null);
    super.dispose();
  }

  void _setAccountDetails(bool open) {
    setState(() => _accountDetails = open);
    widget.onHeaderTitleChanged?.call(open ? 'Account Details' : null);
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _cardShell({required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accountDetails) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to settings',
                onPressed: () => _setAccountDetails(false),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: ProfileSettingsScreen(
                user: widget.user,
                onUserUpdated: widget.onUserUpdated,
                embedded: true,
                insideShell: true,
              ),
            ),
          ),
        ],
      );
    }

    final themeMode = context.watch<AppThemeMode>().mode;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(context, 'Account'),
        _cardShell(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.primaryGreen,
                ),
              ),
              title: Text(
                widget.user['name']?.toString() ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(widget.user['email']?.toString() ?? ''),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Account details'),
              subtitle: const Text('Name, email, password, and more'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _setAccountDetails(true),
            ),
          ],
        ),
        if (_isAdmin) ...[
          const SizedBox(height: 20),
          _sectionTitle(context, 'System thresholds'),
          _cardShell(
            children: [
              const Text(
                'Fill level alert',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Notify when a bin reaches ${_fillAlertPercent.round()}% capacity (stored on device for future alert rules).',
                style: const TextStyle(
                  color: AppColors.subText,
                  fontSize: 13,
                ),
              ),
              if (!_prefsLoaded)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Slider(
                  value: _fillAlertPercent,
                  min: 50,
                  max: 100,
                  divisions: 50,
                  label: '${_fillAlertPercent.round()}%',
                  onChanged: _saveFillThreshold,
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _sectionTitle(context, 'Theme'),
        _cardShell(
          children: [
            const Text(
              'Appearance',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (set) {
                final m = set.first;
                context.read<AppThemeMode>().setMode(m);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, 'Session'),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () async {
            final go = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Log out'),
                content: const Text(
                  'You will need to sign in again to access the dashboard.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Log out'),
                  ),
                ],
              ),
            );
            if (go == true && context.mounted) {
              widget.onLogout();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 8),
        Text(
          'You can also log out from the sidebar (desktop) or the app menu (mobile).',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
