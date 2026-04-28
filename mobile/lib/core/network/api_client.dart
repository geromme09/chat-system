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

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    String? fileField,
    String? filePath,
    String? authToken,
  }) async {
    return _sendMultipart(
      method: 'POST',
      path: path,
      fields: fields,
      fileField: fileField,
      filePath: filePath,
      authToken: authToken,
    );
  }

  Future<Map<String, dynamic>> putMultipart(
    String path, {
    required Map<String, String> fields,
    String? fileField,
    String? filePath,
    String? authToken,
  }) async {
    return _sendMultipart(
      method: 'PUT',
      path: path,
      fields: fields,
      fileField: fileField,
      filePath: filePath,
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

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? queryParameters,
    Object? body,
    String? authToken,
  }) async {
    return _send(
      method: 'DELETE',
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
        'DELETE' => await client.deleteUrl(uri),
        _ => await client.getUrl(uri),
      };
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (authToken != null && authToken.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      }
      if (body != null) {
        final encodedBody = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.headers.contentLength = encodedBody.length;
        request.add(encodedBody);
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

  Future<Map<String, dynamic>> _sendMultipart({
    required String method,
    required String path,
    required Map<String, String> fields,
    String? fileField,
    String? filePath,
    String? authToken,
  }) async {
    final baseUri = Uri.parse(baseUrl);
    final uri = baseUri.resolve(path);
    final client = HttpClient();
    final boundary = '----chat-system-${DateTime.now().microsecondsSinceEpoch}';

    try {
      final request = switch (method) {
        'PUT' => await client.putUrl(uri),
        _ => await client.postUrl(uri),
      };
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );
      if (authToken != null && authToken.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      }

      void writeString(String value) {
        request.add(utf8.encode(value));
      }

      for (final entry in fields.entries) {
        writeString('--$boundary\r\n');
        writeString(
          'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n',
        );
        writeString('${entry.value}\r\n');
      }

      if (fileField != null &&
          filePath != null &&
          filePath.trim().isNotEmpty) {
        final file = File(filePath);
        final filename = file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'upload.jpg';
        final contentType = _contentTypeForFilename(filename);
        writeString('--$boundary\r\n');
        writeString(
          'Content-Disposition: form-data; name="$fileField"; filename="$filename"\r\n',
        );
        writeString('Content-Type: $contentType\r\n\r\n');
        await request.addStream(file.openRead());
        writeString('\r\n');
      }

      writeString('--$boundary--\r\n');

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

  String _contentTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
