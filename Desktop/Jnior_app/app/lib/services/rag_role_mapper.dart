import 'package:app/model/parsed_cv_profile.dart';

/// Maps free-text job titles + CV content to RAG KB `target_role` ids.
abstract final class RagRoleMapper {
  static const String defaultRole = 'backend_engineer';

  static const List<RagRoleOption> knownRoles = <RagRoleOption>[
    RagRoleOption('backend_engineer', 'Backend Engineer'),
    RagRoleOption('frontend_engineer', 'Frontend Engineer'),
    RagRoleOption('fullstack_engineer', 'Full-Stack Engineer'),
    RagRoleOption('mobile_app_developer', 'Mobile Developer'),
    RagRoleOption('data_engineer', 'Data Engineer'),
    RagRoleOption('data_analyst', 'Data Analyst'),
    RagRoleOption('data_scientist', 'Data Scientist'),
    RagRoleOption('ml_engineer', 'ML Engineer'),
    RagRoleOption('devops_engineer', 'DevOps Engineer'),
    RagRoleOption('site_reliability_engineer', 'Site Reliability Engineer'),
    RagRoleOption('cloud_engineer', 'Cloud Engineer'),
    RagRoleOption('product_manager_tech', 'Product Manager (Tech)'),
    RagRoleOption('qa_engineer', 'QA Engineer'),
    RagRoleOption('cybersecurity_analyst', 'Cybersecurity Analyst'),
    RagRoleOption('penetration_tester', 'Penetration Tester'),
    RagRoleOption('database_administrator', 'Database Administrator'),
    RagRoleOption('network_engineer', 'Network Engineer'),
    RagRoleOption('ui_ux_designer', 'UI/UX Designer'),
    RagRoleOption('ai_engineer', 'AI Engineer'),
    RagRoleOption('system_administrator', 'System Administrator'),
  ];

  static const List<(String role, List<String> keywords)> _rules =
      <(String, List<String>)>[
    ('product_manager_tech', <String>[
      'product manager',
      'product owner',
      'product management',
      'pm ',
      'prd',
      'roadmap',
    ]),
    ('data_engineer', <String>['data engineer', 'etl', 'warehouse', 'dbt']),
    ('data_scientist', <String>['data scientist', 'machine learning scientist']),
    ('data_analyst', <String>['data analyst', 'business analyst', 'analytics']),
    ('ml_engineer', <String>['ml engineer', 'machine learning', 'deep learning']),
    ('ai_engineer', <String>['ai engineer', 'generative ai', 'llm']),
    ('devops_engineer', <String>['devops', 'platform engineer', 'ci/cd', 'sre']),
    ('site_reliability_engineer', <String>['site reliability']),
    ('cloud_engineer', <String>['cloud engineer', 'aws architect', 'azure engineer']),
    ('cybersecurity_analyst', <String>['security analyst', 'cybersecurity', 'soc ']),
    ('penetration_tester', <String>['penetration', 'pentest', 'ethical hacker']),
    ('qa_engineer', <String>['qa ', 'quality assurance', 'test engineer']),
    (
      'frontend_engineer',
      <String>[
        'frontend',
        'front-end',
        'javascript',
        'typescript',
        'react',
        'vue',
        'angular',
      ],
    ),
    ('mobile_app_developer', <String>['mobile', 'ios', 'android', 'flutter dev']),
    (
      'fullstack_engineer',
      <String>[
        'full stack',
        'fullstack',
        'full-stack',
        'junior software',
        'junior developer',
        'software developer',
      ],
    ),
    ('backend_engineer', <String>[
      'backend',
      'back-end',
      'api engineer',
      'java dev',
    ]),
    ('database_administrator', <String>['dba', 'database admin']),
    ('network_engineer', <String>['network engineer', 'network admin']),
    ('ui_ux_designer', <String>['ux ', 'ui ', 'designer', 'user experience']),
    ('system_administrator', <String>['sysadmin', 'system admin']),
  ];

  /// Priority: manual KB role → job title/description → CV headline/skills → default.
  static String inferTargetRole({
    required String jobTitle,
    String jobDescription = '',
    String? overrideRole,
    ParsedCvProfile? cvProfile,
  }) {
    if (overrideRole != null && overrideRole.trim().isNotEmpty) {
      return _normalizeRoleId(overrideRole);
    }

    final String jobHaystack =
        '${jobTitle.toLowerCase()} ${jobDescription.toLowerCase()}';
    final String? fromJob = _matchRole(jobHaystack, allowWeak: false);
    if (fromJob != null) {
      return fromJob;
    }

    if (cvProfile != null) {
      final String cvHaystack = <String>[
        cvProfile.headline,
        cvProfile.summary,
        cvProfile.skills.join(' '),
        ...cvProfile.experience.map(
          (Map<String, dynamic> e) =>
              '${e['position'] ?? ''} ${e['company'] ?? ''}',
        ),
      ].join(' ').toLowerCase();
      final String? fromCv = _matchRole(cvHaystack, allowWeak: true);
      if (fromCv != null) {
        return fromCv;
      }
    }

    if (jobTitle.trim().isNotEmpty) {
      return defaultRole;
    }
    return defaultRole;
  }

  static String? _matchRole(String haystack, {required bool allowWeak}) {
    if (haystack.trim().isEmpty) {
      return null;
    }
    for (final (String role, List<String> keys) in _rules) {
      for (final String key in keys) {
        if (haystack.contains(key)) {
          return role;
        }
      }
    }
    if (!allowWeak) {
      return null;
    }
    return null;
  }

  static String _normalizeRoleId(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  static String labelForRole(String role) {
    final String key = _normalizeRoleId(role);
    for (final RagRoleOption o in knownRoles) {
      if (o.role == key) {
        return o.label;
      }
    }
    return key.replaceAll('_', ' ');
  }
}

class RagRoleOption {
  const RagRoleOption(this.role, this.label);
  final String role;
  final String label;
}
