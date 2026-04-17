import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:habit_tracker/services/api_key_service.dart';

/// Exception thrown when the Gemini response cannot be parsed into
/// a valid 30-day habit plan.
class HabitPlanParseException implements Exception {
  final String message;
  final String rawResponse;
  HabitPlanParseException(this.message, {this.rawResponse = ''});

  @override
  String toString() => 'HabitPlanParseException: $message\nRaw: $rawResponse';
}

/// Exception thrown when no API key has been saved in secure storage.
class ApiKeyNotSetException implements Exception {
  @override
  String toString() => 'ApiKeyNotSetException: No Gemini API key configured.';
}

/// Calls the Gemini API to generate a 30-day progressive habit plan.
///
/// The API key is read from [ApiKeyService] (flutter_secure_storage).
/// Go to Settings → AI Settings to enter your key.
class GeminiService {
  static const _modelName = 'gemini-2.5-flash';
  static const _validTypes = {'timer', 'pedometer', 'self_report'};

  /// Generates a 30-day plan for [habitName].
  ///
  /// Throws [ApiKeyNotSetException] if no key has been saved yet.
  /// Throws [HabitPlanParseException] if the response cannot be parsed.
  Future<({List<Map<String, dynamic>> days, List<String> links})>
  generateHabitPlan(String habitName) async {
    // ── Read API key from secure storage ────────────────────────────
    final apiKey = await ApiKeyService.instance.getApiKey();
    if (apiKey == null) {
      throw ApiKeyNotSetException();
    }

    final model = GenerativeModel(model: _modelName, apiKey: apiKey);

    final prompt =
        '''
You are a habit coach. Generate a 30-day progressive plan for the habit: $habitName.
For each day return a JSON object with these exact fields:
  day (int),
  durationMinutes (int),
  taskDescription (String),
  tip (String),
  validationType (String - must be one of: timer, pedometer, self_report),
  stepTarget (int or null - only set if validationType is pedometer, otherwise null).

Choose validationType intelligently:
  use timer for mindfulness/focus/skill habits,
  use pedometer for walking/running/movement habits,
  use self_report for reading/journaling/diet habits.

Also return a top-level field called referenceLinks as a list of 2 real YouTube URLs related to this habit.
Return a single JSON object with two keys:
  "plan": [ ...30 day objects... ],
  "referenceLinks": [ "url1", "url2" ]
IMPORTANT: Must be strictly valid JSON. Do NOT include trailing commas. Do not include markdown fences.
''';

    final response = await model.generateContent([Content.text(prompt)]);

    // ── Debug print (raw response before any parsing) ──────────────────
    final rawJson = response.text ?? '';
    debugPrint('[GeminiService] Raw response:\n$rawJson');
    // ──────────────────────────────────────────────────────────────────

    if (rawJson.isEmpty) {
      throw HabitPlanParseException('Empty response from Gemini API.');
    }

    // ── Clean up the response ─────────────────────────────────────────
    // 1. Strip markdown code fences
    var cleaned = rawJson
        .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*', multiLine: true), '')
        .trim();

    // 2. If there is preamble text before the JSON, extract from the
    //    first JSON delimiter found.
    final jsonStart = cleaned.indexOf(RegExp(r'[\[{]'));
    if (jsonStart > 0) cleaned = cleaned.substring(jsonStart);

    // 3. Remove trailing commas before closing braces/brackets that break standard JSON.
    // E.g. replace ",]" with "]" and ",}" with "}"
    cleaned = cleaned
        .replaceAll(RegExp(r',\s*}'), '}')
        .replaceAll(RegExp(r',\s*]'), ']');

    // ── Decode JSON ───────────────────────────────────────────────────
    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (e) {
      throw HabitPlanParseException(
        'JSON decode failed: $e',
        rawResponse: rawJson,
      );
    }

    // ── Normalise response shape ──────────────────────────────────────
    // The model sometimes returns just the plan array instead of the
    // expected wrapper object {"plan": [...], "referenceLinks": [...]}.
    List<dynamic> planRaw;
    List<dynamic> linksRaw = [];

    if (decoded is List) {
      // Model returned a bare array — treat it as the plan directly.
      debugPrint('[GeminiService] Response was a bare array; adapting.');
      planRaw = decoded;
    } else if (decoded is Map) {
      planRaw = (decoded['plan'] as List?) ?? [];
      linksRaw = (decoded['referenceLinks'] as List?) ?? [];
    } else {
      throw HabitPlanParseException(
        'Response is neither a JSON object nor a JSON array.',
        rawResponse: rawJson,
      );
    }

    if (planRaw.isEmpty) {
      throw HabitPlanParseException(
        'Plan array is empty.',
        rawResponse: rawJson,
      );
    }

    // Warn if not exactly 30 days but don't hard-fail.
    if (planRaw.length != 30) {
      debugPrint(
        '[GeminiService] Warning: expected 30 days, got ${planRaw.length}.',
      );
    }

    // ── Validate and collect day entries ──────────────────────────────
    final days = <Map<String, dynamic>>[];
    for (int i = 0; i < planRaw.length; i++) {
      final entry = planRaw[i];
      if (entry is! Map) {
        throw HabitPlanParseException(
          'Day ${i + 1} is not a JSON object.',
          rawResponse: rawJson,
        );
      }
      final dayMap = Map<String, dynamic>.from(entry);

      // Validate required fields
      for (final field in [
        'day',
        'durationMinutes',
        'taskDescription',
        'tip',
        'validationType',
      ]) {
        if (!dayMap.containsKey(field)) {
          throw HabitPlanParseException(
            'Day ${i + 1} missing required field "$field".',
            rawResponse: rawJson,
          );
        }
      }

      final vt = dayMap['validationType'] as String?;
      if (vt == null || !_validTypes.contains(vt)) {
        // Default to self_report instead of hard-failing the whole plan.
        debugPrint(
          '[GeminiService] Day ${i + 1}: invalid validationType "$vt", defaulting to self_report.',
        );
        dayMap['validationType'] = 'self_report';
        dayMap['stepTarget'] = null;
      }

      days.add(dayMap);
    }

    // ── Parse referenceLinks ──────────────────────────────────────────
    final links = <String>[];
    for (final l in linksRaw) {
      if (l is String && l.isNotEmpty) links.add(l);
    }

    return (days: days, links: links);
  }
}
