/// Structured "Diagnosis Report" data — mirrors the Diagnosis Result design.
///
/// Gemini is asked for strict JSON; [DiagnosisReport.tryParse] tolerates
/// fenced code blocks and stray whitespace, and returns null when the text
/// is not a valid report (so callers can fall back to plain-text rendering).
library;

import 'dart:convert';

class DiagnosisStep {
  const DiagnosisStep({
    required this.title,
    this.badge = '',
    this.medicine = '',
    this.howTo = '',
    this.dosage = '',
    this.frequency = '',
    this.tip = '',
    this.timing = '',
  });

  final String title;
  final String badge;
  final String medicine;
  final String howTo;
  final String dosage;
  final String frequency;
  final String tip;
  final String timing;

  factory DiagnosisStep.fromJson(Map<String, dynamic> json) => DiagnosisStep(
    title: json['title']?.toString() ?? '',
    badge: json['badge']?.toString() ?? '',
    medicine: json['medicine']?.toString() ?? '',
    howTo: json['howToDo']?.toString() ?? '',
    dosage: json['dosage']?.toString() ?? '',
    frequency: json['frequency']?.toString() ?? '',
    tip: json['tip']?.toString() ?? '',
    timing: json['timing']?.toString() ?? '',
  );
}

class DiagnosisReport {
  const DiagnosisReport({
    required this.plantName,
    required this.diseaseTitle,
    this.latinName = '',
    this.confidencePercent,
    this.observations = '',
    this.caution = '',
    this.duration = '',
    this.sprayInterval = '',
    this.cureRate = '',
    this.steps = const <DiagnosisStep>[],
  });

  final String plantName;
  final String diseaseTitle;
  final String latinName;
  final double? confidencePercent;
  final String observations;
  final String caution;
  final String duration;
  final String sprayInterval;
  final String cureRate;
  final List<DiagnosisStep> steps;

  /// Bengali-ish display value e.g. "৯৭.৮%" when Gemini returns numbers.
  String get confidenceLabel {
    final double? value = confidencePercent;
    if (value == null) return '';
    if (value >= 1) {
      return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}%';
    }
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  /// Parses free-form text into a report, or returns null when it is not
  /// parseable JSON matching the expected schema.
  static DiagnosisReport? tryParse(String raw) {
    String text = raw.trim();
    // Strip markdown code fences if the model wrapped the JSON.
    final RegExp fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final RegExpMatch? fenced = fence.firstMatch(text);
    if (fenced != null) text = fenced.group(1)!.trim();

    final int first = text.indexOf('{');
    final int last = text.lastIndexOf('}');
    if (first == -1 || last <= first) return null;
    text = text.substring(first, last + 1);

    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['diseaseTitle'] is! String) {
      return null;
    }

    final List<DiagnosisStep> steps = <DiagnosisStep>[];
    final dynamic rawSteps = decoded['steps'];
    if (rawSteps is List) {
      for (final dynamic item in rawSteps) {
        if (item is Map) {
          steps.add(DiagnosisStep.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return DiagnosisReport(
      plantName: decoded['plantName']?.toString() ?? '',
      diseaseTitle: decoded['diseaseTitle'].toString(),
      latinName: decoded['latinName']?.toString() ?? '',
      confidencePercent: decoded['confidencePercent'] is num
          ? (decoded['confidencePercent'] as num).toDouble()
          : null,
      observations: decoded['observations']?.toString() ?? '',
      caution: decoded['caution']?.toString() ?? '',
      duration: decoded['duration']?.toString() ?? '',
      sprayInterval: decoded['sprayInterval']?.toString() ?? '',
      cureRate: decoded['cureRate']?.toString() ?? '',
      steps: steps,
    );
  }
}
