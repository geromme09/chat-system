import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class SportsPage {
  const SportsPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.nextPage,
  });

  final List<SportItem> items;
  final int page;
  final int limit;
  final int? nextPage;
}

class SportItem {
  const SportItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
  });

  final String id;
  final String name;
  final String slug;
  final bool isActive;

  factory SportItem.fromJson(Map<String, dynamic> json) {
    return SportItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class SportsApi {
  SportsApi({
    ApiClient? client,
  }) : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);

  final ApiClient _client;

  Future<SportsPage> listSports({
    String query = '',
    int page = 1,
    int limit = 15,
  }) async {
    final response = await _client.get(
      '/api/v1/sports',
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'page': '$page',
        'limit': '$limit',
      },
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Missing data envelope');
    }

    final items = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SportItem.fromJson)
        .toList();

    return SportsPage(
      items: items,
      page: data['page'] as int? ?? page,
      limit: data['limit'] as int? ?? limit,
      nextPage: data['next_page'] as int?,
    );
  }
}
