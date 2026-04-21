import 'dart:convert';
import 'dart:io';

class ApiClient {
  const ApiClient({
    required this.baseUrl,
  });

  final String baseUrl;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    String? authToken,
  }) async {
    return _send(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      authToken: authToken,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    String? authToken,
  }) async {
    return _send(
      method: 'POST',
      path: path,
      queryParameters: queryParameters,
      body: body,
      authToken: authToken,
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    String? authToken,
  }) async {
    return _send(
      method: 'PUT',
      path: path,
      queryParameters: queryParameters,
      body: body,
      authToken: authToken,
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Object? body,
    String? authToken,
  }) async {
    final baseUri = Uri.parse(baseUrl);
    final uri = baseUri.resolveUri(
      Uri(
        path: path,
        queryParameters: queryParameters == null || queryParameters.isEmpty
            ? null
            : queryParameters,
      ),
    );

    final client = HttpClient();
    try {
      final request = switch (method) {
        'POST' => await client.postUrl(uri),
        'PUT' => await client.putUrl(uri),
        _ => await client.getUrl(uri),
      };
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (authToken != null && authToken.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      }
      if (body != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw const HttpException('Unexpected API response format');
      }

      if (response.statusCode >= 400) {
        final error = decoded['error'];
        final message = error is Map<String, dynamic>
            ? error['message'] as String? ?? 'Request failed'
            : 'Request failed';
        throw HttpException(message);
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}
