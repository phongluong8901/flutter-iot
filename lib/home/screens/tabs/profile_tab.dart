import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_production_app/auth/auth_service.dart';
import 'package:my_production_app/home/providers/iot_provider.dart';
import 'package:image_picker/image_picker.dart'; // Line-by-line: Thư viện chọn ảnh

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  // Line-by-line: Hàm chọn ảnh từ thư viện và gửi lên server
  Future<void> _pickAndUploadImage(BuildContext context) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null && context.mounted) {
      // Line-by-line: Gửi trực tiếp XFile, không dùng File(pickedFile.path) nữa để tránh dính dart:io
      await context.read<IotProvider>().uploadAvatar(pickedFile);
    }
  }

  // Line-by-line: Hàm hiển thị hộp thoại chỉnh sửa (Giữ nguyên logic cũ)
  void _showEditDialog(BuildContext context, String fieldKey, String label,
      String currentValue) {
    TextEditingController controller =
        TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F25),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white12)),
        title: Text("Chỉnh sửa $label",
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              fieldKey == 'age' ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Nhập $label mới",
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00D2FF))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("HỦY", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D2FF)),
            onPressed: () async {
              dynamic valueToSave = controller.text;
              if (fieldKey == 'age') {
                valueToSave = int.tryParse(controller.text) ?? 0;
              }

              final success =
                  await context.read<IotProvider>().updateUserProfile({
                fieldKey: valueToSave,
              });

              if (context.mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Cập nhật thất bại! Vui lòng thử lại.")),
                  );
                }
              }
            },
            child: const Text("LƯU",
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Line-by-line: Widget tạo một dòng thông tin (Giữ nguyên logic cũ)
  Widget _buildInfoItem(BuildContext context, IconData icon, String fieldKey,
      String label, String value) {
    return InkWell(
      onTap: () => _showEditDialog(context, fieldKey, label, value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        child: Row(
          children: [
            Icon(icon,
                color: const Color(0xFF00D2FF).withOpacity(0.7), size: 22),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit_outlined, color: Colors.white12, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iot = context.watch<IotProvider>();
    final user = iot.currentUser ?? {};

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              const SizedBox(height: 30),

              // --- PHẦN AVATAR ---
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      // Line-by-line: Khi nhấn vào vùng Avatar sẽ kích hoạt chọn ảnh
                      onTap: () => _pickAndUploadImage(context),
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      const Color(0xFF00D2FF).withOpacity(0.2),
                                  width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.white10,
                              // Line-by-line: Ưu tiên hiển thị avatarUrl từ backend
                              backgroundImage: user['avatarUrl'] != null
                                  ? NetworkImage(user['avatarUrl'])
                                  : null,
                              child: (iot.isUploading)
                                  ? const CircularProgressIndicator(
                                      color: Color(
                                          0xFF00D2FF)) // Hiện loading khi đang upload
                                  : (user['avatarUrl'] == null
                                      ? const Icon(Icons.person,
                                          color: Color(0xFF00D2FF), size: 40)
                                      : null),
                            ),
                          ),
                          // Line-by-line: Nút Camera nhỏ ở góc ảnh
                          const Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFF00D2FF),
                              child: Icon(Icons.camera_alt,
                                  size: 12, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                        user['displayName']?.toString().toUpperCase() ??
                            "NGƯỜI DÙNG MỚI",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D2FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF00D2FF).withOpacity(0.3)),
                      ),
                      child: Text(
                          user['role']?.toString().toUpperCase() ??
                              "THÀNH VIÊN",
                          style: const TextStyle(
                              color: Color(0xFF00D2FF),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // --- KHỐI THÔNG TIN CÁ NHÂN ---
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(" THÔNG TIN CÁ NHÂN",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildInfoItem(context, Icons.badge_outlined, "displayName",
                        "Họ và tên", user['displayName'] ?? "Chưa có tên"),
                    Divider(
                        color: Colors.white.withOpacity(0.05),
                        height: 1,
                        indent: 50),
                    _buildInfoItem(context, Icons.work_outline, "role",
                        "Chức vụ", user['role'] ?? "Kỹ sư"),
                    Divider(
                        color: Colors.white.withOpacity(0.05),
                        height: 1,
                        indent: 50),
                    _buildInfoItem(context, Icons.cake_outlined, "age", "Tuổi",
                        user['age']?.toString() ?? "0"),
                    Divider(
                        color: Colors.white.withOpacity(0.05),
                        height: 1,
                        indent: 50),
                    _buildInfoItem(
                        context,
                        Icons.phone_android_outlined,
                        "phone",
                        "Số điện thoại",
                        user['phone'] ?? "Chưa có số"),
                    Divider(
                        color: Colors.white.withOpacity(0.05),
                        height: 1,
                        indent: 50),
                    _buildInfoItem(context, Icons.email_outlined, "email",
                        "Email", user['email'] ?? "Chưa có email"),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- KHỐI HỆ THỐNG ---
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(" CÀI ĐẶT HỆ THỐNG",
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: SwitchListTile(
                  secondary: Icon(
                    iot.isNotificationEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    color: iot.isNotificationEnabled
                        ? const Color(0xFF00D2FF)
                        : Colors.white38,
                  ),
                  title: const Text("Thông báo đẩy (FCM)",
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  activeColor: const Color(0xFF00D2FF),
                  value: iot.isNotificationEnabled,
                  onChanged: (bool value) async {
                    await context
                        .read<IotProvider>()
                        .toggleNotificationPermission(value);
                  },
                ),
              ),

              const SizedBox(height: 40),

              // --- NÚT ĐĂNG XUẤT ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => AuthService().signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text("ĐĂNG XUẤT HỆ THỐNG",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}
