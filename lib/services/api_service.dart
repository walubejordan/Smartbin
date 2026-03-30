import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/preferences_keys.dart';
import '../models/bin_model.dart';
import 'notification_service.dart';

class ApiService {
  // Production backend base URL (Render)
  // All requests go through this HTTPS endpoint.
  static const String baseUrl =
      'https://smartbin-backend-dng0.onrender.com/api';

  String? _token;

  // use a BrowserClient on web, otherwise the default IO client
  final http.Client _client = kIsWeb ? BrowserClient() : http.Client();

  Timer? _binMonitorTimer;
  bool _binMonitoringActive = false;
  /// Bin IDs already alerted while fill stayed at/above threshold (clears when fill drops below).
  final Set<int> _fillAlertedBinIds = {};

  // Render free-tier can take ~50s to spin up. Use a 60s timeout for all
  // outbound HTTP calls so the first request doesn't fail too early.
  static const Duration _requestTimeout = Duration(seconds: 60);

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    return _client.get(uri, headers: headers).timeout(_requestTimeout);
  }

  Future<http.Response> _post(Uri uri,
      {Map<String, String>? headers, Object? body}) {
    return _client
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  Future<http.Response> _put(Uri uri,
      {Map<String, String>? headers, Object? body}) {
    return _client
        .put(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  Future<http.Response> _patch(Uri uri,
      {Map<String, String>? headers, Object? body}) {
    return _client
        .patch(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  Future<http.Response> _delete(Uri uri,
      {Map<String, String>? headers, Object? body}) {
    return _client
        .delete(uri, headers: headers, body: body)
        .timeout(_requestTimeout);
  }

  // Getter to check if token exists
  bool get hasToken => _token != null;

  // Initialize and load token from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  // Save token to storage
  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Clear token from storage
  Future<void> clearToken() async {
    stopBinMonitoring();
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // Get headers with authentication
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('ApiService.login -> POST $baseUrl/auth/login');

      final response = await _post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success']) {
          await saveToken(data['data']['token']);
          return data;
        } else {
          throw Exception(data['message'] ?? 'Login failed');
        }
      } else {
        // Try to parse the error response from the backend. If this is a true
        // server-side error (5xx) or the backend reports "server error during
        // login", surface a friendly message so the UI can show a helpful
        // SnackBar instead of a crash when Render is still waking up.
        try {
          final data = json.decode(response.body);
          final String? message =
              data is Map<String, dynamic> ? data['message']?.toString() : null;

          if (response.statusCode >= 500 ||
              (message != null &&
                  message
                      .toLowerCase()
                      .contains('server error during login'))) {
            throw Exception(
                'Server is waking up, please try again in 30 seconds.');
          }

          throw Exception(
              message ?? 'Login failed with status ${response.statusCode}');
        } catch (_) {
          // If the body isn't JSON or can't be parsed, fall back based on
          // status code.
          if (response.statusCode >= 500) {
            throw Exception(
                'Server is waking up, please try again in 30 seconds.');
          }

          throw Exception('Login failed with status ${response.statusCode}');
        }
      }
    } catch (e, stack) {
      // Network / timeout / CORS-style errors will end up here (especially
      // on Flutter Web). Map them to the same friendly message used above so
      // the caller can always show a clear SnackBar instead of a red error
      // screen when the Render instance is still cold-starting.
      print('Login error: $e');
      print(stack);

      final message = e.toString();
      final bool looksLikeWakeupIssue = message.contains(
              'Server is waking up, please try again in 30 seconds.') ||
          message.contains('XMLHttpRequest error') ||
          message.toLowerCase().contains('timed out') ||
          message.contains('Failed host lookup');

      if (looksLikeWakeupIssue) {
        throw Exception('Server is waking up, please try again in 30 seconds.');
      }

      // For other errors (e.g. invalid credentials), let the original
      // message bubble up so the UI can show it.
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: _getHeaders(),
      );
    } finally {
      await clearToken();
    }
  }

  // Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    print('ApiService.getProfile -> GET $baseUrl/auth/profile');
    print('Headers: ${_getHeaders()}');
    final response = await _get(
      Uri.parse('$baseUrl/auth/profile'),
      headers: _getHeaders(),
    );

    print('Profile response status: ${response.statusCode}');
    print('Profile response body: ${response.body}');

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get profile');
    }
  }

  /// Update the logged-in user's name, email, optional phone, and optional zone.
  /// Use [includePhone] / [includeZone] so omitted fields are left unchanged on the server.
  Future<Map<String, dynamic>> updateMyProfile({
    required String name,
    required String email,
    String? phone,
    String? zone,
    bool includePhone = false,
    bool includeZone = false,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
    };
    if (includePhone) {
      final p = phone?.trim();
      body['phone'] = p == null || p.isEmpty ? null : p;
    }
    if (includeZone) {
      final z = zone?.trim();
      body['zone'] = z == null || z.isEmpty ? null : z;
    }

    final response = await _put(
      Uri.parse('$baseUrl/auth/profile'),
      headers: _getHeaders(),
      body: json.encode(body),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final d = data['data'];
      if (d is Map<String, dynamic>) return d;
      if (d is Map) return Map<String, dynamic>.from(d);
      throw Exception('Invalid profile response');
    }
    throw Exception(data['message'] ?? 'Failed to update profile');
  }

  /// Change password for the current user.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: _getHeaders(),
      body: json.encode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to change password');
    }
  }

  // Get all bins (filtered by user role on backend)
  Future<List<dynamic>> getBins(
      {String? status, int? assignedTo, int? limit, int? offset}) async {
    String url = '$baseUrl/bins?';
    if (status != null) url += 'status=$status&';
    if (assignedTo != null) url += 'assigned_to=$assignedTo&';
    // Fetch all bins by default (set high limit if not specified)
    url += 'limit=${limit ?? 1000}&offset=${offset ?? 0}';

    final response = await _get(
      Uri.parse(url),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success']) {
      final raw = data['data'];
      if (raw is List) {
        return raw;
      }
      if (raw is Map<String, dynamic>) {
        final nested =
            raw['bins'] ?? raw['items'] ?? raw['results'] ?? raw['data'];
        if (nested is List) {
          return nested;
        }
      }
      return <dynamic>[];
    } else {
      throw Exception(data['message'] ?? 'Failed to get bins');
    }
  }

  // Get single bin
  Future<Map<String, dynamic>> getBin(int binId) async {
    final response = await _get(
      Uri.parse('$baseUrl/bins/$binId'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get bin');
    }
  }

  /// Logged-in collector's collection history (joined with bin code & location).
  Future<List<dynamic>> getCollectionHistory() async {
    final response = await _get(
      Uri.parse('$baseUrl/collections/my-history'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final list = data['data'];
      if (list is List) return list;
      return [];
    }
    throw Exception(data['message'] ?? 'Failed to load collection history');
  }

  /// Recent collections org-wide (admin only). `GET /api/collections?limit=`.
  Future<List<dynamic>> getRecentCollections({int limit = 10}) async {
    final response = await _get(
      Uri.parse('$baseUrl/collections?limit=$limit'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final list = data['data'];
      if (list is List) return list;
      return [];
    }
    throw Exception(data['message'] ?? 'Failed to load recent collections');
  }

  // Get bin collection history
  Future<List<dynamic>> getBinHistory(int binId) async {
    final response = await _get(
      Uri.parse('$baseUrl/bins/$binId/history'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final history = data['data'];
      if (history is List) {
        return history;
      }
      return [];
    } else {
      throw Exception(data['message'] ?? 'Failed to get bin history');
    }
  }

  // Mark bin as collected
  Future<Map<String, dynamic>> collectBin(int binId, {String? notes}) async {
    final response = await _post(
      Uri.parse('$baseUrl/bins/$binId/collect'),
      headers: _getHeaders(),
      body: json.encode({
        if (notes != null) 'notes': notes,
      }),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success']) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to mark bin as collected');
    }
  }

  // Get notifications
  Future<Map<String, dynamic>> getNotifications(
      {bool? isRead, int limit = 50}) async {
    String url = '$baseUrl/notifications?limit=$limit';
    if (isRead != null) url += '&is_read=$isRead';

    final response = await _get(
      Uri.parse(url),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success']) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get notifications');
    }
  }

  // Mark notification as read
  Future<void> markNotificationRead(int notificationId) async {
    final response = await _patch(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200 || !data['success']) {
      throw Exception(data['message'] ?? 'Failed to mark notification as read');
    }
  }

  // Get dashboard data (Admin)
  Future<Map<String, dynamic>> getAdminDashboard() async {
    final response = await _get(
      Uri.parse('$baseUrl/dashboard/admin'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get dashboard');
    }
  }

  /// Admin analytics: last-7-days volume, zone stats, top collectors, impact totals.
  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    final response = await _get(
      Uri.parse('$baseUrl/analytics/summary'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final raw = data['data'];
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return <String, dynamic>{};
    }
    throw Exception(data['message'] ?? 'Failed to load analytics');
  }

  /// Admin weekly PDF report (`GET /analytics/report/weekly`).
  Future<Uint8List> downloadWeeklyPdfReport() async {
    final uri = Uri.parse('$baseUrl/analytics/report/weekly');
    final headers = <String, String>{
      ..._getHeaders(),
      'Accept': 'application/pdf',
    };
    final response = await _get(uri, headers: headers);

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final ct = response.headers['content-type'] ?? '';
      if (ct.contains('pdf') || _looksLikePdf(response.bodyBytes)) {
        return response.bodyBytes;
      }
    }

    try {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final msg = data is Map ? data['message']?.toString() : null;
      throw Exception(msg ?? 'Failed to download report');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(
        'Failed to download report (HTTP ${response.statusCode})',
      );
    }
  }

  static bool _looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  // Get dashboard data (Collector)
  Future<Map<String, dynamic>> getCollectorDashboard() async {
    final response = await _get(
      Uri.parse('$baseUrl/dashboard/collector'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get dashboard');
    }
  }

  // Get collection history for a user (collector)
  Future<List<dynamic>> getUserCollections(int userId) async {
    final response = await _get(
      Uri.parse('$baseUrl/users/$userId/collections'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final collections = data['data'];
      if (collections is List) {
        return collections;
      }
      return [];
    } else {
      throw Exception(data['message'] ?? 'Failed to get collection history');
    }
  }

  // Get all users (Admin only)
  Future<List<dynamic>> getUsers({String? role, String? status}) async {
    String url = '$baseUrl/users?';
    if (role != null) url += 'role=$role&';
    if (status != null) url += 'status=$status';

    final response = await _get(
      Uri.parse(url),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get users');
    }
  }

  // Get collectors only (Admin only) - for dropdowns
  Future<List<dynamic>> getCollectors() async {
    final response = await _get(
      Uri.parse('$baseUrl/users/collectors'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final collectors = data['data'];
      if (collectors is List) {
        return collectors;
      }
      return [];
    } else {
      throw Exception(data['message'] ?? 'Failed to get collectors');
    }
  }

  // Update FCM token for the logged-in user
  Future<void> updateFcmToken(String token) async {
    final response = await _patch(
      Uri.parse('$baseUrl/users/update-fcm'),
      headers: _getHeaders(),
      body: json.encode({
        'fcm_token': token,
      }),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to update FCM token');
    }
  }

  // Get specific user by ID (Admin only)
  Future<Map<String, dynamic>> getUser(int userId) async {
    final response = await _get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['success']) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get user');
    }
  }

  // Create user (Admin only)
  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? zone,
    String role = 'collector',
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/users'),
      headers: _getHeaders(),
      body: json.encode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        if (zone != null) 'zone': zone,
        'role': role,
      }),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 201 && data['success']) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to create user');
    }
  }

  // Update user (Admin only)
  Future<void> updateUser(int userId,
      {String? name,
      String? email,
      String? phone,
      String? zone,
      bool setZone = false,
      String? role,
      String? status}) async {
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (setZone) body['zone'] = zone;
    if (role != null) body['role'] = role;
    if (status != null) body['status'] = status;

    final response = await _put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _getHeaders(),
      body: json.encode(body),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to update user');
    }
  }

  // Update user status (Admin only)
  Future<void> updateUserStatus(int userId, String status) async {
    final response = await _patch(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _getHeaders(),
      body: json.encode({
        'status': status,
      }),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to update user status');
    }
  }

  // Reset user password (Admin only)
  Future<void> resetUserPassword(int userId, String newPassword) async {
    final response = await _post(
      Uri.parse('$baseUrl/users/$userId/reset-password'),
      headers: _getHeaders(),
      body: json.encode({
        'newPassword': newPassword,
      }),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200 || !data['success']) {
      throw Exception(data['message'] ?? 'Failed to reset password');
    }
  }

  // Delete user (Admin only)
  Future<void> deleteUser(int userId) async {
    final response = await _delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to delete user');
    }
  }

  // Create bin (Admin only)
  Future<Map<String, dynamic>> createBin({
    required String binCode,
    required String location,
    double? latitude,
    double? longitude,
    int? capacity,
    int? assignedTo,
    String? zone,
  }) async {
    final body = <String, dynamic>{
      'bin_code': binCode,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity ?? 100,
      'assigned_to': assignedTo,
    };
    final z = zone?.trim();
    if (z != null && z.isNotEmpty) body['zone'] = z;

    final response = await _post(
      Uri.parse('$baseUrl/bins'),
      headers: _getHeaders(),
      body: json.encode(body),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 201 && data['success']) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to create bin');
    }
  }

  // Update bin (Admin only)
  Future<void> updateBin(
    int binId, {
    String? binCode,
    String? location,
    double? latitude,
    double? longitude,
    int? capacity,
    int? assignedTo,
    /// When true, sends `assigned_to` even if null (clears assignment on server).
    bool sendAssignedTo = false,
    String? status,
    /// When true, sends `zone` (null clears on server when supported).
    bool sendZone = false,
    String? zone,
  }) async {
    final Map<String, dynamic> body = {};
    if (binCode != null) body['bin_code'] = binCode;
    if (location != null) body['location'] = location;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (capacity != null) body['capacity'] = capacity;
    if (sendAssignedTo) {
      body['assigned_to'] = assignedTo;
    } else if (assignedTo != null) {
      body['assigned_to'] = assignedTo;
    }
    if (status != null) body['status'] = status;
    if (sendZone) {
      final z = zone?.trim();
      body['zone'] = (z == null || z.isEmpty) ? null : z;
    }

    final response = await _put(
      Uri.parse('$baseUrl/bins/$binId'),
      headers: _getHeaders(),
      body: json.encode(body),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200 || !data['success']) {
      throw Exception(data['message'] ?? 'Failed to update bin');
    }
  }

  // Delete bin (Admin only)
  Future<void> deleteBin(int binId) async {
    final response = await _delete(
      Uri.parse('$baseUrl/bins/$binId'),
      headers: _getHeaders(),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Failed to delete bin');
    }
  }

  /// Polls [getBins] every 30s while active. Compares [BinModel.fillLevel] to
  /// [PreferencesKeys.adminFillLevelAlertThreshold] in SharedPreferences.
  /// Alerts once per bin when crossing into “full” until level drops below threshold.
  ///
  /// The timer keeps running while the app process stays alive (including many
  /// background transitions on Android). iOS may suspend the isolate after a
  /// period in background; use push/BG fetch for guaranteed server-driven alerts.
  void startBinMonitoring() {
    if (kIsWeb || !hasToken) return;
    if (_binMonitorTimer != null) return;

    _binMonitoringActive = true;
    unawaited(_binMonitoringTick());
    _binMonitorTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_binMonitoringTick()),
    );
  }

  void stopBinMonitoring() {
    _binMonitoringActive = false;
    _binMonitorTimer?.cancel();
    _binMonitorTimer = null;
    _fillAlertedBinIds.clear();
  }

  Future<void> _binMonitoringTick() async {
    if (!_binMonitoringActive || !hasToken || kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawT = prefs.getInt(PreferencesKeys.adminFillLevelAlertThreshold);
      final threshold = (rawT ?? 80).toDouble().clamp(0, 100);

      final rawBins = await getBins();
      final bins = BinModel.listFromDynamic(rawBins);
      final idsSeen = <int>{};

      for (final b in bins) {
        if (b.id == 0) continue;
        idsSeen.add(b.id);

        if (b.fillLevel >= threshold) {
          if (!_fillAlertedBinIds.contains(b.id)) {
            _fillAlertedBinIds.add(b.id);
            await NotificationService.showNotification(b.binCode, b.location);
          }
        } else {
          _fillAlertedBinIds.remove(b.id);
        }
      }

      _fillAlertedBinIds.removeWhere((id) => !idsSeen.contains(id));
    } catch (e, st) {
      debugPrint('Bin monitoring: $e\n$st');
    }
  }
}
