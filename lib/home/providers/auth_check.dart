import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthCheck {
  // Line-by-line: Đổi tên thành AuthCheck và giữ static để gọi nhanh
  static Future<String?> getIdToken() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Line-by-line: Trả về token cho IotProvider sử dụng
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      debugPrint("❌ AuthCheck Error: $e");
      return null;
    }
  }
}
