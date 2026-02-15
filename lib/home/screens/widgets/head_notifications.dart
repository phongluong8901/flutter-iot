import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'; // Line-by-line: Thư viện bắt buộc để dùng kIsWeb

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Line-by-line: Xin quyền (Cả Web và Mobile đều cần dòng này)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Line-by-line: KIỂM TRA NỀN TẢNG - Subscribe Topic chỉ chạy trên App Mobile
    if (!kIsWeb) {
      await messaging.subscribeToTopic("sensor_alerts");
      print("🚀 Mobile: Đã subscribe Topic thành công");

      // 3. Line-by-line: Cấu hình Local Notifications (Chỉ dành cho Android/iOS)
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: AndroidInitializationSettings("@mipmap/ic_launcher"),
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          print("User nhấn vào thông báo: ${details.payload}");
        },
      );

      // 4. Line-by-line: Tạo Channel độ ưu tiên cao cho Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'iot_urgent_v1',
        'Cảnh báo IOT khẩn cấp',
        description: 'Kênh hiển thị cảnh báo real-time',
        importance: Importance.max,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } else {
      // Line-by-line: Logic dành riêng cho Web Chrome
      print(
          "🌐 Web: Firebase Cloud Messaging đã sẵn sàng (Topic không hỗ trợ)");

      // Line-by-line: Lấy Token trên Web để debug nếu cần
      String? token = await messaging.getToken(
          vapidKey:
              "YOUR_VAPID_KEY_HERE" // Cần nếu bạn muốn bắn tin trực tiếp cho trình duyệt
          );
      print("Web FCM Token: $token");
    }

    // 5. Line-by-line: Lắng nghe tin nhắn Foreground (Cả 2 nền tảng đều dùng được)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 Nhận tin nhắn Firebase!");
      if (!kIsWeb) {
        display(message); // Mobile thì gọi hiển thị popup của hệ thống
      } else {
        // Web thì thường trình duyệt tự hiện hoặc bạn dùng một cái SnackBar/Dialog
        print("Nội dung tin nhắn trên Web: ${message.notification?.title}");
      }
    });
  }

  static void display(RemoteMessage message) async {
    // Line-by-line: Chặn luôn hàm này nếu là Web vì flutter_local_notifications không hỗ trợ Web hoàn toàn như Android
    if (kIsWeb) return;

    try {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const NotificationDetails notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          "iot_urgent_v1",
          "Cảnh báo IOT khẩn cấp",
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
        ),
      );

      await _notificationsPlugin.show(
        id,
        message.notification?.title ?? "Cảnh báo",
        message.notification?.body ?? "Phát hiện bất thường!",
        notificationDetails,
      );
    } catch (e) {
      print("Lỗi hiển thị: $e");
    }
  }

  // Line-by-line: Hàm này dùng để test bắn thông báo tại chỗ (không qua Firebase)
  static void showLocalAlert(String title, String body) async {
    if (kIsWeb) {
      print("Web Alert: $title - $body");
      return;
    }

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'iot_urgent_v1',
        'Cảnh báo trực tiếp',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }
}
