import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_service.dart';
import '../../../config.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/liquid_linear_progress_indicator.dart';
import '../../../widgets/smartbin_fill_icon.dart';

class MapViewScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const MapViewScreen({super.key, required this.user});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  List<dynamic> _bins = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  late MapController _mapController;
  LatLng? _userLocation;
  bool _locating = false;
  List<LatLng> _routePoints = const [];
  bool _routing = false;

  bool get _hasMapboxToken =>
      AppConfig.mapboxApiKey.isNotEmpty &&
      !AppConfig.mapboxApiKey.contains('YOUR_MAPBOX_KEY_HERE');

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadBins();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<bool> _checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.whileInUse ||
          result == LocationPermission.always;
    } else if (permission == LocationPermission.deniedForever) {
      await Geolocator.openLocationSettings();
      return false;
    }
    return true;
  }

  Future<void> _loadBins() async {
    setState(() => _isLoading = true);

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final assignedTo = widget.user['id'];
      final bins = await apiService.getBins(
        assignedTo:
            assignedTo is int ? assignedTo : int.tryParse('$assignedTo'),
      );
      setState(() {
        _bins = bins;
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

  List<dynamic> get _filteredBins {
    if (_filterStatus == 'all') return _bins;
    return _bins.where((bin) => bin['status'] == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
        actions: [
          if (_routePoints.isNotEmpty)
            IconButton(
              tooltip: 'Clear route',
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _routePoints = const []),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Bins')),
              const PopupMenuItem(
                  value: 'critical', child: Text('Critical Only')),
              const PopupMenuItem(
                  value: 'warning', child: Text('Warning Only')),
              const PopupMenuItem(value: 'normal', child: Text('Normal Only')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Map view with flutter_map
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _userLocation ??
                              (_filteredBins.isNotEmpty
                                  ? LatLng(
                                      _toDouble(_filteredBins
                                              .first['latitude']) ??
                                          0,
                                      _toDouble(_filteredBins
                                              .first['longitude']) ??
                                          0,
                                    )
                                  : const LatLng(0, 0)),
                          initialZoom: _userLocation != null ? 15 : 12,
                          minZoom: 5,
                          maxZoom: 18,
                        ),
                        children: [
                          if (_hasMapboxToken)
                            TileLayer(
                              urlTemplate:
                                  'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${AppConfig.mapboxApiKey}',
                              userAgentPackageName: 'smartbin_mobile',
                            )
                          else
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'smartbin_mobile',
                            ),
                          if (_routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  strokeWidth: 5,
                                  color: Colors.blue,
                                ),
                              ],
                            ),
                          // User location marker
                          if (_userLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _userLocation!,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    width: 20,
                                    height: 20,
                                    child: const Icon(
                                      Icons.near_me,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          // Bin markers
                          MarkerLayer(
                            markers: _buildBinMarkers(),
                          ),
                        ],
                      ),

                      // Legend
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Legend',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildLegendItem(Colors.red, 'Critical'),
                                _buildLegendItem(Colors.orange, 'Warning'),
                                _buildLegendItem(Colors.green, 'Normal'),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Center on user location button
                      Positioned(
                        bottom: 220,
                        right: 16,
                        child: FloatingActionButton(
                          mini: true,
                          onPressed: _centerOnUserLocation,
                          child: _locating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.my_location),
                        ),
                      ),
                      if (_routing)
                        const Positioned(
                          top: 72,
                          left: 16,
                          right: 16,
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Calculating route...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (!_hasMapboxToken)
                        const Positioned(
                          top: 16,
                          left: 16,
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'Mapbox token missing. Using OpenStreetMap tiles.',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Bottom sheet with bin list
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bins (${_filteredBins.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_filterStatus != 'all')
                              Chip(
                                label: Text(_filterStatus),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setState(() => _filterStatus = 'all');
                                },
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredBins.length,
                          itemBuilder: (context, index) {
                            return _buildBinCard(_filteredBins[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to first bin
          if (_filteredBins.isNotEmpty) {
            _navigateToBin(_filteredBins[0]);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No bins available')),
            );
          }
        },
        child: const Icon(Icons.navigation),
      ),
    );
  }

  Future<void> _centerOnUserLocation() async {
    if (_userLocation == null) {
      setState(() => _locating = true);
      await _getUserLocation();
      setState(() => _locating = false);
    }

    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15);
    }
  }

  // convert a dynamic value (num or String) into a double if possible
  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  List<Marker> _buildBinMarkers() {
    return _filteredBins
        .map((bin) {
          // latitude/longitude may be numbers or strings from API, so parse safely
          final latitude = _toDouble(bin['latitude']);
          final longitude = _toDouble(bin['longitude']);

          if (latitude == null || longitude == null) return null;

          final point = LatLng(latitude, longitude);
          final status = bin['status'] ?? 'normal';

          Color statusColor;
          IconData iconData;

          switch (status) {
            case 'critical':
              statusColor = Colors.red;
              iconData = Icons.warning;
              break;
            case 'warning':
              statusColor = Colors.orange;
              iconData = Icons.info;
              break;
            default:
              statusColor = Colors.green;
              iconData = Icons.check_circle;
          }

          return Marker(
            point: point,
            child: GestureDetector(
              onTap: () => _showBinDetails(bin),
              child: Container(
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                width: 40,
                height: 40,
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          );
        })
        .whereType<Marker>()
        .toList();
  }

  void _showBinDetails(Map<String, dynamic> bin) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bin['bin_code'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      bin['location'] ?? 'Unknown location',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: Text('${bin['fill_level'] ?? 0}%'),
                  backgroundColor:
                      _getStatusColor(bin['status']).withOpacity(0.2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToBin(bin);
                    },
                    child: const Text('Navigate'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // View full details
                    },
                    child: const Text('Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBin(Map<String, dynamic> bin) {
    final latitude = _toDouble(bin['latitude']);
    final longitude = _toDouble(bin['longitude']);

    if (latitude != null && longitude != null) {
      final point = LatLng(latitude, longitude);
      _mapController.move(point, 17);

      _buildRouteTo(point);
    }
  }

  Future<void> _buildRouteTo(LatLng destination) async {
    if (_userLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on location to build directions')),
        );
      }
      return;
    }

    final start = _userLocation!;

    // On Flutter Web, avoid calling the directions API directly and instead
    // open Google Maps in a new tab for a reliable routing experience.
    if (kIsWeb) {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${start.latitude},${start.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&travelmode=driving',
      );

      final launched = await launchUrl(
        uri,
        webOnlyWindowName: '_blank',
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open directions in browser'),
          ),
        );
      }
      return;
    }

    setState(() => _routing = true);
    try {
      final uri = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car'
        '?api_key=${AppConfig.openRouteServiceKey}'
        '&start=${start.longitude},${start.latitude}'
        '&end=${destination.longitude},${destination.latitude}',
      );

      final res = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      );

      if (res.statusCode != 200) {
        throw Exception(
            'Directions API failed (${res.statusCode}): ${res.body}');
      }

      final data = json.decode(res.body);
      final coords = (data['features']?[0]?['geometry']?['coordinates']
              as List<dynamic>?) ??
          const [];
      final points = coords
          .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList(growable: false);

      if (!mounted) return;
      if (points.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No route found')),
        );
        setState(() => _routePoints = const []);
        return;
      }

      setState(() => _routePoints = points);

      // Fit map to route bounds
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.fromLTRB(24, 120, 24, 260),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to load in-app route. Please try again later.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
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
      default:
        statusColor = Colors.green;
    }

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SmartBinFillIcon(
                  fillLevel: fillLevel,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bin['bin_code'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.headerText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bin['location'],
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.subText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${fillLevel.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LiquidLinearProgressIndicator(
              value: progress,
              color: statusColor,
              height: 10,
              backgroundColor: const Color(0xFFECEFF3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _navigateToBin(bin),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Navigate',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // View details
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Details',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
