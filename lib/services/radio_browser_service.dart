import 'dart:convert';
import 'package:http/http.dart' as http;

class RadioBrowserStation {
  final String name;
  final String url;
  final String tags;
  final String country;
  final String favicon;
  final int votes;

  RadioBrowserStation({
    required this.name,
    required this.url,
    required this.tags,
    required this.country,
    required this.favicon,
    required this.votes,
  });

  factory RadioBrowserStation.fromJson(Map<String, dynamic> json) {
    return RadioBrowserStation(
      name: (json['name'] as String? ?? '').trim(),
      url: (json['url_resolved'] as String? ?? json['url'] as String? ?? '')
          .trim(),
      tags: json['tags'] as String? ?? '',
      country: json['country'] as String? ?? '',
      favicon: json['favicon'] as String? ?? '',
      votes: json['votes'] as int? ?? 0,
    );
  }
}

class RadioBrowserService {
  static const _baseUrl = 'https://de1.api.radio-browser.info/json';

  static Future<List<RadioBrowserStation>> searchByTag(
    String tag, {
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/stations/bytag/$tag?limit=$limit&order=votes&reverse=true&hidebroken=true',
    );
    return _fetch(uri);
  }

  static Future<List<RadioBrowserStation>> searchByName(
    String query, {
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/stations/byname/$query?limit=$limit&order=votes&reverse=true&hidebroken=true',
    );
    return _fetch(uri);
  }

  static Future<List<RadioBrowserStation>> _fetch(Uri uri) async {
    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'PahingApp/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final list = jsonDecode(response.body) as List;
      return list
          .map((e) => RadioBrowserStation.fromJson(e as Map<String, dynamic>))
          .where((s) => s.url.isNotEmpty && s.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
