import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // Line-by-line: Thêm thư viện này để dùng hằng số kIsWeb
import 'firebase_options.dart';
import 'home/screens/widgets/head_notifications.dart';
import 'auth/auth_service.dart';
import 'auth/screens/login_screen.dart';
import 'home/screens/home_screen.dart';
import 'home/providers/iot_provider.dart';

void main() async {
  // Line-by-line: Đảm bảo các thành phần hệ thống của Flutter được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // Line-by-line: Khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Line-by-line: CÁCH SỬA QUAN TRỌNG NHẤT
  // Không dùng 'await' cho NotificationService để tránh việc lỗi trên Web làm treo cả App
  // Đồng thời bên trong NotificationService.initialize() bạn phải dùng kIsWeb như mình đã hướng dẫn trước đó.
  NotificationService.initialize().catchError((e) {
    print("⚠️ Lỗi khởi tạo Notification (Có thể do chạy trên Web): $e");
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IotProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Factory Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00D2FF),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      // Line-by-line: Sử dụng StreamBuilder để quản lý trạng thái đăng nhập
      home: StreamBuilder(
        stream: AuthService().userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Line-by-line: Nếu đã login thì vào Home, chưa thì vào Login
          if (snapshot.hasData) return const HomeScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}
