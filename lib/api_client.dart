import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  // Local Laravel app served via public/index.php on your LAN IP.
  static const String baseUrl =
      //  'http://192.168.1.5/mse_operators_union/public/index.php';
      'https://testdemo.co.in';

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (bearer != null) {
      headers['Authorization'] = 'Bearer $bearer';
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  Future<Map<String, dynamic>> getJson(String path, {String? bearer}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{};
    if (bearer != null) {
      headers['Authorization'] = 'Bearer $bearer';
    }

    final response = await http.get(uri, headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }
}
