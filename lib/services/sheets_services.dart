import 'dart:convert';
import 'package:http/http.dart' as http;

class SheetsService {
  static const _baseUrl = 'https://script.google.com/macros/s/AKfycbwsBmsAa7OuzmEuqwyuy75hcYBlgVcB-EEcUZTkUPVLjEW_94Or_7GlCvFgvFgBJHiTJA/exec'; // tu URL
  static const _token = 'mibodasecreta2025'; // el mismo TOKEN del script

  static Future<List<dynamic>> search(String query) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'action': 'search',
      'q': query,
      'token': _token,
    });
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
    });
    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      throw Exception("Error buscando invitados");
    }
  }

  static Future<Map<String, dynamic>?> getGuest(String name) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'action': 'guest',
      'name': name,
      'token': _token,
    });
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
    });
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data is Map<String, dynamic> ? data : null;
    } else {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> confirm(String name, {int consume = 1}) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'token': _token,
    });
    final body = json.encode({
      "action": "confirm",
      "name": name,
      "consume": consume,
      "token": _token
    });
    final res = await http.post(uri, body: body, headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    });
    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      return null;
    }
  }

  static Future<bool> status() async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'action': 'status',
      'token': _token,
    });
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
    });
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data["hasAnyGuestsLeft"] ?? false;
    } else {
      return false;
    }
  }
}
