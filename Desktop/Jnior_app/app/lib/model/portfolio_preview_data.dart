import 'dart:math';

import 'package:app/model/parsed_cv_profile.dart';

/// Visual theme for the in-app portfolio preview (5 variants).
enum PortfolioTemplate {
  classic,
  minimal,
  darkNeon,
  warmCreative,
  editorial,
}

extension PortfolioTemplateX on PortfolioTemplate {
  String get label => switch (this) {
        PortfolioTemplate.classic => 'Classic Blue',
        PortfolioTemplate.minimal => 'Minimal',
        PortfolioTemplate.darkNeon => 'Dark Neon',
        PortfolioTemplate.warmCreative => 'Warm Creative',
        PortfolioTemplate.editorial => 'Editorial',
      };

  String get shortDescription => switch (this) {
        PortfolioTemplate.classic =>
          'Bold hero, gradients — great for engineers.',
        PortfolioTemplate.minimal =>
          'Lots of whitespace, calm typography.',
        PortfolioTemplate.darkNeon =>
          'High contrast dark UI with neon accents.',
        PortfolioTemplate.warmCreative =>
          'Rounded cards & warm tones.',
        PortfolioTemplate.editorial =>
          'Magazine-style layout & serif headline.',
      };
}

/// Extracts GitHub login from a pasted profile/repo URL or plain `@user` / `user`.
String? extractGithubUsername(String raw) {
  var s = raw.trim();
  if (s.isEmpty) {
    return null;
  }
  s = s.replaceFirst(RegExp(r'^@'), '');
  final bool plainNoUrl =
      !RegExp(r'[/.]').hasMatch(s) && RegExp(r'^[a-zA-Z0-9_-]{1,39}$').hasMatch(s);
  if (plainNoUrl) {
    return s;
  }
  var url = s;
  if (!url.contains('://')) {
    url = 'https://$url';
  }
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }
  final String host = uri.host.toLowerCase();
  if (!host.endsWith('github.com')) {
    return null;
  }
  final List<String> parts =
      uri.pathSegments.where((String p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    return null;
  }
  if (parts.first == 'orgs' || parts.first == 'settings' || parts.first == 'topics') {
    return null;
  }
  return parts.first;
}

/// Path segment for `github.com/username/<repo>`; keeps user's casing, trims spaces to `-`.
String githubRepoSlug(String projectName) {
  final String t = projectName.trim();
  if (t.isEmpty) {
    return '';
  }
  return t.replaceAll(RegExp(r'\s+'), '-');
}

/// Canonical key for per-project uploads / OG maps (`" online store "` → `"online store"`).
String portfolioProjectKey(String displayName) => displayName.trim();

/// Snapshot for rendering the preview; [fromDummy] fills plausible placeholders until CV/AI JSON exists.
class PortfolioPreviewData {
  const PortfolioPreviewData({
    required this.githubUsername,
    required this.template,
    required this.projectNames,
    required this.projectOgImagesByName,
    required this.projectCustomImagesByName,
    required this.displayName,
    required this.headline,
    required this.bio,
    required this.email,
    required this.phone,
    required this.linkedinUrl,
    required this.location,
    required this.skills,
  });

  final String githubUsername;
  final PortfolioTemplate template;
  final List<String> projectNames;
  /// Repo display name → `https://opengraph.githubassets.com/...` when resolved.
  final Map<String, String> projectOgImagesByName;
  /// User-uploaded JPEG/PNG inlined as data URLs (`data:image/jpeg;base64,...`).
  final Map<String, String> projectCustomImagesByName;
  final String displayName;
  final String headline;
  final String bio;
  final String email;
  final String phone;
  final String linkedinUrl;
  final String location;
  final List<String> skills;

  Uri projectUri(String projectName) {
    final String slug = githubRepoSlug(projectName);
    return Uri(scheme: 'https', host: 'github.com', path: '/$githubUsername/$slug');
  }

  /// `user/repo-slug` for labels (GitHub URL path without host).
  String projectGithubShortPath(String projectName) {
    final String slug = githubRepoSlug(projectName);
    if (slug.isEmpty) {
      return githubUsername.isEmpty ? '' : githubUsername;
    }
    if (githubUsername.isEmpty) {
      return slug;
    }
    return '$githubUsername/$slug';
  }

  Uri get profileUri =>
      Uri(scheme: 'https', host: 'github.com', path: '/$githubUsername');

  static const List<String> _dummyFirstNames = <String>[
    'Layla',
    'Omar',
    'Noor',
    'Karim',
    'Sara',
    'Sam',
    'Huda',
    'Rami',
  ];

  static const List<String> _dummyLastNames = <String>[
    'Haddad',
    'Nasser',
    'El-Amin',
    'Farah',
    'Idris',
    'Volkov',
    'Park',
    'Silva',
  ];

  static const List<String> _dummyRoles = <String>[
    'Full-stack developer',
    'Mobile engineer (Flutter)',
    'Backend engineer',
    'Product-focused engineer',
    'DevOps & platform engineer',
  ];

  static const List<String> _dummyBios = <String>[
    'I ship reliable apps with pragmatic architecture, measurable performance, '
        'and clear communication across design and backend.',
    'Focused on UX polish, typed APIs, and automated testing — from prototype '
        'to production with CI/CD baked in.',
    'Comfortable spanning databases, caches, queues, and client apps; I care '
        'about observability and maintainable docs.',
    'Interested in scalable frontends, design systems, and pairing with stakeholders '
        'to ship iterative value.',
    'I emphasize security basics, predictable releases, and mentoring through code review.',
  ];

  static const List<String> _dummyLocs = <String>[
    'Amman, Jordan · Remote-friendly',
    'Berlin · Hybrid',
    'Dubai · Remote',
    'Toronto · Remote',
    'London · On-site hybrid',
  ];

  static const List<String> _skillPool = <String>[
    'Flutter',
    'Dart',
    'TypeScript',
    'Node.js',
    'PostgreSQL',
    'GraphQL',
    'Docker',
    'Kubernetes',
    'AWS',
    'GCP',
    'Redis',
    'CI/CD',
    'Python',
    'Go',
    'React',
    'Next.js',
  ];

  static String _headlineFromParsed(ParsedCvProfile parsed) {
    if (parsed.headline.isNotEmpty) {
      return parsed.headline;
    }
    if (parsed.experience.isNotEmpty) {
      final Map<String, dynamic> job = parsed.experience.first;
      final String role =
          (job['position'] ?? job['role'] ?? job['title'] ?? '').toString().trim();
      final String company =
          (job['company'] ?? job['employer'] ?? '').toString().trim();
      if (role.isNotEmpty && company.isNotEmpty) {
        return '$role @ $company';
      }
      if (role.isNotEmpty) {
        return role;
      }
    }
    return 'Software engineer';
  }

  /// Build preview from CV parser JSON stored in Mongo (used instead of placeholders).
  factory PortfolioPreviewData.fromParsedProfile({
    required ParsedCvProfile parsed,
    required String githubUsername,
    required PortfolioTemplate template,
    List<String>? projectNames,
    Map<String, String>? projectOgImagesByName,
    Map<String, String>? projectCustomImagesByName,
  }) {
    final List<String> fromCv = parsed.projects
        .map((Map<String, dynamic> p) =>
            (p['name'] ?? p['title'] ?? '').toString().trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    final List<String> projs = (projectNames != null && projectNames.isNotEmpty)
        ? projectNames
            .map((String p) => p.trim())
            .where((String p) => p.isNotEmpty)
            .toList()
        : fromCv;

    return PortfolioPreviewData(
      githubUsername: githubUsername,
      template: template,
      projectNames: projs,
      projectOgImagesByName:
          projectOgImagesByName ?? const <String, String>{},
      projectCustomImagesByName:
          projectCustomImagesByName ?? const <String, String>{},
      displayName:
          parsed.displayName.isNotEmpty ? parsed.displayName : 'Portfolio',
      headline: _headlineFromParsed(parsed),
      bio: parsed.summary.isNotEmpty
          ? parsed.summary
          : 'Professional summary from your uploaded CV.',
      email: parsed.email,
      phone: parsed.phone,
      linkedinUrl: '',
      location: parsed.location,
      skills: parsed.skills.isNotEmpty
          ? parsed.skills.take(24).toList()
          : const <String>['Flutter', 'Dart', 'Git'],
    );
  }

  /// Shown when GitHub is linked but CV JSON / text is not available yet (no fake names).
  static PortfolioPreviewData fromAwaitingCv({
    required String githubUsername,
    required PortfolioTemplate template,
    required List<String> projectNames,
    Map<String, String>? projectOgImagesByName,
    Map<String, String>? projectCustomImagesByName,
  }) {
    final List<String> projs =
        projectNames.map((String p) => p.trim()).where((String p) => p.isNotEmpty).toList();
    return PortfolioPreviewData(
      githubUsername: githubUsername,
      template: template,
      projectNames: projs,
      projectOgImagesByName:
          projectOgImagesByName ?? const <String, String>{},
      projectCustomImagesByName:
          projectCustomImagesByName ?? const <String, String>{},
      displayName: 'Your CV profile',
      headline: 'Upload your CV on the Dashboard',
      bio:
          'We could not load parsed CV data yet. Re-upload your PDF or DOCX after signing in '
          'so your real name, skills, and experience replace this message.',
      email: '',
      phone: '',
      linkedinUrl: '',
      location: '',
      skills: const <String>[
        'Re-upload CV to populate skills',
      ],
    );
  }

  static PortfolioPreviewData fromDummy({
    required String githubUsername,
    required PortfolioTemplate template,
    required List<String> projectNames,
    Map<String, String>? projectOgImagesByName,
    Map<String, String>? projectCustomImagesByName,
  }) {
    final int seed = githubUsername.hashCode.abs();
    final Random r = Random(seed);

    final String first = _dummyFirstNames[r.nextInt(_dummyFirstNames.length)];
    final String last = _dummyLastNames[r.nextInt(_dummyLastNames.length)];
    final List<String> shuffled = List<String>.from(_skillPool)..shuffle(r);
    final int n = 5 + r.nextInt(4);
    final List<String> skills = shuffled.take(n).toList();

    final String inbox = '${githubUsername.toLowerCase()}@mailbox.dev.example';
    final List<String> projs =
        projectNames.map((String p) => p.trim()).where((String p) => p.isNotEmpty).toList();

    return PortfolioPreviewData(
      githubUsername: githubUsername,
      template: template,
      projectNames: projs,
      projectOgImagesByName:
          projectOgImagesByName ?? const <String, String>{},
      projectCustomImagesByName:
          projectCustomImagesByName ?? const <String, String>{},
      displayName: '$first $last',
      headline: _dummyRoles[r.nextInt(_dummyRoles.length)],
      bio: _dummyBios[r.nextInt(_dummyBios.length)],
      email: inbox,
      phone: '+962 7${r.nextInt(90000000) + 10000000}',
      linkedinUrl: 'https://www.linkedin.com/in/${githubUsername.toLowerCase()}-portfolio',
      location: _dummyLocs[r.nextInt(_dummyLocs.length)],
      skills: skills,
    );
  }

  /// Only repositories the user listed (trimmed). No placeholder repos.
  List<String> get effectiveProjects {
    return projectNames
        .map((String p) => p.trim())
        .where((String p) => p.isNotEmpty)
        .toList();
  }

  /// Sent to the API so the public `/p/:slug` page matches this in-app preview.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'displayName': displayName,
        'headline': headline,
        'bio': bio,
        'email': email,
        'phone': phone,
        'linkedinUrl': linkedinUrl,
        'location': location,
        'skills': skills,
        'githubUsername': githubUsername,
        'template': template.name,
        'projectNames': List<String>.from(projectNames),
        'effectiveProjects': effectiveProjects,
        'projectOgImages': Map<String, String>.from(projectOgImagesByName),
        'projectCustomImages':
            Map<String, String>.from(projectCustomImagesByName),
      };
}
