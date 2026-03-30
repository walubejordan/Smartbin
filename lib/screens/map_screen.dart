import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/bin_model.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Live bin map: markers from [ApiService.getBins], 30s polling, [zoomToBin] for deep links.
class MapScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  /// Called after a successful collection (refresh sibling screens, e.g. bins list).
  final VoidCallback? onCollectionComplete;

  const MapScreen({
    super.key,
    required this.user,
    this.onCollectionComplete,
  });

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  List<BinModel> _bins = [];
  bool _loading = true;
  String _filter = 'all';
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  BinModel? _selectedBin;
  bool _didInitialCamera = false;
  int? _collectingBinId;

  Timer? _pollTimer;

  static const LatLng _defaultRegion = LatLng(0.3476, 32.5825);
  static const Duration _pollInterval = Duration(seconds: 30);

  bool get _hasMapbox =>
      AppConfig.mapboxApiKey.isNotEmpty &&
      !AppConfig.mapboxApiKey.contains('YOUR_MAPBOX_KEY_HERE');

  @override
  void initState() {
    super.initState();
    _loadBins(silent: false);
    _locate();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted) _loadBins(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  int? get _userId {
    final v = widget.user['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  bool get _isCollector =>
      widget.user['role']?.toString().toLowerCase() == 'collector';

  bool _canConfirmCollection(BinModel b) {
    if (!_isCollector) return false;
    final uid = _userId;
    if (uid == null || b.assignedTo != uid) return false;
    return b.fillLevel > 0;
  }

  /// Reload markers (e.g. after a collection from the bins list).
  Future<void> refreshBinData() async {
    await _loadBins(silent: true);
    if (!mounted) return;
    if (_selectedBin != null) {
      final id = _selectedBin!.id;
      BinModel? next;
      for (final b in _bins) {
        if (b.id == id) {
          next = b;
          break;
        }
      }
      setState(() => _selectedBin = next);
    }
  }

  Future<void> _confirmCollect(BinModel b) async {
    final api = Provider.of<ApiService>(context, listen: false);
    setState(() => _collectingBinId = b.id);
    try {
      await api.collectBin(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bin Emptied Successfully'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadBins(silent: true);
      if (!mounted) return;
      BinModel? next;
      for (final x in _bins) {
        if (x.id == b.id) {
          next = x;
          break;
        }
      }
      setState(() => _selectedBin = next);
      widget.onCollectionComplete?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _collectingBinId = null);
    }
  }

  /// Centers the map on [lat]/[lng] at zoom 16 and selects the matching bin when possible.
  void zoomToBin(double lat, double lng) {
    if (!mounted) return;
    final target = LatLng(lat, lng);
    _mapController.move(target, 16);
    BinModel? best;
    var bestD2 = double.infinity;
    for (final b in _bins) {
      if (b.latitude == null || b.longitude == null) continue;
      final dx = b.latitude! - lat;
      final dy = b.longitude! - lng;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = b;
      }
    }
    // ~0.0001 deg² ≈ tens of metres — treat as same bin when jumping from list.
    if (best != null && bestD2 < 0.0001) {
      setState(() => _selectedBin = best);
    } else {
      setState(() => _selectedBin = null);
    }
  }

  Future<void> _loadBins({required bool silent}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final raw = await api.getBins();
      if (!mounted) return;
      setState(() {
        _bins = BinModel.listFromDynamic(raw);
        _loading = false;
      });
      _centerOnFirstBinOnce();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load bins: $e')),
        );
      }
    }
  }

  void _centerOnFirstBinOnce() {
    if (_didInitialCamera) return;
    final withCoords =
        _bins.where((b) => b.latitude != null && b.longitude != null).toList();
    if (withCoords.isEmpty) return;
    _didInitialCamera = true;
    final first = withCoords.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(
        LatLng(first.latitude!, first.longitude!),
        14,
      );
    });
  }

  Future<void> _locate() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  List<BinModel> get _visible {
    if (_filter == 'all') return _bins;
    return _bins.where((b) {
      final s = b.status.toLowerCase();
      return s == _filter;
    }).toList();
  }

  LatLng get _mapInitialCenter {
    final withCoords =
        _visible.where((b) => b.latitude != null && b.longitude != null);
    if (withCoords.isNotEmpty) {
      final b = withCoords.first;
      return LatLng(b.latitude!, b.longitude!);
    }
    if (_userLocation != null) return _userLocation!;
    return _defaultRegion;
  }

  /// Marker color strictly from fill level (monitoring thresholds).
  Color _markerColorForFill(BinModel b) {
    if (b.fillLevel >= 90) return Colors.red.shade700;
    if (b.fillLevel >= 70) return Colors.orange.shade800;
    return AppColors.primaryGreen;
  }

  List<Marker> _binMarkers() {
    return _visible
        .map((b) {
          if (b.latitude == null || b.longitude == null) return null;
          final point = LatLng(b.latitude!, b.longitude!);
          final c = _markerColorForFill(b);
          return Marker(
            point: point,
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => setState(() => _selectedBin = b),
              child: Container(
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: c.withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.delete, color: Colors.white, size: 20),
              ),
            ),
          );
        })
        .whereType<Marker>()
        .toList();
  }

  Future<void> _openDirections(double lat, double lng) async {
    if (_userLocation != null) {
      final o = _userLocation!;
      if (kIsWeb) {
        final uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&origin=${o.latitude},${o.longitude}'
          '&destination=$lat,$lng&travelmode=driving',
        );
        await launchUrl(uri, webOnlyWindowName: '_blank');
        return;
      }
    }
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mapInitialCenter,
                  initialZoom: 14,
                  minZoom: 3,
                  maxZoom: 18,
                  onTap: (_, __) => setState(() => _selectedBin = null),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  if (_hasMapbox)
                    TileLayer(
                      urlTemplate:
                          'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${AppConfig.mapboxApiKey}',
                      userAgentPackageName: 'smartbin_mobile',
                    )
                  else
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'smartbin_mobile',
                    ),
                  if (_userLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _userLocation!,
                          width: 28,
                          height: 28,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.near_me,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    ),
                  MarkerLayer(markers: _binMarkers()),
                ],
              ),
            ),
            if (_loading && _bins.isEmpty)
              Positioned.fill(
                child: ColoredBox(
                  color: surface.withValues(alpha: 0.85),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    color: surface.withValues(alpha: 0.94),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _filter == 'all',
                            onSelected: (_) => setState(() => _filter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Critical'),
                            selected: _filter == 'critical',
                            onSelected: (_) =>
                                setState(() => _filter = 'critical'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Warning'),
                            selected: _filter == 'warning',
                            onSelected: (_) =>
                                setState(() => _filter = 'warning'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Normal'),
                            selected: _filter == 'normal',
                            onSelected: (_) =>
                                setState(() => _filter = 'normal'),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Refresh now',
                            onPressed: () async {
                              await _loadBins(silent: true);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Map data refreshed'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_selectedBin != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _BinInfoPanel(
                      bin: _selectedBin!,
                      onClose: () => setState(() => _selectedBin = null),
                      onDirections: _selectedBin!.latitude != null &&
                              _selectedBin!.longitude != null
                          ? () {
                              unawaited(_openDirections(
                                _selectedBin!.latitude!,
                                _selectedBin!.longitude!,
                              ));
                            }
                          : null,
                      showConfirmCollect:
                          _canConfirmCollection(_selectedBin!),
                      isCollecting: _collectingBinId == _selectedBin!.id,
                      onConfirmCollect: () =>
                          _confirmCollect(_selectedBin!),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Info window–style summary for a selected bin (code, location, fill %).
class _BinInfoPanel extends StatelessWidget {
  final BinModel bin;
  final VoidCallback onClose;
  final VoidCallback? onDirections;
  final bool showConfirmCollect;
  final bool isCollecting;
  final VoidCallback onConfirmCollect;

  const _BinInfoPanel({
    required this.bin,
    required this.onClose,
    this.onDirections,
    this.showConfirmCollect = false,
    this.isCollecting = false,
    required this.onConfirmCollect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bin.binCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bin.location,
                    style: const TextStyle(
                      color: AppColors.subText,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current fill: ${bin.fillLevel.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (onDirections != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onDirections,
                  child: const Text('Directions'),
                ),
              ),
            ],
          ),
        ] else
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClose,
              child: const Text('Close'),
            ),
          ),
        if (showConfirmCollect) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: isCollecting ? null : onConfirmCollect,
            icon: isCollecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(isCollecting ? 'Processing...' : 'Confirm Collection'),
          ),
        ],
      ],
    );
  }
}
