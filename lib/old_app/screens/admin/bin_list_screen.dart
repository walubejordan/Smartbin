import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/liquid_linear_progress_indicator.dart';
import '../../../widgets/smartbin_fill_icon.dart';
import 'bin_details_screen.dart';

class BinListScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const BinListScreen({super.key, required this.user});

  @override
  State<BinListScreen> createState() => _BinsListScreenState();
}

class _BinsListScreenState extends State<BinListScreen> {
  List<dynamic> _bins = [];
  List<dynamic> _filteredBins = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadBins();
  }

  List<dynamic> _filterBins(List<dynamic> bins) {
    final q = _searchQuery.toLowerCase();
    return bins.where((bin) {
      final binCode = (bin['bin_code'] ?? '').toString().toLowerCase();
      final name = (bin['name'] ?? '').toString().toLowerCase();
      final location = (bin['location'] ?? '').toString().toLowerCase();

      final matchesSearch =
          binCode.contains(q) || name.contains(q) || location.contains(q);
      final binStatus = _getStatusLabel(bin);
      final matchesStatus = _statusFilter == null ||
          binStatus.toLowerCase() == _statusFilter!.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> _loadBins() async {
    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      var bins = await apiService.getBins(status: _statusFilter);
      print(
          'DEBUG bin_list_screen: API returned ${bins.length} bins, statusFilter=$_statusFilter');
      if (bins.isEmpty) {
        // Fallback test data for empty response during local development
        bins = [
          {
            'id': 1001,
            'bin_code': 'BIN-101',
            'name': 'Main Entrance',
            'location': 'Main Entrance',
            'fill_level': 42,
            'status': 'Half Full',
            'assigned_to': null,
            'collector_name': 'Unassigned',
            'last_collection': null,
          },
          {
            'id': 1002,
            'bin_code': 'BIN-102',
            'name': 'Warehouse',
            'location': 'Warehouse',
            'fill_level': 83,
            'status': 'Full',
            'assigned_to': null,
            'collector_name': 'Unassigned',
            'last_collection': null,
          },
        ];
      }

      setState(() {
        _bins = bins;
        _filteredBins = _filterBins(bins);
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

  void _applyFilters() {
    setState(() => _filteredBins = _filterBins(_bins));
  }

  List<DataRow> _buildDataRows() {
    if (_filteredBins.isEmpty) {
      return [
        DataRow(cells: [
          const DataCell(
              Text('No bins found', style: TextStyle(color: Colors.grey))),
          DataCell.empty,
          DataCell.empty,
          DataCell.empty,
          DataCell.empty,
        ]),
      ];
    }

    return _filteredBins.map((bin) {
      final statusLabel = _getStatusLabel(bin);
      final statusColor = _getStatusColor(bin);
      final fillLevel = (bin['fill_level'] ?? 0).toDouble().clamp(0, 100);

      return DataRow(
          onSelectChanged: (selected) {
            if (selected ?? false) {
              _openBinDetails(bin);
            }
          },
          cells: [
            DataCell(Text(bin['bin_code']?.toString() ?? '—')),
            DataCell(Text(bin['location']?.toString() ?? '—')),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )),
            DataCell(SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: fillLevel / 100,
                    color: statusColor,
                    backgroundColor: Colors.grey.shade200,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 4),
                  Text('${fillLevel.toStringAsFixed(0)}%'),
                ],
              ),
            )),
            DataCell(Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  color: AppColors.primaryGreen,
                  tooltip: 'Edit',
                  onPressed: () => _editBin(bin),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  color: Colors.redAccent,
                  tooltip: 'Delete',
                  onPressed: () => _deleteBin(bin),
                ),
              ],
            )),
          ]);
    }).toList();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Bins'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Status'),
              leading: Radio<String?>(
                value: null,
                groupValue: _statusFilter,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _statusFilter = value;
                    _applyFilters();
                  });
                },
              ),
            ),
            ListTile(
              title: const Text('Full'),
              leading: Radio<String?>(
                value: 'Full',
                groupValue: _statusFilter,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _statusFilter = value;
                    _applyFilters();
                  });
                },
              ),
            ),
            ListTile(
              title: const Text('Half Full'),
              leading: Radio<String?>(
                value: 'Half Full',
                groupValue: _statusFilter,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _statusFilter = value;
                    _applyFilters();
                  });
                },
              ),
            ),
            ListTile(
              title: const Text('Empty'),
              leading: Radio<String?>(
                value: 'Empty',
                groupValue: _statusFilter,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _statusFilter = value;
                    _applyFilters();
                  });
                },
              ),
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
        final contentWidth = constraints.maxWidth;
        final contentHeight = constraints.maxHeight;

        final searchWidth =
            (contentWidth > 1000 ? contentWidth * 0.45 : contentWidth * 0.55)
                .clamp(280.0, 520.0);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: searchWidth,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search bins...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Colors.transparent),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.primaryGreen),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                              _applyFilters();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _statusFilter != null
                                ? Icons.filter_alt
                                : Icons.filter_alt_outlined,
                            color: AppColors.primaryGreen,
                          ),
                          onPressed: _showFilterDialog,
                          tooltip: 'Filter bins',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddBinDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Bin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      minimumSize: const Size(160, 45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_statusFilter != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12, left: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text('Status: $_statusFilter'),
                        onDeleted: () {
                          setState(() => _statusFilter = null);
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'DEBUG: loaded ${_bins.length} bins, filtered ${_filteredBins.length}, loading=$_isLoading',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Expanded(
                      child: Container(
                        color: Colors.blue.shade50,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'DEBUG: showing ${_filteredBins.length} rows',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _loadBins,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Container(
                                    width: double.infinity,
                                    constraints:
                                        const BoxConstraints(minHeight: 280),
                                    child: Card(
                                      color: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: _filteredBins.isEmpty
                                          ? const SizedBox(
                                              height: 150,
                                              child: Center(
                                                child: Text('No bins found'),
                                              ),
                                            )
                                          : DataTable(
                                              columnSpacing: 56.0,
                                              columns: const [
                                                DataColumn(
                                                  label: Text(
                                                    'Bin Name',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: Text(
                                                    'Location',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: Text(
                                                    'Status',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: Text(
                                                    'Fill %',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: Text(
                                                    'Actions',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              rows: _buildDataRows(),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusLabel(Map<String, dynamic> bin) {
    final fill = (bin['fill_level'] ?? 0).toDouble();
    if (fill >= 80) return 'Full';
    if (fill >= 40) return 'Half Full';
    return 'Empty';
  }

  Color _getStatusColor(Map<String, dynamic> bin) {
    final fill = (bin['fill_level'] ?? 0).toDouble();
    if (fill >= 80) return Colors.red;
    if (fill >= 40) return Colors.amber.shade700;
    return Colors.green;
  }

  Future<void> _openBinDetails(Map<String, dynamic> bin) async {
    final changed = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => BinDetailScreen(
            binId: bin['id'] is int
                ? bin['id']
                : int.tryParse(bin['id'].toString()) ?? 0),
      ),
    );
    if (changed == true) {
      _loadBins();
    }
  }

  Future<void> _showEditBinDialog(Map<String, dynamic> bin) async {
    final binCodeController =
        TextEditingController(text: bin['bin_code']?.toString() ?? '');
    final locationController =
        TextEditingController(text: bin['location']?.toString() ?? '');
    final fillLevelController =
        TextEditingController(text: (bin['fill_level'] ?? 0).toString());

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Bin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: binCodeController,
                  decoration: const InputDecoration(labelText: 'Bin Code'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fillLevelController,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Fill Level (%)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedBinCode = binCodeController.text.trim();
                final updatedLocation = locationController.text.trim();
                final updatedFillLevel =
                    double.tryParse(fillLevelController.text.trim())
                            ?.clamp(0, 100) ??
                        0;
                if (updatedBinCode.isEmpty || updatedLocation.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Bin code and location must not be empty')),
                  );
                  return;
                }
                try {
                  final service =
                      Provider.of<ApiService>(context, listen: false);
                  await service.updateBin(
                    bin['id'] is int
                        ? bin['id']
                        : int.tryParse(bin['id'].toString()) ?? 0,
                    binCode: updatedBinCode,
                    location: updatedLocation,
                    status: _getStatusLabel({'fill_level': updatedFillLevel}),
                  );
                  setState(() {
                    final index = _bins.indexWhere((b) => b['id'] == bin['id']);
                    if (index != -1) {
                      _bins[index] = {
                        ..._bins[index],
                        'bin_code': updatedBinCode,
                        'location': updatedLocation,
                        'fill_level': updatedFillLevel,
                      };
                    }
                    _filteredBins = _filterBins(_bins);
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bin updated successfully')),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Update failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _editBin(Map<String, dynamic> bin) {
    _showEditBinDialog(bin);
  }

  void _deleteBin(Map<String, dynamic> bin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bin'),
        content: const Text('Do you want to delete this bin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                _bins.remove(bin);
                _filteredBins = _filterBins(_bins);
              });
              Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBinDialog() async {
    final TextEditingController idController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController locationController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Bin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(labelText: 'Bin ID'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final id = idController.text.trim();
                final name = nameController.text.trim();
                final location = locationController.text.trim();

                if (id.isEmpty || name.isEmpty || location.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields.')),
                  );
                  return;
                }

                final newBin = {
                  'id': DateTime.now().millisecondsSinceEpoch,
                  'bin_code': id,
                  'name': name,
                  'location': location,
                  'fill_level': 0,
                  'status': 'normal',
                  'collector_name': 'Unassigned',
                  'last_collection': null,
                };

                setState(() {
                  _bins.insert(0, newBin);
                  _filteredBins = _filterBins(_bins);
                });

                Navigator.of(context).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBinCard(Map<String, dynamic> bin) {
    final fillLevel = (bin['fill_level'] ?? 0).toDouble();
    final progress = (fillLevel / 100).clamp(0.0, 1.0);
    final status = bin['status'] ?? 'normal';

    Color statusColor;

    switch (status) {
      case 'critical':
        statusColor = Colors.red;
        break;
      case 'warning':
        statusColor = Colors.orange;
        break;
      case 'offline':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BinDetailScreen(binId: bin['id']),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SmartBinFillIcon(
                        fillLevel: fillLevel,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  bin['bin_code'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.headerText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bin['location'],
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.subText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${fillLevel.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                    children: [
                      FaIcon(
                        FontAwesomeIcons.user,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bin['collector_name'] ?? 'Unassigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bin['last_collection'] != null) ...[
                        const SizedBox(width: 12),
                        FaIcon(
                          FontAwesomeIcons.clock,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Last: ${_formatDate(bin['last_collection'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Never';

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inMinutes}m ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
