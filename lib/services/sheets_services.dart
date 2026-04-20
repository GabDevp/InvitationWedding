import 'dart:convert';
import 'package:http/http.dart' as http;

class SheetsService {
  static const _scriptUrl ='https://script.google.com/macros/s/AKfycbz0s2q6q6axMxPbmdk_GElZE3prcLB7AfncEfG9XAv0AVHNKFOI2Wggzwn-Dx786QgXjw/exec';

  static const _token = 'babyshower';

  // 🔥 BASE REQUEST (BIEN HECHO)
  static Future<dynamic> _get(Map<String, String> params) async {
    // 1. URL real
    final original = Uri.parse(_scriptUrl).replace(queryParameters: {
      ...params,
      'token': _token,
    });

    // 2. pasar al proxy
    // final proxyUrl = Uri.parse(
    //   'https://corsproxy.io/?${Uri.encodeComponent(original.toString())}',
    // );

    final res = await http.get(original);

    if (res.statusCode != 200) {
      throw Exception('Error HTTP: ${res.statusCode}');
    }

    return jsonDecode(res.body);
  }

  // 🔹 SEARCH
  static Future<List<Map<String, dynamic>>> search(String query) async {
    final data = await _get({
      'action': 'search',
      'q': query,
    });

    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }

    return [];
  }

  // 🔹 GET GUEST
  static Future<Map<String, dynamic>?> getGuest(String name) async {
    final data = await _get({
      'action': 'guest',
      'name': name,
    });

    if (data == null) return null;

    return Map<String, dynamic>.from(data);
  }

  // CONFIRM
  static Future<Map<String, dynamic>?> confirm(String name,
      {int consume = 1}) async {
    final data = await _get({
      'action': 'confirm',
      'name': name,
      'consume': consume.toString(),
    });

    if (data == null) return null;

    return Map<String, dynamic>.from(data);
  }

  // DECLINE
  static Future<Map<String, dynamic>?> noConfirm(String name,
      {int consume = 1}) async {
    final data = await _get({
      'action': 'decline',
      'name': name,
      'consume': consume.toString(),
    });

    if (data == null) return null;

    return Map<String, dynamic>.from(data);
  }

  // STATUS
  static Future<bool> status() async {
    final data = await _get({
      'action': 'status',
    });

    if (data == null) return false;

    return data['hasAny'] == true;
  }
}