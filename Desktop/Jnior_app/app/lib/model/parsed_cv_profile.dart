/// Structured CV JSON from the Llama + LoRA parser (`cv-parser` Uvicorn service).
class ParsedCvProfile {
  ParsedCvProfile({
    this.displayName = '',
    this.headline = '',
    this.summary = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.skills = const <String>[],
    this.experience = const <Map<String, dynamic>>[],
    this.education = const <Map<String, dynamic>>[],
    this.projects = const <Map<String, dynamic>>[],
    this.certifications = const <String>[],
  });

  final String displayName;
  final String headline;
  final String summary;
  final String email;
  final String phone;
  final String location;
  final List<String> skills;
  final List<Map<String, dynamic>> experience;
  final List<Map<String, dynamic>> education;
  final List<Map<String, dynamic>> projects;
  final List<String> certifications;

  /// True when this profile has enough data to render the portfolio preview.
  bool get hasPortfolioData =>
      displayName.isNotEmpty ||
      summary.isNotEmpty ||
      skills.isNotEmpty ||
      experience.isNotEmpty ||
      education.isNotEmpty;

  factory ParsedCvProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return ParsedCvProfile();
    }
    final Map<String, dynamic> profile =
        json['profile'] is Map<String, dynamic>
            ? json['profile'] as Map<String, dynamic>
            : <String, dynamic>{};
    final Map<String, dynamic> contact =
        profile['contact'] is Map<String, dynamic>
            ? profile['contact'] as Map<String, dynamic>
            : <String, dynamic>{};

    return ParsedCvProfile(
      displayName: _str(profile['name']),
      headline: _str(profile['headline']),
      summary: _str(profile['summary']),
      email: _str(contact['email']),
      phone: _str(contact['phone']),
      location: _str(profile['location']),
      skills: _stringList(json['skills']),
      experience: _mapList(json['experience']),
      education: _mapList(json['education']),
      projects: _mapList(json['projects']),
      certifications: _stringList(json['certifications']),
    );
  }

  /// Human-readable preview for Results / post-upload UI.
  String toPreviewMarkdown() {
    final StringBuffer buf = StringBuffer();
    if (displayName.isNotEmpty) {
      buf.writeln(displayName.toUpperCase());
      buf.writeln();
    }
    if (headline.isNotEmpty) {
      buf.writeln(headline);
      buf.writeln();
    }
    if (email.isNotEmpty || phone.isNotEmpty || location.isNotEmpty) {
      final List<String> bits = <String>[
        if (email.isNotEmpty) email,
        if (phone.isNotEmpty) phone,
        if (location.isNotEmpty) location,
      ];
      buf.writeln(bits.join(' · '));
      buf.writeln();
    }
    if (summary.isNotEmpty) {
      buf.writeln('SUMMARY');
      buf.writeln(summary);
      buf.writeln();
    }
    if (skills.isNotEmpty) {
      buf.writeln('SKILLS');
      buf.writeln(skills.join(', '));
      buf.writeln();
    }
    if (experience.isNotEmpty) {
      buf.writeln('EXPERIENCE');
      for (final Map<String, dynamic> item in experience.take(8)) {
        buf.writeln('• ${_experienceLine(item)}');
      }
      buf.writeln();
    }
    if (education.isNotEmpty) {
      buf.writeln('EDUCATION');
      for (final Map<String, dynamic> item in education.take(5)) {
        buf.writeln('• ${_educationLine(item)}');
      }
      buf.writeln();
    }
    if (projects.isNotEmpty) {
      buf.writeln('PROJECTS');
      for (final Map<String, dynamic> item in projects.take(6)) {
        buf.writeln('• ${_projectLine(item)}');
      }
    }
    return buf.toString().trim();
  }

  static String _str(Object? v) => v == null ? '' : v.toString().trim();

  static List<String> _stringList(Object? raw) {
    if (raw is! List) {
      return <String>[];
    }
    return raw
        .map((dynamic e) => e?.toString().trim() ?? '')
        .where((String s) => s.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> _mapList(Object? raw) {
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }
    return raw
        .whereType<Map>()
        .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
        .toList();
  }

  static String _experienceLine(Map<String, dynamic> item) {
    final String role = _str(item['role'] ?? item['title']);
    final String company = _str(item['company'] ?? item['employer']);
    final String duration = _str(item['duration'] ?? item['dates']);
    final String parts = <String>[
      if (role.isNotEmpty && company.isNotEmpty) '$role @ $company',
      if (role.isNotEmpty && company.isEmpty) role,
      if (role.isEmpty && company.isNotEmpty) company,
      if (duration.isNotEmpty) duration,
    ].join(' | ');
    return parts.isEmpty ? item.toString() : parts;
  }

  static String _educationLine(Map<String, dynamic> item) {
    final String degree = _str(item['degree']);
    final String school = _str(item['school'] ?? item['institution']);
    final String year = _str(item['year'] ?? item['duration']);
    return <String>[
      if (degree.isNotEmpty) degree,
      if (school.isNotEmpty) school,
      if (year.isNotEmpty) year,
    ].join(' — ');
  }

  static String _projectLine(Map<String, dynamic> item) {
    final String name = _str(item['name'] ?? item['title']);
    final String desc = _str(item['description']);
    if (name.isEmpty) {
      return desc.isEmpty ? item.toString() : desc;
    }
    return desc.isEmpty ? name : '$name — $desc';
  }
}
