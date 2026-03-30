/// Domain model for a waste bin, aligned with API `/bins` payloads.
class BinModel {
  final int id;
  final String binCode;
  final String? name;
  final String location;
  final double fillLevel;
  final String status;
  final double? latitude;
  final double? longitude;
  final int? capacity;
  final int? assignedTo;
  final String? collectorName;
  /// Optional area / route (API may expose as `zone`, `area`, or `region`).
  final String? zone;
  /// Optional telemetry (not always present in DB).
  final int? batteryPercent;

  const BinModel({
    required this.id,
    required this.binCode,
    this.name,
    required this.location,
    required this.fillLevel,
    required this.status,
    this.latitude,
    this.longitude,
    this.capacity,
    this.assignedTo,
    this.collectorName,
    this.zone,
    this.batteryPercent,
  });

  static double _fill(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble().clamp(0, 100);
    return double.tryParse(v.toString())?.clamp(0, 100) ?? 0;
  }

  static double? _coord(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory BinModel.fromJson(Map<String, dynamic> json) {
    return BinModel(
      id: _int(json['id']) ?? 0,
      binCode: json['bin_code']?.toString() ?? '—',
      name: json['name']?.toString(),
      location: json['location']?.toString() ?? '—',
      fillLevel: _fill(json['fill_level']),
      status: json['status']?.toString() ?? 'normal',
      latitude: _coord(json['latitude']),
      longitude: _coord(json['longitude']),
      capacity: _int(json['capacity']),
      assignedTo: _int(json['assigned_to']),
      collectorName: json['collector_name']?.toString(),
      zone: json['zone']?.toString() ??
          json['area']?.toString() ??
          json['region']?.toString(),
      batteryPercent: _int(json['battery_level'] ?? json['battery_percent']),
    );
  }

  static List<BinModel> listFromDynamic(List<dynamic> raw) {
    return raw
        .map((e) {
          if (e is Map<String, dynamic>) return BinModel.fromJson(e);
          if (e is Map) return BinModel.fromJson(Map<String, dynamic>.from(e));
          return null;
        })
        .whereType<BinModel>()
        .toList();
  }

  /// API-shaped map (round-trip friendly with [fromJson]).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'bin_code': binCode,
      'name': name,
      'location': location,
      'fill_level': fillLevel,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'assigned_to': assignedTo,
      'collector_name': collectorName,
      'zone': zone,
      'battery_percent': batteryPercent,
    };
  }

  bool get isCritical {
    final s = status.toLowerCase();
    return s == 'critical' || s == 'full' || fillLevel >= 90;
  }

  bool get isWarning {
    final s = status.toLowerCase();
    return s == 'warning' || (fillLevel >= 70 && fillLevel < 90);
  }
}
