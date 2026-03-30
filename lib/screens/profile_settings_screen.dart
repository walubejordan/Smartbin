import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Edit name, email, phone (admins) or assigned zone (collectors), and password.
class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  /// Called with merged profile fields after a successful save.
  final void Function(Map<String, dynamic> patch) onUserUpdated;

  /// When true, no [Scaffold]/[AppBar] — embed under another screen (e.g. admin settings).
  final bool embedded;

  /// When true (main [AppShell] tab), no [Scaffold]/[AppBar]; scrollable body only (shell shows title).
  final bool insideShell;

  const ProfileSettingsScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    this.embedded = false,
    this.insideShell = false,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _saving = false;
  bool _changingPass = false;
  bool _showPasswordSection = false;

  bool get _isCollector =>
      widget.user['role']?.toString().toLowerCase() == 'collector';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user['name']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: widget.user['email']?.toString() ?? '');
    _phoneCtrl = TextEditingController(
      text: _isCollector
          ? (widget.user['zone'] ?? widget.user['phone'] ?? '').toString()
          : (widget.user['phone']?.toString() ?? ''),
    );
  }

  @override
  void didUpdateWidget(ProfileSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user['name'] != widget.user['name']) {
      _nameCtrl.text = widget.user['name']?.toString() ?? '';
    }
    if (oldWidget.user['email'] != widget.user['email']) {
      _emailCtrl.text = widget.user['email']?.toString() ?? '';
    }
    if (_isCollector) {
      final z = '${widget.user['zone'] ?? ''}';
      final p = '${widget.user['phone'] ?? ''}';
      final oz = '${oldWidget.user['zone'] ?? ''}';
      final op = '${oldWidget.user['phone'] ?? ''}';
      if (z != oz || p != op) {
        _phoneCtrl.text = (widget.user['zone'] ?? widget.user['phone'] ?? '').toString();
      }
    } else if (oldWidget.user['phone'] != widget.user['phone']) {
      _phoneCtrl.text = widget.user['phone']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required')),
      );
      return;
    }
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email')),
      );
      return;
    }

    setState(() => _saving = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final data = await api.updateMyProfile(
        name: name,
        email: email,
        includePhone: !_isCollector,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        includeZone: _isCollector,
        zone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      widget.onUserUpdated({
        'name': data['name'] ?? name,
        'email': data['email'] ?? email,
        'phone': data['phone'],
        'zone': data['zone'],
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePassword() async {
    final cur = _currentPassCtrl.text;
    final nw = _newPassCtrl.text;
    final cf = _confirmPassCtrl.text;
    if (nw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters')),
      );
      return;
    }
    if (nw != cf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() => _changingPass = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.changePassword(currentPassword: cur, newPassword: nw);
      if (!mounted) return;
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      setState(() => _showPasswordSection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password changed'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _changingPass = false);
    }
  }

  Widget _formBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.embedded
              ? 'Edit profile'
              : (widget.insideShell ? 'Account' : 'Your details'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Full name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          decoration: InputDecoration(
            labelText: _isCollector ? 'Assigned zone' : 'Phone (optional)',
            hintText: _isCollector ? 'e.g. Main Campus, Hostels, Retail' : null,
            prefixIcon: Icon(_isCollector ? Icons.map_outlined : Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isCollector
              ? 'Must match a bin zone name exactly (same labels as admin uses for bins) so your tasks filter correctly.'
              : 'Optional contact number for your account.',
          style: const TextStyle(fontSize: 12, color: AppColors.subText),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _saveProfile,
          child: _saving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save profile'),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: () => setState(() => _showPasswordSection = !_showPasswordSection),
          child: Row(
            children: [
              Icon(
                _showPasswordSection ? Icons.expand_less : Icons.expand_more,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              const Text(
                'Change password',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        if (_showPasswordSection) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _currentPassCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPassCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPassCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _changingPass ? null : _savePassword,
            child: _changingPass
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Update password'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: (widget.embedded || widget.insideShell) ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _formBody(),
      ),
    );

    if (widget.embedded) {
      return card;
    }

    if (widget.insideShell) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: card,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: card,
      ),
    );
  }
}
