import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';

class CollectionHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const CollectionHistoryScreen({super.key, required this.user});

  @override
  State<CollectionHistoryScreen> createState() => _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends State<CollectionHistoryScreen> {
  List<dynamic> _collections = [];
  bool _isLoading = true;
  String _selectedPeriod = 'all'; // all, today, week, month

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    try {
      final profile = await apiService.getProfile();
      final userId = profile['id'] as int;
      final collections = await apiService.getUserCollections(userId);
      
      setState(() {
        _collections = collections;
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

  List<dynamic> get _filteredCollections {
    final now = DateTime.now();
    
    return _collections.where((collection) {
      if (_selectedPeriod == 'all') return true;
      
      try {
        final date = DateTime.parse(collection['collection_time']);
        
        switch (_selectedPeriod) {
          case 'today':
            return date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          case 'week':
            final weekAgo = now.subtract(const Duration(days: 7));
            return date.isAfter(weekAgo);
          case 'month':
            return date.year == now.year && date.month == now.month;
          default:
            return true;
        }
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Map<String, List<dynamic>> get _groupedCollections {
    final Map<String, List<dynamic>> grouped = {};
    
    for (var collection in _filteredCollections) {
      try {
        final date = DateTime.parse(collection['collection_time']);
        final key = '${date.day}/${date.month}/${date.year}';
        
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(collection);
      } catch (e) {
        // Skip invalid dates
      }
    }
    
    return grouped;
  }

  int get _totalCollections => _filteredCollections.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection History'),
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            color: Colors.grey.shade100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Today', 'today'),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Week', 'week'),
                  const SizedBox(width: 8),
                  _buildFilterChip('This Month', 'month'),
                ],
              ),
            ),
          ),

          // Stats card
          if (!_isLoading)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _totalCollections.toString(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _selectedPeriod == 'all'
                            ? 'Total Collections'
                            : 'Collections',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Collections list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCollections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No collections found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try changing the filter',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _groupedCollections.length,
                          itemBuilder: (context, index) {
                            final date = _groupedCollections.keys.elementAt(index);
                            final collections = _groupedCollections[date]!;
                            
                            return _buildDateGroup(date, collections);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedPeriod = value);
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.green.shade100,
      checkmarkColor: Colors.green,
    );
  }

  Widget _buildDateGroup(String date, List<dynamic> collections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${collections.length})',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        ...collections.map((collection) => _buildCollectionCard(collection)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCollectionCard(Map<String, dynamic> collection) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection['bin_code'] ?? 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    collection['location'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(collection['collection_time']),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (collection['fill_level_before'] != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${collection['fill_level_before']}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}