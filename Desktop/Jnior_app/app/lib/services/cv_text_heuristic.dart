import 'package:app/model/parsed_cv_profile.dart';

/// Lightweight résumé text → portfolio JSON (mirrors backend text-heuristic-v1).
abstract final class CvTextHeuristic {
  static final RegExp _emailRe = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  static final RegExp _phoneRe = RegExp(r'(\+?\d[\d\s().-]{6,}\d)');
  static final RegExp _jobLineRe = RegExp(
    r'^(.+?)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*(.+)$',
  );

  static ParsedCvProfile? parseResumeText(String raw) {
    final String text = raw.trim();
    if (text.length < 40) {
      return null;
    }
    final String email = _email(text);
    final String phone = _phone(text);
    final String name = _name(text);
    final String headline = _headline(text, name);
    final String location = _location(text);
    final String summary = _section(
      text,
      const <String>[
        'professional summary',
        'summary',
        'profile',
        'about me',
      ],
    );
    final List<String> skills = _skills(text);
    final List<Map<String, dynamic>> experience = _experience(text);
    final List<Map<String, dynamic>> education = _education(text);

    final ParsedCvProfile profile = ParsedCvProfile.fromJson(<String, dynamic>{
      'profile': <String, dynamic>{
        'name': name,
        'headline': headline,
        'location': location,
        'contact': <String, dynamic>{
          'email': email,
          'phone': phone,
        },
        'summary': summary,
      },
      'skills': skills,
      'experience': experience,
      'education': education,
      'projects': <Map<String, dynamic>>[],
      'certifications': <String>[],
    });
    return profile.hasPortfolioData ? profile : null;
  }

  static String _email(String text) {
    final RegExpMatch? m = _emailRe.firstMatch(text);
    return m?.group(0)?.trim() ?? '';
  }

  static String _phone(String text) {
    for (final String line in text.split('\n').take(25)) {
      if (RegExp(r'phone|mobile|tel', caseSensitive: false).hasMatch(line)) {
        final RegExpMatch? m = _phoneRe.firstMatch(line);
        if (m != null) {
          return m.group(1)!.trim();
        }
      }
    }
    final RegExpMatch? m = _phoneRe.firstMatch(text);
    return m?.group(1)?.trim() ?? '';
  }

  static String _location(String text) {
    final RegExpMatch? m = RegExp(
      r'^\s*location\s*:\s*(.+)$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(text);
    return m?.group(1)?.trim() ?? '';
  }

  static String _name(String text) {
    for (final String line in text.split('\n').take(12)) {
      final String t = line.trim();
      if (t.isEmpty || t.length > 80) {
        continue;
      }
      if (_emailRe.hasMatch(t) || _phoneRe.hasMatch(t)) {
        continue;
      }
      if (RegExp(r'^(email|phone|location|linkedin|github|skills|experience|education)\s*',
              caseSensitive: false)
          .hasMatch(t)) {
        continue;
      }
      if (t.startsWith('•') || t.startsWith('-')) {
        continue;
      }
      if (RegExp(r"^[A-Z][A-Z\s.'-]{2,}$").hasMatch(t)) {
        return t;
      }
      if (RegExp(r"^[A-Z][a-z]+(\s+[A-Z][a-z.'-]+)+$").hasMatch(t)) {
        return t;
      }
      // Parsed-CV preview: first substantive line is often the legal name.
      if (RegExp(r"^[A-Za-z][A-Za-z\s.'-]{2,}$").hasMatch(t) &&
          !RegExp(r'\d').hasMatch(t)) {
        return t;
      }
    }
    return '';
  }

  /// Role line directly under the name (e.g. "Senior Software Engineer").
  static String _headline(String text, String name) {
    final List<String> lines =
        text.split('\n').map((String l) => l.trim()).where((String l) => l.isNotEmpty).toList();
    if (lines.isEmpty) {
      return '';
    }
    final String nameNorm = name.trim().toLowerCase();
    for (int i = 0; i < lines.length && i < 6; i++) {
      final String t = lines[i];
      if (nameNorm.isNotEmpty && t.toLowerCase() == nameNorm) {
        continue;
      }
      if (_emailRe.hasMatch(t) || _phoneRe.hasMatch(t)) {
        continue;
      }
      if (RegExp(r'^(email|phone|location|linkedin|github)\s*:', caseSensitive: false)
          .hasMatch(t)) {
        continue;
      }
      if (t.length > 90 || RegExp(r'\d{3,}').hasMatch(t)) {
        continue;
      }
      if (_isSectionHeader(t.toLowerCase())) {
        continue;
      }
      return t;
    }
    return '';
  }

  static String _section(String text, List<String> headers) {
    final List<String> lines = text.split('\n');
    int start = -1;
    for (int i = 0; i < lines.length; i++) {
      final String low = lines[i].trim().toLowerCase();
      if (low.isEmpty || RegExp(r'^[-_=]{4,}$').hasMatch(low)) {
        continue;
      }
      for (final String h in headers) {
        if (low == h || low.startsWith('$h:')) {
          start = i + 1;
          break;
        }
      }
      if (start >= 0) {
        break;
      }
    }
    if (start < 0) {
      return '';
    }
    final StringBuffer buf = StringBuffer();
    for (int i = start; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.isEmpty) {
        continue;
      }
      if (RegExp(r'^[-_=]{4,}$').hasMatch(line)) {
        continue;
      }
      final String low = line.toLowerCase();
      if (_isSectionHeader(low)) {
        break;
      }
      if (buf.isNotEmpty) {
        buf.write(' ');
      }
      buf.write(line);
    }
    return buf.toString().trim();
  }

  static bool _isSectionHeader(String low) {
    const List<String> ends = <String>[
      'experience',
      'work experience',
      'education',
      'skills',
      'technical skills',
      'projects',
      'languages',
      'certifications',
      'volunteering',
    ];
    for (final String e in ends) {
      if (low == e || low.startsWith('$e:')) {
        return true;
      }
    }
    return false;
  }

  static List<String> _skills(String text) {
    final String block = _section(
      text,
      const <String>[
        'technical skills',
        'core skills',
        'key skills',
        'skills',
        'competencies',
      ],
    );
    if (block.isEmpty) {
      return <String>[];
    }
    final List<String> parts = <String>[];
    for (final String line in block.split('\n')) {
      final String t = line.trim();
      if (t.isEmpty) {
        continue;
      }
      final String chunk =
          t.contains(':') && !t.toLowerCase().startsWith('http')
              ? t.split(':').skip(1).join(':')
              : t;
      for (final String p in chunk.split(RegExp(r'[,;|/]+'))) {
        final String s = p.trim();
        if (s.length > 1 && s.length < 80) {
          parts.add(s);
        }
      }
    }
    final Set<String> seen = <String>{};
    final List<String> out = <String>[];
    for (final String s in parts) {
      final String k = s.toLowerCase();
      if (seen.add(k)) {
        out.add(s);
      }
    }
    return out.take(40).toList();
  }

  static List<Map<String, dynamic>> _experience(String text) {
    final String block = _section(
      text,
      const <String>[
        'experience',
        'work experience',
        'professional experience',
        'work history',
        'employment',
      ],
    );
    if (block.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    Map<String, dynamic>? current;
    final List<String> bullets = <String>[];

    void flush() {
      if (current != null) {
        current!['description'] = bullets.join(' ').trim();
        items.add(Map<String, dynamic>.from(current!));
        current = null;
        bullets.clear();
      }
    }

    for (final String raw in block.split('\n')) {
      final String line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      final RegExpMatch? jm = _jobLineRe.firstMatch(line);
      if (jm != null) {
        flush();
        current = <String, dynamic>{
          'position': jm.group(1)!.trim(),
          'role': jm.group(1)!.trim(),
          'company': jm.group(2)!.trim(),
          'period': '${jm.group(4)!.trim()} · ${jm.group(3)!.trim()}',
          'description': '',
        };
      } else if (current != null) {
        if (line.startsWith(RegExp(r'[•\-–*]')) ||
            RegExp(r'^\d+[\).]').hasMatch(line)) {
          bullets.add(line.replaceFirst(RegExp(r'^[•\-–*\d\).]+\s*'), '').trim());
        } else if (bullets.isNotEmpty) {
          bullets[bullets.length - 1] = '${bullets.last} $line'.trim();
        } else {
          bullets.add(line);
        }
      }
    }
    flush();
    return items;
  }

  static List<Map<String, dynamic>> _education(String text) {
    final String block = _section(text, const <String>['education', 'academic']);
    if (block.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    for (final String raw in block.split('\n')) {
      final String line = raw.trim();
      if (line.isEmpty || RegExp(r'^[-_=]{4,}$').hasMatch(line)) {
        continue;
      }
      final List<String> parts = line.split('|').map((String s) => s.trim()).toList();
      if (parts.length >= 2) {
        items.add(<String, dynamic>{
          'degree': parts[0],
          'school': parts[1],
          'major': parts[0],
          'period': parts.length > 2 ? parts.sublist(2).join(' | ') : '',
        });
      }
    }
    return items;
  }
}
