import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// A file to attach to a multipart request — wraps a picked file's path plus the
/// multipart field name the backend's `@RequestPart`/`@RequestParam MultipartFile` expects.
class ApiFile {
  final String field;
  final String path;
  const ApiFile(this.field, this.path);
}

class ApiClient {
  static const _tokenKey = 'stepup_token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Something went wrong. Please try again.';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {
      // ignore parse failure, use default message
    }
    throw ApiException(message);
  }

  /// Runs a request with a timeout and turns low-level network failures (server down, wrong Wi-Fi,
  /// firewall) into one readable message instead of a raw SocketException dump.
  static Future<http.Response> _send(Future<http.Response> Function() request, {Duration timeout = _timeout}) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException(_unreachableMessage);
    } on SocketException {
      throw ApiException(_unreachableMessage);
    } on http.ClientException {
      throw ApiException(_unreachableMessage);
    }
  }

  // Generous enough for a free-tier host waking from sleep (~1 minute on the first request).
  static const _timeout = Duration(seconds: 75);
  static const _uploadTimeout = Duration(minutes: 3);
  static const _unreachableMessage =
      "Can't reach the StepUp Hub server right now. Check your internet connection and try again — if the server was idle it can take up to a minute to wake up.";

  static Future<dynamic> get(String path, {Map<String, String>? query}) async {
    var uri = Uri.parse('$apiBaseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final headers = await _headers();
    return _handle(await _send(() => http.get(uri, headers: headers)));
  }

  static Future<dynamic> post(String path, [Object? body]) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = await _headers();
    return _handle(await _send(() => http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body))));
  }

  static Future<dynamic> put(String path, [Object? body]) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = await _headers();
    return _handle(await _send(() => http.put(uri, headers: headers, body: body == null ? null : jsonEncode(body))));
  }

  static Future<dynamic> delete(String path) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = await _headers();
    return _handle(await _send(() => http.delete(uri, headers: headers)));
  }

  /// multipart/form-data request — mirrors the web client's FormData pattern. `fields` become
  /// plain text parts (for `@RequestParam String`), `jsonParts` become parts with an
  /// `application/json` content type (for the backend's `@RequestPart("data")` DTOs used by
  /// course/signup/assignment endpoints — a plain field would arrive untyped and be rejected as
  /// application/octet-stream), and `files` become file parts.
  static Future<dynamic> multipart(
    String method,
    String path, {
    Map<String, String> fields = const {},
    Map<String, Object> jsonParts = const {},
    List<ApiFile> files = const [],
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final req = http.MultipartRequest(method, uri);
    req.headers.addAll(await _headers(json: false));
    req.fields.addAll(fields);
    jsonParts.forEach((name, value) {
      req.files.add(http.MultipartFile.fromString(name, jsonEncode(value),
          filename: '$name.json', contentType: MediaType('application', 'json')));
    });
    for (final f in files) {
      req.files.add(await http.MultipartFile.fromPath(f.field, f.path));
    }
    return _handle(await _send(() async => http.Response.fromStream(await req.send()), timeout: _uploadTimeout));
  }
}

/// Reads a local file into bytes — used when a picked attachment needs to be shown as a preview
/// before upload (e.g. an image thumbnail) rather than sent straight through.
Future<List<int>> readLocalFile(String path) => File(path).readAsBytes();
