import 'package:app/common/api_config.dart';
import 'package:app/common/app_colors.dart';
import 'package:app/common/app_typography.dart';
import 'package:app/services/local_ats_service.dart';
import 'package:app/services/local_cv_parser_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Debug-only: shows Hostinger storage API + local ATS/parser reachability.
class DevApiBanner extends StatefulWidget {
  const DevApiBanner({super.key});

  @override
  State<DevApiBanner> createState() => _DevApiBannerState();
}

class _DevApiBannerState extends State<DevApiBanner> {
  String? _atsLine;
  String? _parserLine;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _loadLocalServices();
    }
  }

  Future<void> _loadLocalServices() async {
    final bool atsOk = await LocalAtsService.instance.ping();
    final bool parserOk = await LocalCvParserService.instance.ping();
    if (!mounted) return;
    setState(() {
      _atsLine = atsOk
          ? 'Local ATS OK (${ApiConfig.atsBaseUrl}) — real scores on upload'
          : 'Local ATS offline — run .\\start-local-dev.cmd (${ApiConfig.atsBaseUrl})';
      _parserLine = parserOk
          ? 'Local CV parser OK (${ApiConfig.cvParserBaseUrl})'
          : 'CV parser offline (${ApiConfig.cvParserBaseUrl}) — ATS still works';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AuroraDark.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AuroraDark.cyanBright.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Storage API: ${ApiConfig.baseUrl}',
            style: AppType.labelMedium.copyWith(color: AuroraDark.cyanBright),
          ),
          if (_atsLine != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              _atsLine!,
              style: AppType.bodySmall.copyWith(color: AuroraDark.textSecondary),
            ),
          ],
          if (_parserLine != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              _parserLine!,
              style: AppType.bodySmall.copyWith(color: AuroraDark.textMuted),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Re-upload CV for a new score (old rows in Mongo may still show 28).',
            style: AppType.bodySmall.copyWith(color: AuroraDark.textMuted),
          ),
        ],
      ),
    );
  }
}
