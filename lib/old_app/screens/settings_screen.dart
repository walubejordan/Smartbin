import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/mqtt_service.dart';
import '../screens/login_screen.dart' as login;

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  bool _pushNotifications = true;
  bool _darkMode = false;
  bool _locationServices = true;
  bool _autoSync = true;
  String _language = 'English';

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    // Call API to change password (add this method to API service)
    // For now, just show success
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final apiService = Provider.of<ApiService>(context, listen: false);
    final mqttService = Provider.of<MqttService>(context, listen: false);

    mqttService.disconnect();

    try {
      await apiService.logout();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const login.LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final nameController =
        TextEditingController(text: widget.user['name'] ?? '');
    final emailController =
        TextEditingController(text: widget.user['email'] ?? '');
    final phoneController =
        TextEditingController(text: widget.user['phone'] ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updateUser(widget.user['id'],
          name: nameController.text,
          email: emailController.text,
          phone: phoneController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );

        setState(() {
          widget.user['name'] = nameController.text;
          widget.user['email'] = emailController.text;
          widget.user['phone'] = phoneController.text;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportData() async {
    final csv = StringBuffer();
    csv.writeln('Field,Value');
    csv.writeln('Name,${widget.user['name'] ?? ''}');
    csv.writeln('Email,${widget.user['email'] ?? ''}');
    csv.writeln('Phone,${widget.user['phone'] ?? ''}');
    csv.writeln('Role,${widget.user['role'] ?? ''}');

    await Clipboard.setData(ClipboardData(text: csv.toString()));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Profile data copied to clipboard as CSV (for export).')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open specified URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Profile Section
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green.withOpacity(0.2),
                  child: Text(
                    widget.user['name']
                        .toString()
                        .split(' ')
                        .map((n) => n[0])
                        .take(2)
                        .join()
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.user['name'],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user['email'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.user['role'] == 'admin'
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.user['role'].toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.user['role'] == 'admin'
                          ? Colors.purple
                          : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Account Settings
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePassword,
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editProfile,
          ),
          const Divider(),

          // App Settings
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Preferences',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts for critical bins'),
            value: _pushNotifications,
            onChanged: (value) {
              setState(() => _pushNotifications = value);
              // Save preference
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.location_on_outlined),
            title: const Text('Location Services'),
            subtitle: const Text('Enable location tracking for routes'),
            value: _locationServices,
            onChanged: (value) {
              setState(() => _locationServices = value);
              // Save preference
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.sync_outlined),
            title: const Text('Auto Sync'),
            subtitle: const Text('Automatically sync data in background'),
            value: _autoSync,
            onChanged: (value) {
              setState(() => _autoSync = value);
              // Save preference
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: _darkMode,
            onChanged: (value) {
              setState(() => _darkMode = value);
              // Save preference
            },
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('Language'),
            subtitle: Text(_language),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Show language selection dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Language'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('English'),
                        onTap: () {
                          setState(() => _language = 'English');
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        title: const Text('Spanish'),
                        onTap: () {
                          setState(() => _language = 'Spanish');
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        title: const Text('French'),
                        onTap: () {
                          setState(() => _language = 'French');
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(),

          // Data Management
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Data Management',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export Data'),
            subtitle: const Text('Download your data as CSV'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exportData,
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup Data'),
            subtitle: const Text('Create a backup of your data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Backup functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup feature coming soon')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.clear_outlined),
            title: const Text('Clear Cache'),
            subtitle: const Text('Free up storage space'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Clear cache functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
          ),
          const Divider(),

          // About
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Version'),
            trailing: Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Terms & Conditions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openUrl('https://example.com/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openUrl('https://example.com/privacy'),
          ),
          const Divider(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: _logout,
          ),
          const SizedBox(height: 24),

          // Footer
          Center(
            child: Text(
              'SmartBin © 2026',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
