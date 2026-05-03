import 'package:shared_preferences/shared_preferences.dart';

class PhoneStore {
  static const _phoneKey = 'customer_phone';

  Future<String?> readPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone);
  }
}
