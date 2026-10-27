import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/diagnosis.dart';

/// Clinical "Diagnosis Result" view — strictly follows the Stitch design:
/// ai-spec strip → leaf card (thumb + SCAN + badges + confidence gauge) →
/// observation box → amber caution notice → 3 telemetry tiles →
/// prescription steps with numbered timeline cards.
class DiagnosisReportView extends StatelessWidget {
  const DiagnosisReportView({
    super.key,
    required this.report,
    this.imageBytes,
    this.reportId = '',
    this.rawText = '',
  });

  final DiagnosisReport report;
  final Uint8List? imageBytes;
  final String reportId;
  final String rawText;

  // Exact palette from the design (the report keeps its light-clinical look
  // regardless of the ambient theme).
  static const Color ink = Color(0xFF0C321D);
  static const Color sub = Color(0xFF436551);
  static const Color body = Color(0xFF284936);
  static const Color line = Color(0xFFC7E8D3);
  static const Color softLine = Color(0xFFE1F3E7);
  static const Color pillar = Color(0xFFBBF7D0);
  static const Color mint = Color(0xFFF0FDF4);
  static const Color mintChip = Color(0xFFDCFCE7);
  static const Color emerald = Color(0xFF047857);
  static const Color emeraldFill = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle label =
        theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _statusStrip(label),
        const SizedBox(height: 14),
        _leafCard(label),
        const SizedBox(height: 12),
        if (report.observations.isNotEmpty)
          _ObservationBox(text: report.observations),
        if (report.observations.isNotEmpty) const SizedBox(height: 12),
        if (report.caution.isNotEmpty) _CautionBox(text: report.caution),
        if (report.caution.isNotEmpty) const SizedBox(height: 12),
        _MetricTiles(
          duration: report.duration,
          interval: report.sprayInterval,
          cure: report.cureRate,
        ),
        const SizedBox(height: 18),
        if (report.steps.isNotEmpty) ...<Widget>[
          Row(
            // prescription section header
            children: <Widget>[
              Expanded(
                child: Text(
                  'প্রেসক্রিপশন ও চিকিৎসা নির্দেশিকা',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: const Color(0xFF235036),
                  ),
                ),
              ),
              _Pill(
                text: '${report.steps.length}টি সহজ ধাপ',
                background: mintChip,
                color: const Color(0xFF065F46),
                border: pillar,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < report.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StepCard(
                index: i + 1,
                step: report.steps[i],
                label: label,
              ),
            ),
        ],
      ],
    );
  }

  Widget _statusStrip(TextStyle label) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: softLine)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: emeraldFill,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${report.plantName.isEmpty ? 'উদ্ভিদ মডেল' : report.plantName} • Gemini Vision',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          Text(
            'MODEL VERIFIED${report.confidencePercent == null ? '' : ' • ${report.confidenceLabel} CONFIDENCE'}',
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.6,
              color: sub,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leafCard(TextStyle label) {
    final double confidence = report.confidencePercent ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F15803D),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Scanned leaf thumbnail + SCAN tag.
              if (imageBytes != null)
                Stack(
                  children: <Widget>[
                    Container(
                      width: 80,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: line),
                        color: mint,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.eco_rounded, color: emerald),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE6065F46),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SCAN',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (imageBytes != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        const _Pill(
                          text: 'রোগ শনাক্ত',
                          background: Color(0xFFFFF1F2),
                          color: Color(0xFFBE123C),
                          border: Color(0xFFFECDD3),
                        ),
                        if (report.confidencePercent != null)
                          _Pill(
                            text: '${report.confidenceLabel} নির্ভুলতা',
                            background: const Color(0xFFECFDF5),
                            color: const Color(0xFF065F46),
                            border: const Color(0xFFA7F3D0),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      report.diseaseTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        height: 1.3,
                      ),
                    ),
                    if (report.latinName.isNotEmpty ||
                        report.plantName.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (report.plantName.isNotEmpty) report.plantName,
                          if (report.latinName.isNotEmpty) report.latinName,
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: sub,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (report.confidencePercent != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          const Text(
                            'কনফিডেন্স স্কোর',
                            style: TextStyle(fontSize: 11, color: sub),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: confidence.clamp(0, 100) / 100,
                                minHeight: 6,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  emeraldFill,
                                ),
                                backgroundColor: mintChip,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            report.confidenceLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.color,
    this.border,
  });

  final String text;
  final Color background;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.6,
        ),
      ),
    );
  }
}

class _ObservationBox extends StatelessWidget {
  const _ObservationBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC7E8D3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.biotech_rounded, size: 18, color: Color(0xFF047857)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Color(0xFF1E3A2B),
                ),
                children: <InlineSpan>[
                  const TextSpan(
                    text: 'লক্ষণ পর্যবেক্ষণ: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0C321D),
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CautionBox extends StatelessWidget {
  const _CautionBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEF3C7)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x08000000), blurRadius: 3),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 19,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Color(0xFF78350F),
                ),
                children: <InlineSpan>[
                  const TextSpan(
                    text: 'সতর্কতা ও প্রধান করণীয়: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTiles extends StatelessWidget {
  const _MetricTiles({
    required this.duration,
    required this.interval,
    required this.cure,
  });

  final String duration;
  final String interval;
  final String cure;

  Widget tile(String heading, String value, {bool highlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight
                ? const Color(0xFFBBF7D0)
                : const Color(0xFFC7E8D3),
          ),
        ),
        child: Column(
          children: <Widget>[
            Text(
              heading.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
                color: highlight
                    ? const Color(0xFF065F46)
                    : const Color(0xFF436551),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: highlight
                    ? const Color(0xFF15803D)
                    : const Color(0xFF0C321D),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        tile('চিকিৎসা মেয়াদ', duration),
        const SizedBox(width: 10),
        tile('স্প্রে ব্যবধান', interval),
        const SizedBox(width: 10),
        tile('নিরাময় সম্ভাবনা', cure, highlight: true),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.step,
    required this.label,
  });

  final int index;
  final DiagnosisStep step;
  final TextStyle label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7E8D3)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A15803D),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  _bengaliNumber(index),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C321D),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C321D),
                  ),
                ),
              ),
              if (step.badge.isNotEmpty)
                _Pill(
                  text: step.badge,
                  background: const Color(0xFFDCFCE7),
                  color: const Color(0xFF065F46),
                  border: const Color(0xFFBBF7D0),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (step.medicine.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                step.medicine,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF065F46),
                ),
              ),
            ),
          if (step.howTo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 3),
              child: Text(
                step.howTo,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Color(0xFF284936),
                ),
              ),
            ),
          if (step.dosage.isNotEmpty || step.frequency.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Row(
                children: <Widget>[
                  if (step.dosage.isNotEmpty)
                    Expanded(
                      child: _MiniField(heading: 'অনুপাত', value: step.dosage),
                    ),
                  if (step.dosage.isNotEmpty && step.frequency.isNotEmpty)
                    const SizedBox(width: 8),
                  if (step.frequency.isNotEmpty)
                    Expanded(
                      child: _MiniField(
                        heading: 'প্রয়োগকাল',
                        value: step.frequency,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (step.tip.isNotEmpty || step.timing.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Row(
                children: <Widget>[
                  if (step.tip.isNotEmpty)
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Color(0xFF047857),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              step.tip,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF436551),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (step.timing.isNotEmpty)
                    Text(
                      step.timing,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF436551),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _bengaliNumber(int value) {
    const List<String> digits = <String>[
      '০',
      '১',
      '২',
      '৩',
      '৪',
      '৫',
      '৬',
      '৭',
      '৮',
      '৯',
    ];
    return value
        .toString()
        .split('')
        .map((String d) => digits[int.parse(d)])
        .join();
  }
}

/// Compact label/value field inside a step card.
class _MiniField extends StatelessWidget {
  const _MiniField({required this.heading, required this.value});

  final String heading;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC7E8D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            heading,
            style: const TextStyle(fontSize: 10, color: Color(0xFF436551)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0C321D),
            ),
          ),
        ],
      ),
    );
  }
}

/// Report header — sticky title with report id pill + copy/share action.
class DiagnosisReportHeader extends StatelessWidget {
  const DiagnosisReportHeader({
    super.key,
    required this.reportId,
    this.rawText = '',
  });

  final String reportId;
  final String rawText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text(
                'রোগ নির্ণয় রিপোর্ট',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0C321D),
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Gemini Clinical Engine',
                style: TextStyle(fontSize: 11, color: Color(0xFF436551)),
              ),
            ],
          ),
        ),
        if (reportId.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Text(
              reportId,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0C321D),
              ),
            ),
          ),
        IconButton(
          tooltip: 'রিপোর্ট কপি করুন',
          icon: const Icon(Icons.share_rounded, size: 18),
          color: const Color(0xFF436551),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: rawText));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('রিপোর্ট কপি হয়েছে')));
          },
        ),
      ],
    );
  }
}
