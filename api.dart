import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Тот же адрес Apps Script, что и у сайта (константа API в index.html).
const apiUrl =
    'https://script.google.com/macros/s/AKfycbwSe1I-p3TTpHsFWpC3RAg7ZhaI5t_hbOwOoghcOwf7O117Bzl7oy3E3nRIfWoydcBN/exec';

/// Пароль хранится на сервере как sha256("логин:пароль"), как и на сайте.
String sha(String s) => sha256.convert(utf8.encode(s)).toString();

String imgUrl(String id, [int w = 800]) => 'https://lh3.googleusercontent.com/d/$id=w$w';

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => message;
}

class Api {
  static Map<String, dynamic>? user;
  static String? get token => user?['t'] as String?;

  /// Сообщает экранам, что пользователь вошёл или вышел (нужно, чтобы показать телефоны).
  static final ValueNotifier<int> auth = ValueNotifier(0);

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('user');
    if (s != null) user = Map<String, dynamic>.from(jsonDecode(s));
  }

  static Future<void> save(Map<String, dynamic>? u) async {
    user = u;
    final p = await SharedPreferences.getInstance();
    if (u == null) {
      await p.remove('user');
    } else {
      await p.setString('user', jsonEncode(u));
    }
    auth.value++;
  }

  static Future<Map<String, dynamic>> call(String a, [Map<String, dynamic> d = const {}]) async {
    final body = jsonEncode({'a': a, 't': token, ...d});
    http.Response r;
    try {
      r = await http.post(Uri.parse(apiUrl),
          headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: body);
      // Apps Script отвечает редиректом на адрес с результатом: идём по нему вручную.
      if ([301, 302, 303, 307, 308].contains(r.statusCode) && r.headers['location'] != null) {
        r = await http.get(Uri.parse(r.headers['location']!));
      }
    } catch (_) {
      throw ApiError('Нет связи с сервером. Проверьте интернет');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (j['ok'] != true) {
      if (j['err'] == 'auth') await save(null);
      throw ApiError('${j['err'] ?? 'Ошибка'}');
    }
    return j;
  }
}

class Ad {
  final Map<String, dynamic> j;
  Ad(this.j);
  String get id => '${j['id']}';
  String get title => '${j['title'] ?? ''}';
  String get type => '${j['type'] ?? ''}';
  String get category => '${j['category'] ?? ''}';
  String get city => '${j['city'] ?? ''}';
  String get desc => '${j['desc'] ?? ''}';
  String get phone => '${j['phone'] ?? ''}';
  String get author => '${j['author'] ?? ''}';
  int get ts => (j['ts'] as num?)?.toInt() ?? 0;
  List<String> get imgs => ((j['imgs'] as List?) ?? []).map((e) => '$e').toList();

  String get pay {
    final v = '${j['pay'] ?? ''}'.trim();
    if (v.isEmpty) return 'Договорная';
    return RegExp(r'^\d[\d\s.,]*$').hasMatch(v) ? '$v ₽' : v;
  }

  String get date {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    String t(int n) => n.toString().padLeft(2, '0');
    return '${t(d.day)}.${t(d.month)}.${d.year}, ${t(d.hour)}:${t(d.minute)}';
  }
}
