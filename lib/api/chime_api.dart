import 'dart:convert';
import 'package:http/http.dart' as http;

class ChimeApi {
  static const String baseUrl = 'https://assess.hipster-dev.com/api';
  static const String defaultApiKey = 'rlN5zr6YKn1MKvqCJu8s';

  static Map<String, String> _getHeaders(String apiKey) => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey.isEmpty ? defaultApiKey : apiKey,
        'Accept': 'application/json',
      };

  /// Creates a new meeting. Returns the response map containing meeting and attendee data.
  static Future<Map<String, dynamic>> createMeeting({required String apiKey}) async {
    final uri = Uri.parse('$baseUrl/meetings').replace(queryParameters: {
      'type': 'agent',
    });

    final body = jsonEncode({
      'type': 'agent',
    });

    final response = await _postWithRetry(
      uri,
      headers: _getHeaders(apiKey),
      body: body,
    );

    return _parseResponse(response);
  }

  /// Joins an existing meeting as either 'client' or 'agent'.
  /// Returns the response map containing meeting and attendee data.
  static Future<Map<String, dynamic>> joinMeeting({
    required String meetingId,
    required String role, // 'agent' or 'client'
    required String apiKey,
  }) async {
    final uri = Uri.parse('$baseUrl/meetings').replace(queryParameters: {
      'type': role,
      'meeting_id': meetingId,
    });

    final body = jsonEncode({
      'type': role,
      'meeting_id': meetingId,
    });

    final response = await _postWithRetry(
      uri,
      headers: _getHeaders(apiKey),
      body: body,
    );

    return _parseResponse(response);
  }

  /// Performs an HTTP POST request with automatic retries and exponential backoff for 429 rate limit errors.
  static Future<http.Response> _postWithRetry(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    int maxRetries = 3,
  }) async {
    int delayMs = 1500; // Start with a 1.5s delay
    for (int i = 0; i <= maxRetries; i++) {
      try {
        final response = await http.post(uri, headers: headers, body: body);
        if (response.statusCode != 429 || i == maxRetries) {
          return response;
        }
      } catch (e) {
        if (i == maxRetries) rethrow;
      }
      // Wait before retrying
      await Future.delayed(Duration(milliseconds: delayMs));
      delayMs *= 2; // Exponential backoff (1.5s -> 3s -> 6s)
    }
    throw Exception('Request failed due to rate limits');
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Body is not JSON, ignore parsing
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded != null && decoded['status'] == 'success') {
        return decoded['data'] as Map<String, dynamic>;
      } else {
        throw Exception(decoded?['message'] ?? 'API Error');
      }
    } else {
      if (decoded != null && decoded['message'] != null) {
        throw Exception(decoded['message']);
      }
      if (response.statusCode == 429) {
        throw Exception('Rate limit exceeded (429). Please wait a moment and try again.');
      }
      throw Exception('Server Error: ${response.statusCode}');
    }
  }
}
