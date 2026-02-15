import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Line-by-line: Import dotenv để đọc biến môi trường
import 'firebase_options.dart';
import 'home/screens/widgets/head_notifications.dart';
import 'auth/auth_service.dart';
import 'auth/screens/login_screen.dart';
import 'home/screens/home_screen.dart';
import 'home/providers/iot_provider.dart';

void main() async {
  // Line-by-line: Đảm bảo Flutter được khởi tạo trước khi gọi các hàm async
  WidgetsFlutterBinding.ensureInitialized();

  // Line-by-line: Nạp file .env ngay từ đầu. Cậu cần tạo file này ở root project.
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
        "⚠️ Cảnh báo: Không tìm thấy file .env, app sẽ dùng giá trị mặc định.");
  }

  // Line-by-line: Khởi tạo Firebase dựa trên nền tảng
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Line-by-line: Khởi tạo Notification mà không dùng await để tránh treo app trên Web
  NotificationService.initialize().catchError((e) {
    debugPrint("⚠️ Lỗi khởi tạo Notification: $e");
  });

  runApp(
    MultiProvider(
      providers: [
        // Line-by-line: Đăng ký IotProvider để dùng trong toàn bộ app
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
      // Line-by-line: StreamBuilder lắng nghe trạng thái đăng nhập từ Firebase
      home: StreamBuilder(
        stream: AuthService().userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Line-by-line: Nếu snapshot có dữ liệu (user != null) thì vào Home
          if (snapshot.hasData) return const HomeScreen();

          // Line-by-line: Ngược lại thì quay về màn Login
          return const LoginScreen();
        },
      ),
    );
  }
}
