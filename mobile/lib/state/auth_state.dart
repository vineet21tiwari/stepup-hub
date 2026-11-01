import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';

class AuthState extends ChangeNotifier {
  Map<String, dynamic>? user;
  bool loading = true;

  Future<void> bootstrap() async {
    final token = await ApiClient.getToken();
    if (token == null) {
      loading = false;
      notifyListeners();
      return;
    }
    try {
      user = await UserApi.me();
    } catch (_) {
      await ApiClient.setToken(null);
      user = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await AuthApi.login(email, password);
    await ApiClient.setToken(res['token'] as String);
    user = await UserApi.me();
    notifyListeners();
    return user!;
  }

  Future<Map<String, dynamic>> signup(Map<String, dynamic> payload, {String? resumePath}) async {
    final res = await AuthApi.signup(payload, resumePath: resumePath);
    await ApiClient.setToken(res['token'] as String);
    user = await UserApi.me();
    notifyListeners();
    return user!;
  }

  Future<void> refreshMe() async {
    user = await UserApi.me();
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.setToken(null);
    user = null;
    notifyListeners();
  }

  String? get role => user?['role'] as String?;
  int? get userId => user?['id'] as int?;
  bool get isStudent => role == 'STUDENT';
  bool get isTeacher => role == 'TEACHER';
  bool get isCoordinator => role == 'COORDINATOR';
  bool get isAdmin => role == 'ADMIN';
}
