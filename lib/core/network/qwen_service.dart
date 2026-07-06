import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Client for the Memory Agent's chat backend.
///
/// IMPORTANT: This calls the app's own backend proxy (`/api/chat` on Vercel,
/// or the equivalent route on the Node server used for Docker / Alibaba
/// Cloud deployments) instead of calling Dashscope directly. Calling
/// Dashscope directly from the Flutter *web* client would require bundling
/// the Qwen API key into the compiled JavaScript, which would expose the
/// secret to anyone who opens devtools. The backend proxy keeps the API key
/// server-side only.
class QwenService {
  /// Base URL of this app's own backend. Defaults to a relative path so it
  /// automatically targets whichever host served the web app. Override only
  /// if the API is hosted on a different origin.
  final String baseUrl;

  QwenService({this.baseUrl = ''});

  /// Sends a chat request to the backend, which forwards it to Qwen.
  Future<String> sendMessage({
    required String prompt,
    List<Map<String, dynamic>>? history,
  }) async {
    try {
      final messages = [
        {
          "role": "system",
          "content": "You are Memory Agent, a helpful AI assistant integrated into a mobile app.",
        },
        if (history != null) ...history,
        {"role": "user", "content": prompt},
      ];

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "model": "qwen-turbo",
              "input": {"messages": messages},
              "parameters": {"result_format": "message"},
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['output']['choices'][0]['message']['content'] as String;
      } else {
        throw Exception("Chat API Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Qwen Service Error: $e");
      rethrow;
    }
  }
}
