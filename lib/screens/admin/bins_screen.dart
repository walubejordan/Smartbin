import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/bin_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

/// Admin bins management: [DataTable] on wide view, cards on narrow.
class AdminBinsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final void Function(double lat, double lng)? onShowBinOnMap;

  const AdminBinsScreen({
    super.key,
    required this.user,
    this.onShowBinOnMap,
  });

  @override
  State<AdminBinsScreen> createState() => AdminBinsScreenState();
}

class AdminBinsScreenState extends State<AdminBinsScreen> {
  static const double _wideBreakpoint = 900;

  List<BinModel> _bins = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    assert(
      widget.user['role']?.toString() == 'admin',
      'AdminBinsScreen is for admin users only',
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final raw = await api.getBins();
      if (!mounted) return;
      setState(() {
        _bins = BinModel.listFromDynamic(raw);
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

  List<BinModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _bins;
    return _bins.where((b) {
      final collector = (b.collectorName ?? '').toLowerCase();
      final zone = (b.zone ?? '').toLowerCase();
      return b.binCode.toLowerCase().contains(q) ||
          b.location.toLowerCase().contains(q) ||
          b.status.toLowerCase().contains(q) ||
          (b.name ?? '').toLowerCase().contains(q) ||
          collector.contains(q) ||
          zone.contains(q);
    }).toList();
  }

  Color _statusColor(BinModel b) {
    if (b.isCritical) return Colors.red.shade700;
    if (b.isWarning) return Colors.orange.shade800;
    return AppColors.primaryGreen;
  }

  Widget _statusBadge(BinModel b) {
    final c = _statusColor(b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        b.status,
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  int? _collectorIdFromEntry(dynamic c) {
    final m = c as Map<String, dynamic>;
    final v = m['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  /// Opens the add-bin flow (used from dashboard shortcuts).
  void openAddBinDialog() {
    _showBinDialog();
  }

  Future<void> _showBinDialog({BinModel? existing}) async {
    final isEdit = existing != null;
    final api = Provider.of<ApiService>(context, listen: false);
    List<dynamic> collectors = [];
    try {
      collectors = await api.getCollectors();
    } catch (_) {}

    if (!mounted) return;

    final validCollectorIds = collectors.map(_collectorIdFromEntry).whereType<int>().toSet();

    final codeCtrl = TextEditingController(text: existing?.binCode ?? '');
    final locCtrl = TextEditingController(text: existing?.location ?? '');
    final zoneCtrl = TextEditingController(text: existing?.zone ?? '');
    final latCtrl = TextEditingController(
      text: existing?.latitude?.toString() ?? '',
    );
    final lngCtrl = TextEditingController(
      text: existing?.longitude?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    var assignedTo = existing?.assignedTo;
    if (assignedTo != null && !validCollectorIds.contains(assignedTo)) {
      assignedTo = null;
    }

    final collectorItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Unassigned'),
      ),
    ];
    for (final c in collectors) {
      final id = _collectorIdFromEntry(c);
      if (id == null) continue;
      final m = Map<String, dynamic>.from(c as Map);
      collectorItems.add(
        DropdownMenuItem<int?>(
          value: id,
          child: Text(
            '${m['name'] ?? 'Collector'} · ${m['email'] ?? ''}',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit bin' : 'Add new bin'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bin code',
                          hintText: 'e.g. BIN-101',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: locCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Location name',
                          hintText: 'Street or area',
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: zoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Assigned zone',
                          hintText: 'e.g. Main Campus, Hostels',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        value: assignedTo,
                        decoration: const InputDecoration(
                          labelText: 'Assigned collector',
                        ),
                        items: collectorItems,
                        onChanged: collectors.isEmpty
                            ? null
                            : (v) => setDialogState(() => assignedTo = v),
                      ),
                      if (collectors.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'No collectors loaded. Save without assignment or try again later.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.subText,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: 'Optional',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: 'Optional',
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
      },
    );

    double? parseCoord(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }

    final code = codeCtrl.text.trim();
    final loc = locCtrl.text.trim();
    final zoneVal = zoneCtrl.text.trim();
    final lat = parseCoord(latCtrl.text);
    final lng = parseCoord(lngCtrl.text);
    final editId = existing?.id;
    final assignee = assignedTo;

    // Dispose after the dialog route has finished unmounting (sync dispose
    // after pop causes framework assertions with Form/TextField dependents).
    void disposeCtrls() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        codeCtrl.dispose();
        locCtrl.dispose();
        zoneCtrl.dispose();
        latCtrl.dispose();
        lngCtrl.dispose();
      });
    }

    disposeCtrls();

    if (saved != true || !mounted) return;

    try {
      if (isEdit && editId != null) {
        await api.updateBin(
          editId,
          binCode: code,
          location: loc,
          latitude: lat,
          longitude: lng,
          assignedTo: assignee,
          sendAssignedTo: true,
          sendZone: true,
          zone: zoneVal.isEmpty ? null : zoneVal,
        );
      } else {
        await api.createBin(
          binCode: code,
          location: loc,
          latitude: lat,
          longitude: lng,
          assignedTo: assignee,
          zone: zoneVal.isEmpty ? null : zoneVal,
        );
      }
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Bin updated' : 'Bin created'),
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

  Future<void> _confirmDelete(BinModel b) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete bin'),
        content: Text(
          'Remove ${b.binCode} at ${b.location}? This cannot be undone.',
        ),
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
      await api.deleteBin(b.id);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bin deleted'),
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

  Widget _searchAndAddRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search code, location, zone, status, collector…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () => _showBinDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add bin'),
        ),
      ],
    );
  }

  Widget _buildWideTable() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filtered.isEmpty) {
      return const Center(
        child: Text(
          'No bins match your search.',
          style: TextStyle(color: AppColors.subText),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 48,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 72,
                columns: const [
                  DataColumn(label: Text('Bin code')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Zone')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Fill level')),
                  DataColumn(label: Text('Collector')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final b in _filtered)
                    DataRow(
                      cells: [
                        DataCell(Text(b.binCode)),
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              b.location,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 120,
                            child: Text(
                              b.zone ?? '—',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_statusBadge(b)),
                        DataCell(Text('${b.fillLevel.toStringAsFixed(0)}%')),
                        DataCell(Text(b.collectorName ?? '—')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onShowBinOnMap != null &&
                                  b.latitude != null &&
                                  b.longitude != null)
                                IconButton(
                                  tooltip: 'Map',
                                  icon: const Icon(Icons.map_outlined),
                                  onPressed: () => widget.onShowBinOnMap!(
                                    b.latitude!,
                                    b.longitude!,
                                  ),
                                ),
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _showBinDialog(existing: b),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade700,
                                ),
                                onPressed: () => _confirmDelete(b),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mobileBinCard(BinModel b) {
    final fill = b.fillLevel / 100.0;
    final statusColor = _statusColor(b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.binCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _statusBadge(b),
                    ],
                  ),
                ),
                if (widget.onShowBinOnMap != null &&
                    b.latitude != null &&
                    b.longitude != null)
                  IconButton(
                    tooltip: 'Map',
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () => widget.onShowBinOnMap!(
                      b.latitude!,
                      b.longitude!,
                    ),
                  ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showBinDialog(existing: b),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade700,
                  ),
                  onPressed: () => _confirmDelete(b),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              b.location,
              style: const TextStyle(
                color: AppColors.subText,
                fontSize: 13,
              ),
            ),
            if (b.zone != null && b.zone!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Zone: ${b.zone}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (b.collectorName != null && b.collectorName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Collector: ${b.collectorName}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fill.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${b.fillLevel.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;

        if (wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _searchAndAddRow(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: LayoutBuilder(
                    builder: (context, inner) {
                      return RefreshIndicator(
                        onRefresh: _load,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: inner.maxHeight,
                            ),
                            child: _buildWideTable(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        }

        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _searchAndAddRow(),
                  const SizedBox(height: 12),
                  if (_error != null) ...[
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_loading)
                    const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No bins match your search.',
                          style: TextStyle(color: AppColors.subText),
                        ),
                      ),
                    )
                  else
                    ..._filtered.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _mobileBinCard(b),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
