/// Backend base URL.
///
/// - Android emulator: use 10.0.2.2 to reach the host machine's localhost.
/// - iOS simulator / desktop / web: use localhost (or your machine's LAN IP for a real device).
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8080
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);
