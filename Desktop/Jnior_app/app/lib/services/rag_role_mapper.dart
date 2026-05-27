/// Maps free-text job titles to RAG KB `target_role` ids.
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

  static String inferTargetRole({
    required String jobTitle,
    String jobDescription = '',
    String? overrideRole,
  }) {
    if (overrideRole != null && overrideRole.trim().isNotEmpty) {
      return _normalizeRoleId(overrideRole);
    }
    final String haystack =
        '${jobTitle.toLowerCase()} ${jobDescription.toLowerCase()}';
    final List<(String role, List<String> keywords)> rules =
        <(String, List<String>)>[
      ('product_manager_tech', <String>['product manager', 'product owner', 'pm ']),
      ('data_engineer', <String>['data engineer', 'etl', 'warehouse', 'dbt']),
      ('data_scientist', <String>['data scientist', 'machine learning scientist']),
      ('data_analyst', <String>['data analyst', 'business analyst', 'analytics']),
      ('ml_engineer', <String>['ml engineer', 'machine learning', 'deep learning']),
      ('ai_engineer', <String>['ai engineer', 'generative ai', 'llm']),
      ('devops_engineer', <String>['devops', 'platform engineer', 'ci/cd']),
      ('site_reliability_engineer', <String>['sre', 'site reliability']),
      ('cloud_engineer', <String>['cloud engineer', 'aws architect', 'azure engineer']),
      ('cybersecurity_analyst', <String>['security analyst', 'cybersecurity', 'soc ']),
      ('penetration_tester', <String>['penetration', 'pentest', 'ethical hacker']),
      ('qa_engineer', <String>['qa ', 'quality assurance', 'test engineer']),
      ('frontend_engineer', <String>['frontend', 'front-end', 'react', 'vue', 'angular']),
      ('mobile_app_developer', <String>['mobile', 'ios', 'android', 'flutter dev']),
      ('fullstack_engineer', <String>['full stack', 'fullstack', 'full-stack']),
      ('backend_engineer', <String>['backend', 'back-end', 'api engineer', 'java dev']),
      ('database_administrator', <String>['dba', 'database admin']),
      ('network_engineer', <String>['network engineer', 'network admin']),
      ('ui_ux_designer', <String>['ux ', 'ui ', 'designer', 'user experience']),
      ('system_administrator', <String>['sysadmin', 'system admin']),
    ];
    for (final (String role, List<String> keys) in rules) {
      for (final String key in keys) {
        if (haystack.contains(key)) {
          return role;
        }
      }
    }
    return defaultRole;
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
