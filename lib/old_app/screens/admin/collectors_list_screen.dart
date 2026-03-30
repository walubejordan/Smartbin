import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';
import 'create_user_screen.dart';
import 'user_detail_screen.dart';

class CollectorsListScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const CollectorsListScreen({super.key, required this.user});

  @override
  State<CollectorsListScreen> createState() => _CollectorsListScreenState();
}

class _CollectorsListScreenState extends State<CollectorsListScreen> {
  List<dynamic> _collectors = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadCollectors();
  }

  Future<void> _loadCollectors() async {
    setState(() => _isLoading = true);
    
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    try {
      final collectors = await apiService.getUsers(
        role: 'collector',
        status: _statusFilter,
      );
      setState(() {
        _collectors = collectors;
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

  List<dynamic> get _filteredCollectors {
    if (_searchQuery.isEmpty) return _collectors;
    
    return _collectors.where((collector) {
      return collector['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          collector['email']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collectors'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _statusFilter = value == 'all' ? null : value);
              _loadCollectors();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Status')),
              const PopupMenuItem(value: 'active', child: Text('Active Only')),
              const PopupMenuItem(value: 'inactive', child: Text('Inactive Only')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search collectors...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Collectors list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCollectors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No collectors found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCollectors,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredCollectors.length,
                          itemBuilder: (context, index) {
                            return _buildCollectorCard(_filteredCollectors[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Wrap CreateUserScreen in its own Scaffold so form fields are always
          // under a Material ancestor when pushed as a route from the list.
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('Create New User'),
                ),
                body: CreateUserScreen(user: widget.user),
              ),
            ),
          );
          if (result == true) {
            _loadCollectors();
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Collector'),
      ),
    );
  }

  Widget _buildCollectorCard(Map<String, dynamic> collector) {
    final isActive = collector['status'] == 'active';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailScreen(userId: collector['id']),
            ),
          );
          if (result == true) {
            _loadCollectors();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isActive 
                        ? Colors.green.withOpacity(0.2) 
                        : Colors.grey.withOpacity(0.2),
                    child: Text(
                      collector['name']
                          .toString()
                          .split(' ')
                          .map((n) => n[0])
                          .take(2)
                          .join()
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                collector['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isActive 
                                    ? Colors.green.withOpacity(0.1) 
                                    : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                collector['email'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Stats
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.delete_outline,
                      'Assigned',
                      collector['assigned_bins'].toString(),
                      Colors.blue,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    _buildStatItem(
                      Icons.check_circle_outline,
                      'Collected',
                      collector['total_collections'].toString(),
                      Colors.green,
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

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}