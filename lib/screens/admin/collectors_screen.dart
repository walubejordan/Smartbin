import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

/// Admin: manage collectors (users with role collector).
class CollectorsScreen extends StatefulWidget {
  const CollectorsScreen({super.key});

  @override
  State<CollectorsScreen> createState() => _CollectorsScreenState();
}

class _CollectorsScreenState extends State<CollectorsScreen> {
  final _search = TextEditingController();
  List<dynamic> _collectors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final list = await api.getUsers(role: 'collector');
      if (!mounted) return;
      setState(() {
        _collectors = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<dynamic> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _collectors;
    return _collectors.where((c) {
      final m = c as Map<String, dynamic>;
      final name = '${m['name'] ?? ''}'.toLowerCase();
      final email = '${m['email'] ?? ''}'.toLowerCase();
      final zone = '${m['zone'] ?? ''}'.toLowerCase();
      final phone = '${m['phone'] ?? ''}'.toLowerCase();
      return name.contains(q) ||
          email.contains(q) ||
          zone.contains(q) ||
          phone.contains(q);
    }).toList();
  }

  String _zoneLabel(Map<String, dynamic> c) {
    final z = c['zone']?.toString().trim();
    if (z != null && z.isNotEmpty) return 'Zone: $z';
    return 'No zone assigned';
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final zoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add collector'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Full name',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'name@example.com',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: zoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Assigned zone',
                      hintText: 'e.g. Main Campus, Hostels, Retail',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                      hintText: 'Min 6 characters',
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'At least 6 characters';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    void disposeCtrls() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        emailCtrl.dispose();
        zoneCtrl.dispose();
        passCtrl.dispose();
      });
    }

    if (ok != true) {
      disposeCtrls();
      return;
    }

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final zone = zoneCtrl.text.trim();
    final password = passCtrl.text;
    disposeCtrls();

    if (!mounted) return;

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.createUser(
        name: name,
        email: email,
        password: password,
        zone: zone.isEmpty ? null : zone,
        role: 'collector',
      );
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Collector created'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _load();
      });
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      });
    }
  }

  int _userId(Map<String, dynamic> c) {
    final v = c['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  Future<void> _showEditDialog(Map<String, dynamic> c) async {
    final id = _userId(c);
    if (id == 0) return;
    final nameCtrl = TextEditingController(text: '${c['name'] ?? ''}');
    final emailCtrl = TextEditingController(text: '${c['email'] ?? ''}');
    final zoneCtrl = TextEditingController(
      text: '${c['zone'] ?? c['phone'] ?? ''}',
    );
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit collector'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: zoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Assigned zone',
                      hintText: 'e.g. Main Campus, Hostels, Retail',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    void disposeCtrls() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        emailCtrl.dispose();
        zoneCtrl.dispose();
      });
    }

    if (ok != true) {
      disposeCtrls();
      return;
    }

    final newName = nameCtrl.text.trim();
    final newEmail = emailCtrl.text.trim();
    final newZone = zoneCtrl.text.trim();
    disposeCtrls();

    if (!mounted) return;

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.updateUser(
        id,
        name: newName,
        email: newEmail,
        setZone: true,
        zone: newZone.isEmpty ? null : newZone,
      );
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Collector updated'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _load();
      });
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      });
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final id = _userId(c);
    if (id == 0) return;
    final name = '${c['name'] ?? 'Collector'}';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete collector'),
        content: Text('Remove $name? Assigned bins may need reassignment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.deleteUser(id);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Collector removed'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        _load();
      });
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            hintText: 'Search collectors…',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Add collector'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No collectors found.',
                        style: TextStyle(color: AppColors.subText),
                      ),
                    )
                  else
                    ..._filtered.map((raw) {
                      final c = raw as Map<String, dynamic>;
                      final name = '${c['name'] ?? '—'}';
                      final email = '${c['email'] ?? ''}';
                      final status = '${c['status'] ?? 'active'}';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(name),
                          subtitle: Text(
                            '$email\n${_zoneLabel(c)}',
                            style: const TextStyle(height: 1.35),
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _showEditDialog(c),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade700,
                                ),
                                onPressed: () => _confirmDelete(c),
                              ),
                            ],
                          ),
                          leading: CircleAvatar(
                            backgroundColor: status == 'active'
                                ? AppColors.primaryGreen.withOpacity(0.2)
                                : Colors.grey.shade300,
                            child: Icon(
                              Icons.person,
                              color: status == 'active'
                                  ? AppColors.primaryGreen
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
