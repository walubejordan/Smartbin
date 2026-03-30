import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/liquid_linear_progress_indicator.dart';

class BinDetailScreen extends StatefulWidget {
  final int binId;

  const BinDetailScreen({super.key, required this.binId});

  @override
  State<BinDetailScreen> createState() => _BinDetailScreenState();
}

class _BinDetailScreenState extends State<BinDetailScreen> {
  Map<String, dynamic>? _bin;
  List<dynamic> _history = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  List<dynamic> _collectors = [];
  bool _isLoadingCollectors = false;
  int? _selectedCollectorId;
  bool _inlineSaving = false;

  @override
  void initState() {
    super.initState();
    _loadBinDetails();
  }

  Future<void> _loadBinDetails() async {
    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final bin = await apiService.getBin(widget.binId);
      final history = await apiService.getBinHistory(widget.binId);

      setState(() {
        _bin = bin;
        _history = history;
        _selectedCollectorId = bin['assigned_to'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadCollectors() async {
    setState(() {
      _isLoadingCollectors = true;
    });

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final collectors = await apiService.getCollectors();
      setState(() {
        _collectors = collectors;
        _isLoadingCollectors = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCollectors = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading collectors: $e')),
        );
      }
    }
  }

  Future<void> _deleteBin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bin'),
        content: Text('Are you sure you want to delete ${_bin!['bin_code']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      await apiService.deleteBin(widget.binId);

      if (!mounted) return;

      Navigator.pop(context, true); // Return true to indicate deletion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bin deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showQuickTextEdit({
    required String title,
    required String initialValue,
    required Future<void> Function(String value) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _inlineSaving
                      ? null
                      : () async {
                          setState(() => _inlineSaving = true);
                          try {
                            await onSave(controller.text.trim());
                            if (!mounted) return;
                            Navigator.pop(context);
                            await _loadBinDetails();
                          } finally {
                            if (mounted) setState(() => _inlineSaving = false);
                          }
                        },
                  child: Text(_inlineSaving ? 'Saving...' : 'Save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showQuickCollectorEdit() async {
    if (_collectors.isEmpty) {
      await _loadCollectors();
    }
    if (!mounted) return;
    int? localValue = _selectedCollectorId;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assign Collector',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: localValue,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _collectors.map((collector) {
                return DropdownMenuItem<int>(
                  value: collector['id'] as int,
                  child: Text(collector['name'] as String),
                );
              }).toList(),
              onChanged: (value) => localValue = value,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final apiService =
                      Provider.of<ApiService>(context, listen: false);
                  await apiService.updateBin(widget.binId,
                      assignedTo: localValue);
                  if (!mounted) return;
                  setState(() => _selectedCollectorId = localValue);
                  Navigator.pop(context);
                  await _loadBinDetails();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bin Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_bin == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bin Details')),
        body: const Center(child: Text('Bin not found')),
      );
    }

    final fillLevel = _bin!['fill_level'] ?? 0;
    final status = _bin!['status'] ?? 'normal';
    final double progress =
        (((fillLevel as num).toDouble()) / 100).clamp(0.0, 1.0);

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'critical':
        statusColor = Colors.red;
        statusIcon = FontAwesomeIcons.triangleExclamation;
        break;
      case 'warning':
        statusColor = Colors.orange;
        statusIcon = FontAwesomeIcons.circleInfo;
        break;
      case 'offline':
        statusColor = Colors.grey;
        statusIcon = FontAwesomeIcons.cloud;
        break;
      default:
        statusColor = Colors.green;
        statusIcon = FontAwesomeIcons.circleCheck;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_bin!['bin_code']),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              if (_bin == null) return;
              final apiService =
                  Provider.of<ApiService>(context, listen: false);

              // Controllers for existing editable fields
              final locationController = TextEditingController(
                  text: _bin!['location']?.toString() ?? '');
              final capacityController = TextEditingController(
                  text: (_bin!['capacity'] ?? 100).toString());
              final latitudeController = TextEditingController(
                  text: _bin!['latitude'] != null
                      ? _bin!['latitude'].toString()
                      : '');
              final longitudeController = TextEditingController(
                  text: _bin!['longitude'] != null
                      ? _bin!['longitude'].toString()
                      : '');

              // Load collectors for the dropdown
              await _loadCollectors();

              await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Edit Bin'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: capacityController,
                          decoration: const InputDecoration(
                            labelText: 'Capacity (L)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: latitudeController,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: longitudeController,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                        ),
                        const SizedBox(height: 12),
                        _isLoadingCollectors
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButtonFormField<int>(
                                initialValue: _selectedCollectorId,
                                decoration: const InputDecoration(
                                  labelText: 'Assign Collector',
                                  border: OutlineInputBorder(),
                                ),
                                items: _collectors.map((collector) {
                                  return DropdownMenuItem<int>(
                                    value: collector['id'] as int,
                                    child: Text(collector['name'] as String),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCollectorId = value;
                                  });
                                },
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
                      onPressed: () async {
                        try {
                          final loc = locationController.text.trim();
                          final cap =
                              int.tryParse(capacityController.text.trim());
                          final lat = latitudeController.text.trim().isNotEmpty
                              ? double.tryParse(latitudeController.text.trim())
                              : null;
                          final lng = longitudeController.text.trim().isNotEmpty
                              ? double.tryParse(longitudeController.text.trim())
                              : null;

                          await apiService.updateBin(
                            widget.binId,
                            location: loc.isNotEmpty ? loc : null,
                            capacity: cap,
                            latitude: lat,
                            longitude: lng,
                            assignedTo: _selectedCollectorId,
                          );

                          if (!mounted) return;
                          Navigator.pop(context, true);
                          await _loadBinDetails();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bin updated successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Bin', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                _deleteBin();
              }
            },
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBinDetails,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fill Level',
                                    style: TextStyle(
                                      color: AppColors.subText,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(progress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: FaIcon(
                                  statusIcon,
                                  size: 48,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LiquidLinearProgressIndicator(
                            value: progress,
                            color: statusColor,
                            height: 12,
                            backgroundColor: const Color(0xFFECEFF3),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Information
                    const Text(
                      'Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            FontAwesomeIcons.qrcode,
                            'Bin Code',
                            _bin!['bin_code'],
                            onTap: () => _showQuickTextEdit(
                              title: 'Edit Bin Name',
                              initialValue: _bin!['bin_code']?.toString() ?? '',
                              onSave: (value) async {
                                if (value.isEmpty) return;
                                final apiService = Provider.of<ApiService>(
                                    context,
                                    listen: false);
                                await apiService.updateBin(
                                  widget.binId,
                                  binCode: value,
                                );
                              },
                            ),
                          ),
                          const Divider(height: 1),
                          _buildInfoRow(
                            FontAwesomeIcons.locationDot,
                            'Location',
                            _bin!['location'],
                            onTap: () => _showQuickTextEdit(
                              title: 'Edit Location',
                              initialValue: _bin!['location']?.toString() ?? '',
                              onSave: (value) async {
                                if (value.isEmpty) return;
                                final apiService = Provider.of<ApiService>(
                                    context,
                                    listen: false);
                                await apiService.updateBin(
                                  widget.binId,
                                  location: value,
                                );
                              },
                            ),
                          ),
                          const Divider(height: 1),
                          _buildInfoRow(
                            FontAwesomeIcons.user,
                            'Assigned To',
                            _bin!['collector_name'] ?? 'Unassigned',
                            onTap: _showQuickCollectorEdit,
                          ),
                          const Divider(height: 1),
                          _buildInfoRow(
                            FontAwesomeIcons.waterLadder,
                            'Capacity',
                            '${_bin!['capacity'] ?? 100}L',
                          ),
                          if (_bin!['last_collection'] != null) ...[
                            const Divider(height: 1),
                            _buildInfoRow(
                              FontAwesomeIcons.clock,
                              'Last Collection',
                              _formatDateTime(_bin!['last_collection']),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Location Map
                    if (_bin!['latitude'] != null &&
                        _bin!['longitude'] != null) ...[
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 48,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Map View',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lat: ${_bin!['latitude']}, Lng: ${_bin!['longitude']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Collection History
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Collection History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // View all history
                          },
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_history.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No collection history',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _history.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final collection = _history[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                              ),
                              title: Text(
                                  collection['collector_name'] ?? 'Unknown'),
                              subtitle: Text(
                                _formatDateTime(collection['collection_time']),
                              ),
                              trailing: Text(
                                '${collection['fill_level_before']}% → ${collection['fill_level_after']}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final isEditable = onTap != null;
    return Container(
      color: isEditable ? Colors.transparent : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          highlightColor:
              isEditable ? Colors.grey.shade100 : Colors.transparent,
          splashColor: isEditable ? Colors.grey.shade200 : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FaIcon(
                  icon,
                  color: Colors.grey.shade700,
                  size: 16,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.subText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.headerText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isEditable)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return 'Unknown';

    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
