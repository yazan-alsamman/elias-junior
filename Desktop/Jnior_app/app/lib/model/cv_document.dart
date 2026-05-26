import 'package:app/model/ats_check_report.dart';
import 'package:app/model/parsed_cv_profile.dart';

class CVDocument {
  /// Mongo `_id` when loaded from API.
  final String? id;
  /// Links to [CVParsedProfile] row with parser JSON for portfolio.
  final String? profileId;
  final bool hasParsedCv;
  final String fileName;
  final DateTime uploadedAt;
  final ATSCheckReport report;
  /// Parsed text preview shown after upload (mock / extracted content).
  final String contentPreview;
  /// Llama + LoRA parser output when available.
  final ParsedCvProfile? parsedProfile;

  CVDocument({
    this.id,
    this.profileId,
    this.hasParsedCv = false,
    required this.fileName,
    required this.uploadedAt,
    required this.report,
    this.contentPreview = '',
    this.parsedProfile,
  });

  factory CVDocument.fromApi(Map<String, dynamic> json) {
    final Object? rep = json['report'];
    final String raw = (json['extractedText'] as String?) ?? '';
    final String preview = raw.length > 320 ? '${raw.substring(0, 320)}…' : raw;
    return CVDocument(
      id: json['id'] as String?,
      profileId: json['profileId'] as String?,
      hasParsedCv: json['hasParsedCv'] == true,
      fileName: (json['originalFileName'] as String?) ?? 'document',
      uploadedAt: DateTime.tryParse((json['uploadedAt'] as String?) ?? '') ??
          DateTime.now(),
      contentPreview:
          preview.isNotEmpty ? preview : (json['originalFileName'] as String? ?? ''),
      report: rep is Map<String, dynamic>
          ? ATSCheckReport.fromJson(rep)
          : ATSCheckReport.pending(),
      parsedProfile: json['parsedCv'] is Map<String, dynamic>
          ? ParsedCvProfile.fromJson(
              json['parsedCv'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// After `POST /api/cv/documents/upload-analyze` (includes optional `parsedCv`).
  CVDocument copyWith({ATSCheckReport? report, String? contentPreview}) {
    return CVDocument(
      id: id,
      profileId: profileId,
      hasParsedCv: hasParsedCv,
      fileName: fileName,
      uploadedAt: uploadedAt,
      report: report ?? this.report,
      contentPreview: contentPreview ?? this.contentPreview,
      parsedProfile: parsedProfile,
    );
  }

  factory CVDocument.fromUploadResponse(Map<String, dynamic> body) {
    final Map<String, dynamic> docJson =
        body['document'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final CVDocument base = CVDocument.fromApi(docJson);
    final ParsedCvProfile? parsed = body['parsedCv'] is Map<String, dynamic>
        ? ParsedCvProfile.fromJson(body['parsedCv'] as Map<String, dynamic>)
        : null;
    final String preview = parsed != null && parsed.toPreviewMarkdown().isNotEmpty
        ? parsed.toPreviewMarkdown()
        : base.contentPreview;
    return CVDocument(
      id: base.id,
      profileId: body['profileId'] as String? ?? base.profileId,
      hasParsedCv: parsed != null || base.hasParsedCv,
      fileName: base.fileName,
      uploadedAt: base.uploadedAt,
      report: base.report,
      contentPreview: preview,
      parsedProfile: parsed,
    );
  }
}
