import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/api_service.dart';

class CreateBinScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CreateBinScreen({super.key, required this.user});

  @override
  State<CreateBinScreen> createState() => _CreateBinScreenState();
}

class _CreateBinScreenState extends State<CreateBinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _binCodeController = TextEditingController();
  final _locationController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _capacityController = TextEditingController(text: '100');

  List<dynamic> _collectors = [];
  int? _selectedCollectorId;
  bool _isLoading = false;
  bool _isLoadingCollectors = true;

  @override
  void initState() {
    super.initState();
    _loadCollectors();
  }

  @override
  void dispose() {
    _binCodeController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadCollectors() async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final collectors = await apiService.getCollectors();
      setState(() {
        _collectors = collectors;
        _isLoadingCollectors = false;
      });
    } catch (e) {
      setState(() => _isLoadingCollectors = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading collectors: $e')),
        );
      }
    }
  }

  Future<void> _createBin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      await apiService.createBin(
        binCode: _binCodeController.text.trim(),
        location: _locationController.text.trim(),
        latitude: _latitudeController.text.isNotEmpty
            ? double.tryParse(_latitudeController.text)
            : null,
        longitude: _longitudeController.text.isNotEmpty
            ? double.tryParse(_longitudeController.text)
            : null,
        capacity: int.tryParse(_capacityController.text) ?? 100,
        assignedTo: _selectedCollectorId,
      );

      if (!mounted) return;

      // Logic change: Instead of Navigator.pop (which would close the app/dashboard),
      // we show a success message. You can also add a callback to switch the index back to 0.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bin created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear fields after success
      _binCodeController.clear();
      _locationController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      setState(() {
        _isLoading = false;
        _selectedCollectorId = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Removed Scaffold and AppBar because they are provided by AdminDashboard
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Create New Waste Bin',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
          ),
          const SizedBox(height: 20),

          // Bin Code
          TextFormField(
            controller: _binCodeController,
            decoration: InputDecoration(
              labelText: 'Bin Code *',
              hintText: 'e.g., BIN001',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter bin code';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Location
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(
              labelText: 'Location *',
              hintText: 'e.g., Main Street Plaza, Kampala',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter location';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // GPS Coordinates Section
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.my_location, size: 20, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'GPS Coordinates (Optional)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latitudeController,
                          decoration: InputDecoration(
                            labelText: 'Latitude',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _longitudeController,
                          decoration: InputDecoration(
                            labelText: 'Longitude',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Capacity
          TextFormField(
            controller: _capacityController,
            decoration: InputDecoration(
              labelText: 'Capacity (Liters)',
              prefixIcon: const Icon(Icons.inventory_2_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Please enter capacity';
              final capacity = int.tryParse(value);
              if (capacity == null || capacity <= 0)
                return 'Enter valid capacity';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Assign to Collector
          _isLoadingCollectors
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<int?>(
                  initialValue: _selectedCollectorId,
                  decoration: InputDecoration(
                    labelText: 'Assign to Collector (Optional)',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ..._collectors.map((collector) {
                      return DropdownMenuItem<int>(
                        value: collector['id'],
                        child: Text(collector['name']),
                      );
                    }),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedCollectorId = value),
                ),
          const SizedBox(height: 32),

          // Submit Button
          SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createBin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('CREATE BIN',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
