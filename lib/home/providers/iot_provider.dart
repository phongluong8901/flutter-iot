import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:my_production_app/home/providers/auth_check.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:my_production_app/home/screens/widgets/head_notifications.dart';
import 'package:app_settings/app_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart'; // Line-by-line: Thư viện HTTP mạnh mẽ để upload file
import 'package:flutter_dotenv/flutter_dotenv.dart';

class IotProvider extends ChangeNotifier {
  // --- CẤU HÌNH URL ĐỘNG ---

  // Line-by-line: Hàm lấy Base URL (có đuôi /iot) từ SharedPreferences hoặc .env
  Future<String> get _baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    String? savedIp = prefs.getString('server_ip');

    // Line-by-line: Ưu tiên sử dụng IP do người dùng nhập thủ công nếu có
    if (savedIp != null && savedIp.isNotEmpty) {
      return "http://$savedIp:3000/iot";
    }

    // Line-by-line: Nếu không có IP thủ công, dùng giá trị mặc định từ file .env
    if (kIsWeb) {
      return "http://localhost:3000/iot";
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://192.168.1.5:3000/iot";
    } else {
      return "http://192.168.1.5:3000/iot";
    }
  }

  // Line-by-line: Hàm lấy Root URL (bỏ đuôi /iot) để dùng cho các API user/socket
  Future<String> get _rootUrl async {
    final base = await _baseUrl;
    return base.replaceAll('/iot', '');
  }

  late IO.Socket socket;
  final Dio _dio = Dio();

  // --- BIẾN TRẠNG THÁI ---
  double _temp = 0.0, _humidity = 0.0, _gas = 0.0, _light = 0.0;
  bool _isOnline = false;
  bool _rgbLedStatus = false;
  Color _rgbColor = Colors.green;
  Map<String, dynamic> _devicesControl = {};
  bool _isNotificationEnabled = true;
  bool get isNotificationEnabled => _isNotificationEnabled;

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  final Map<String, bool> _activeMonitors = {
    "temperature": true,
    "humidity": true,
    "gas_leak": true,
    "light_intensity": true,
  };

  List<dynamic> _logs = [];
  List<dynamic> get logs => _logs;
  int get unreadCount => _logs.where((log) => log['is_read'] == false).length;

  List<double> tempHistory = List.generate(15, (index) => 0.0);
  List<double> humiHistory = List.generate(15, (index) => 0.0);
  List<double> gasHistory = List.generate(15, (index) => 0.0);
  List<double> lightHistory = List.generate(15, (index) => 0.0);

  Timer? _timer;

  // --- GETTERS ---
  double get temp => _temp;
  double get humidity => _humidity;
  double get gas => _gas;
  double get light => _light;
  bool get isOnline => _isOnline;
  bool get rgbLedStatus => _rgbLedStatus;
  Color get rgbColor => _rgbColor;
  Map<String, dynamic> get devicesControl => _devicesControl;
  Map<String, bool> get activeMonitors => _activeMonitors;

  Future<Map<String, String>> _getHeaders() async {
    String? token = await AuthCheck.getIdToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  IotProvider() {
    _loadNotificationSettings();
    fetchIotStatus();
    fetchMe();
    _startGlobalTimer();
    _initSocket();
  }

  // --- QUẢN LÝ USER PROFILE ---

  Future<void> fetchMe() async {
    try {
      final headers = await _getHeaders();
      final root = await _rootUrl; // Line-by-line: Đợi lấy root URL động
      final url = '${root.trim()}/users/me';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        _currentUser = jsonDecode(response.body);
        notifyListeners();
      } else {
        debugPrint("❌ Fetch Me Failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Fetch Profile Error: $e");
    }
  }

  // --- UPLOAD ẢNH ĐẠI DIỆN ---
  bool _isUploading = false;
  bool get isUploading => _isUploading;

  Future<void> uploadAvatar(XFile imageFile) async {
    _isUploading = true;
    notifyListeners();

    try {
      String? token = await AuthCheck.getIdToken();
      final root = await _rootUrl; // Line-by-line: Đợi lấy root URL động
      final String uploadUrl = "${root.trim()}/users/upload-avatar";

      MultipartFile multipartFile;

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: imageFile.name,
        );
      } else {
        multipartFile = await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.name,
        );
      }

      FormData formData = FormData.fromMap({"file": multipartFile});

      var response = await _dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data['success'] == true) {
          debugPrint("✅ Thành công trên ${kIsWeb ? 'Web' : 'Mobile'}");
          await fetchMe();
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi upload chi tiết: $e");
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> updateData) async {
    try {
      final headers = await _getHeaders();
      String root = await _rootUrl; // Line-by-line: Đợi lấy root URL động
      if (root.endsWith('/')) {
        root = root.substring(0, root.length - 1);
      }
      final url = Uri.parse('$root/users/update');

      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchMe();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("--- ❌ LỖI UPDATE: $e ---");
      return false;
    }
  }

  // --- LOGIC THÔNG BÁO ---
  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isNotificationEnabled = prefs.getBool('noti_enabled') ?? true;
    if (_isNotificationEnabled && !kIsWeb) {
      await FirebaseMessaging.instance.subscribeToTopic('factory_alerts');
    }
    notifyListeners();
  }

  Future<void> toggleNotificationPermission(bool value) async {
    if (kIsWeb) {
      _isNotificationEnabled = value;
      notifyListeners();
      return;
    }
    if (value == true) {
      var status = await Permission.notification.status;
      if (status.isPermanentlyDenied || status.isDenied) {
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
        return;
      }
      await FirebaseMessaging.instance.subscribeToTopic('factory_alerts');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('factory_alerts');
    }
    _isNotificationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('noti_enabled', value);
    notifyListeners();
  }

  // --- SOCKET ---
  void _initSocket() async {
    // Line-by-line: Socket cần lấy root URL trước khi khởi tạo
    final socketUrl = await _rootUrl;
    socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    socket.onConnect((_) => debugPrint("✅ Socket Connected: ${socket.id}"));
    socket.on('woki-alert', (data) {
      if (!_isNotificationEnabled) return;
      NotificationService.showLocalAlert(
        data['title'] ?? 'Cảnh báo',
        data['message'] ?? 'Phát hiện bất thường!',
      );
      fetchLogs();
    });
  }

  // --- API LOGS & STATUS ---
  Future<void> fetchLogs() async {
    try {
      final headers = await _getHeaders();
      final base = await _baseUrl; // Line-by-line: Đợi lấy base URL động
      final response = await http.get(
        Uri.parse('$base/logs'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        _logs = jsonDecode(response.body);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Logs Error: $e");
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final headers = await _getHeaders();
      final base = await _baseUrl;
      await http.delete(Uri.parse('$base/logs'), headers: headers);
      _logs.clear();
      notifyListeners();
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final headers = await _getHeaders();
      final base = await _baseUrl;
      final response = await http.patch(
        Uri.parse('$base/logs/$id'),
        headers: headers,
        body: jsonEncode({"is_read": true}),
      );
      if (response.statusCode == 200) await fetchLogs();
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  Future<void> deleteSingleLog(String id) async {
    try {
      final headers = await _getHeaders();
      final base = await _baseUrl;
      await http.delete(Uri.parse('$base/logs/$id'), headers: headers);
      await fetchLogs();
    } catch (e) {
      debugPrint("Delete Single Error: $e");
    }
  }

  // --- LOGIC MÀU SẮC ---
  Color getTempColor() => _temp > 40.0
      ? Colors.redAccent
      : (_temp > 30.0 ? Colors.orangeAccent : Colors.greenAccent);
  Color getHumidityColor() =>
      (_humidity < 30 || _humidity > 80) ? Colors.redAccent : Colors.cyanAccent;
  Color getGasColor() => _gas > 2500
      ? Colors.redAccent
      : (_gas > 1200 ? Colors.orangeAccent : Colors.greenAccent);
  Color getLightColor() =>
      _light < 1000 ? Colors.redAccent : Colors.yellowAccent;

  String getStatusText(double val, String type) {
    switch (type) {
      case 'temp':
        return val > 40.0
            ? "QUÁ NHIỆT (Bật quạt)"
            : (val > 30.0 ? "Nhiệt độ cao" : "Ổn định");
      case 'humi':
        return (val < 30 || val > 80) ? "ẨM NGUY HIỂM (Mở cửa)" : "Tốt";
      case 'gas':
        return val > 2500 ? "RÒ RỈ GAS (Báo động)" : "An toàn";
      case 'light':
        return val < 1000 ? "QUÁ TỐI (Báo động)" : "Bình thường";
      default:
        return "Bình thường";
    }
  }

  void toggleMonitoring(String key) {
    if (_activeMonitors.containsKey(key)) {
      _activeMonitors[key] = !(_activeMonitors[key]!);
      notifyListeners();
    }
  }

  Future<void> fetchIotStatus() async {
    try {
      final headers = await _getHeaders();
      final base = await _baseUrl; // Line-by-line: Lấy URL động cho status
      final response = await http
          .get(Uri.parse('$base/status'), headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sensors = data['iot_sensors'];
        _temp = (sensors['temperature']['value'] as num).toDouble();
        _humidity = (sensors['humidity']['value'] as num).toDouble();
        _gas = (sensors['gas_leak']['value'] as num).toDouble();
        _light = (sensors['light_intensity']['value'] as num).toDouble();
        _isOnline = sensors['temperature']['is_online'] ?? false;
        _devicesControl = Map<String, dynamic>.from(data['devices_control']);

        final rgb = data['rgb_status'] ??
            {
              'is_on': false,
              'color': {'r': 0, 'g': 255, 'b': 0},
            };
        _rgbLedStatus = rgb['is_on'];
        _rgbColor = Color.fromARGB(
          255,
          rgb['color']['r'],
          rgb['color']['g'],
          rgb['color']['b'],
        );

        _updateList(tempHistory, _temp);
        _updateList(humiHistory, _humidity);
        _updateList(gasHistory, _gas);
        _updateList(lightHistory, _light);

        if (_isNotificationEnabled &&
            _gas > 2500 &&
            _activeMonitors['gas_leak'] == true) {
          NotificationService.showLocalAlert(
            "CẢNH BÁO NGUY HIỂM",
            "Phát hiện rò rỉ Gas: $_gas ppm!",
          );
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error Status: $e");
    }
  }

  // --- ĐIỀU KHIỂN THIẾT BỊ ---
  Future<void> toggleDevicePower(String deviceKey, bool status) async {
    try {
      final headers = await _getHeaders();
      final base = await _baseUrl; // Line-by-line: Lấy URL động cho control
      final body = {"type": "control", "name": deviceKey, "is_on": status};
      await http.post(
        Uri.parse('$base/control'),
        headers: headers,
        body: jsonEncode(body),
      );
      await fetchIotStatus();
    } catch (e) {
      debugPrint("Error Control: $e");
    }
  }

  Future<void> updateRGBColor(Color color) async {
    try {
      final headers = await _getHeaders();
      final base = await _baseUrl;
      final body = {
        "type": "rgb",
        "r": color.red,
        "g": color.green,
        "b": color.blue,
        "is_on": true,
      };
      await http.post(
        Uri.parse('$base/control'),
        headers: headers,
        body: jsonEncode(body),
      );
      _rgbColor = color;
      _rgbLedStatus = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error RGB: $e");
    }
  }

  Future<bool> updateDeviceSettings(
    String deviceId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final headers = await _getHeaders();
      final base = await _baseUrl;
      final response = await http.patch(
        Uri.parse('$base/devices/$deviceId'),
        headers: headers,
        body: jsonEncode(updateData),
      );
      if (response.statusCode == 200) {
        await fetchIotStatus();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> resetDeviceHealth(String deviceId) async {
    try {
      final headers = await _getHeaders();
      final base = await _baseUrl;
      final response = await http.post(
        Uri.parse('$base/devices/$deviceId/reset-health'),
        headers: headers,
      );
      if (response.statusCode == 200) await fetchIotStatus();
    } catch (e) {
      debugPrint("Error Health: $e");
    }
  }

  void _startGlobalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => fetchIotStatus(),
    );
  }

  void _updateList(List<double> list, double newValue) {
    if (list.length >= 15) list.removeAt(0);
    list.add(newValue);
  }

  @override
  void dispose() {
    _timer?.cancel();
    socket.dispose();
    super.dispose();
  }
}
