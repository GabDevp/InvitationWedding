import 'dart:convert';
import 'package:http/http.dart' as http;

class SheetsService {
  static const _baseUrl = 'https://script.google.com/macros/s/AKfycbzhZaAvc0Al9Ebs-Zx37xD50bvb14AFSIvZ1Myjl53YSp9uIk64t_4_FTxfJGAcqw-HyQ/exec'; // tu URL
  static const _token = 'mibodasecreta210326'; // el mismo TOKEN del script

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
    // Usar GET para evitar preflight CORS en Flutter Web
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'action': 'confirm',
      'name': name,
      'consume': consume.toString(),
      'token': _token,
    });
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
    });
    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> decline(String name) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'action': 'decline',
      'name': name,
      'token': _token,
    });

    final res = await http.get(uri, headers: {
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
