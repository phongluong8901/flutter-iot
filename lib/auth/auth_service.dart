import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // 1. Khởi tạo instance của FirebaseAuth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 2. Stream lắng nghe trạng thái đăng nhập để main.dart tự điều hướng
  Stream<User?> get userStream => _auth.authStateChanges();

  // 3. Logic Đăng nhập
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Không có lỗi
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  // 4. Logic Đăng ký
  Future<String?> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  // 5. Logic Quên mật khẩu (Gửi email khôi phục)
  Future<String?> resetPassword(String email) async {
    try {
      // Firebase sẽ tự gửi một link đổi mật khẩu tới email này
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  // 6. Logic Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 7. Hàm bổ trợ chuyển mã lỗi Firebase sang tiếng Việt chuyên nghiệp
  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return "Email này chưa được đăng ký tài khoản.";
      case 'wrong-password':
        return "Mật khẩu không chính xác.";
      case 'email-already-in-use':
        return "Email này đã được sử dụng bởi một tài khoản khác.";
      case 'invalid-email':
        return "Định dạng email không hợp lệ.";
      case 'user-disabled':
        return "Tài khoản này đã bị khóa.";
      case 'too-many-requests':
        return "Quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.";
      default:
        return "Đã xảy ra lỗi hệ thống (Mã: $code)";
    }
  }

  static Future<String?> getIdToken() async {
    return null;
  }
}
