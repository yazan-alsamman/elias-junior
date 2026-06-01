import 'package:app/model/cv_document.dart';
import 'package:app/model/parsed_cv_profile.dart';

/// Text / structured deltas between two CV versions (older → newer).
class CvContentDiff {
  const CvContentDiff({
    required this.skillsAdded,
    required this.skillsRemoved,
    required this.certificationsAdded,
    required this.certificationsRemoved,
    required this.experienceAdded,
    required this.experienceRemoved,
    required this.educationAdded,
    required this.educationRemoved,
    required this.rulesFixed,
    required this.rulesRegressed,
  });

  final List<String> skillsAdded;
  final List<String> skillsRemoved;
  final List<String> certificationsAdded;
  final List<String> certificationsRemoved;
  final List<String> experienceAdded;
  final List<String> experienceRemoved;
  final List<String> educationAdded;
  final List<String> educationRemoved;
  final List<String> rulesFixed;
  final List<String> rulesRegressed;

  bool get hasStructuredChanges =>
      skillsAdded.isNotEmpty ||
      skillsRemoved.isNotEmpty ||
      certificationsAdded.isNotEmpty ||
      certificationsRemoved.isNotEmpty ||
      experienceAdded.isNotEmpty ||
      experienceRemoved.isNotEmpty ||
      educationAdded.isNotEmpty ||
      educationRemoved.isNotEmpty ||
      rulesFixed.isNotEmpty ||
      rulesRegressed.isNotEmpty;

  static CvContentDiff between(CVDocument older, CVDocument newer) {
    final ParsedCvProfile? oldP = older.parsedProfile;
    final ParsedCvProfile? newP = newer.parsedProfile;

    final Set<String> oldSkills = _normSet(
      oldP?.skills ?? _skillsFromPreview(older.contentPreview),
    );
    final Set<String> newSkills = _normSet(
      newP?.skills ?? _skillsFromPreview(newer.contentPreview),
    );
    final Set<String> oldCerts = _normSet(oldP?.certifications ?? const <String>[]);
    final Set<String> newCerts = _normSet(newP?.certifications ?? const <String>[]);

    final List<String> oldExp = _experienceLines(oldP, older);
    final List<String> newExp = _experienceLines(newP, newer);
    final List<String> oldEdu = _educationLines(oldP, older);
    final List<String> newEdu = _educationLines(newP, newer);

    final Set<String> oldRules = older.report.failures
        .map((f) => f.issue.trim().toLowerCase())
        .where((String s) => s.isNotEmpty)
        .toSet();
    final Set<String> newRules = newer.report.failures
        .map((f) => f.issue.trim().toLowerCase())
        .where((String s) => s.isNotEmpty)
        .toSet();

    return CvContentDiff(
      skillsAdded: _addedLabels(oldSkills, newSkills, newP?.skills ?? const <String>[]),
      skillsRemoved: _removedLabels(oldSkills, newSkills, oldP?.skills ?? const <String>[]),
      certificationsAdded:
          _addedLabels(oldCerts, newCerts, newP?.certifications ?? const <String>[]),
      certificationsRemoved:
          _removedLabels(oldCerts, newCerts, oldP?.certifications ?? const <String>[]),
      experienceAdded: _listAdded(oldExp, newExp),
      experienceRemoved: _listRemoved(oldExp, newExp),
      educationAdded: _listAdded(oldEdu, newEdu),
      educationRemoved: _listRemoved(oldEdu, newEdu),
      rulesFixed: older.report.failures
          .where((f) {
            final String k = f.issue.trim().toLowerCase();
            return k.isNotEmpty && !newRules.contains(k);
          })
          .map((f) => f.issue.trim())
          .toList(),
      rulesRegressed: newer.report.failures
          .where((f) {
            final String k = f.issue.trim().toLowerCase();
            return k.isNotEmpty && !oldRules.contains(k);
          })
          .map((f) => f.issue.trim())
          .toList(),
    );
  }

  static Set<String> _normSet(Iterable<String> items) {
    return items
        .map((String s) => s.trim().toLowerCase())
        .where((String s) => s.isNotEmpty)
        .toSet();
  }

  static List<String> _addedLabels(
    Set<String> oldSet,
    Set<String> newSet,
    List<String> displayOrder,
  ) {
    final Set<String> added = newSet.difference(oldSet);
    if (added.isEmpty) return const <String>[];
    final List<String> out = <String>[];
    for (final String label in displayOrder) {
      if (added.contains(label.trim().toLowerCase())) {
        out.add(label.trim());
      }
    }
    for (final String k in added) {
      if (!out.any((String o) => o.toLowerCase() == k)) {
        out.add(k);
      }
    }
    return out;
  }

  static List<String> _removedLabels(
    Set<String> oldSet,
    Set<String> newSet,
    List<String> displayOrder,
  ) {
    final Set<String> removed = oldSet.difference(newSet);
    if (removed.isEmpty) return const <String>[];
    final List<String> out = <String>[];
    for (final String label in displayOrder) {
      if (removed.contains(label.trim().toLowerCase())) {
        out.add(label.trim());
      }
    }
    for (final String k in removed) {
      if (!out.any((String o) => o.toLowerCase() == k)) {
        out.add(k);
      }
    }
    return out;
  }

  static List<String> _experienceLines(ParsedCvProfile? p, CVDocument doc) {
    if (p != null && p.experience.isNotEmpty) {
      return p.experience.map(_formatRole).where((String s) => s.isNotEmpty).toList();
    }
    return _linesFromSection(_preview(doc.contentPreview), 'WORK EXPERIENCE', 'EDUCATION');
  }

  static List<String> _educationLines(ParsedCvProfile? p, CVDocument doc) {
    if (p != null && p.education.isNotEmpty) {
      return p.education.map(_formatEdu).where((String s) => s.isNotEmpty).toList();
    }
    return _linesFromSection(_preview(doc.contentPreview), 'EDUCATION', 'SKILLS');
  }

  static String _formatRole(Map<String, dynamic> m) {
    final String title = '${m['title'] ?? m['role'] ?? ''}'.trim();
    final String company = '${m['company'] ?? m['employer'] ?? ''}'.trim();
    if (title.isEmpty && company.isEmpty) return '';
    if (company.isEmpty) return title;
    if (title.isEmpty) return company;
    return '$title @ $company';
  }

  static String _formatEdu(Map<String, dynamic> m) {
    final String degree = '${m['degree'] ?? m['qualification'] ?? ''}'.trim();
    final String school = '${m['school'] ?? m['institution'] ?? ''}'.trim();
    if (degree.isEmpty && school.isEmpty) return '';
    if (school.isEmpty) return degree;
    if (degree.isEmpty) return school;
    return '$degree — $school';
  }

  static List<String> _linesFromSection(
    String text,
    String startHeader,
    String endHeader,
  ) {
    final String upper = text.toUpperCase();
    final int start = upper.indexOf(startHeader);
    if (start < 0) return const <String>[];
    final int end = upper.indexOf(endHeader, start + startHeader.length);
    final String chunk = end > start
        ? text.substring(start + startHeader.length, end)
        : text.substring(start + startHeader.length);
    return chunk
        .split('\n')
        .map((String l) => l.replaceFirst(RegExp(r'^[\s•\-–*]+'), '').trim())
        .where((String l) => l.length > 2)
        .toList();
  }

  static const int _maxPreviewChars = 4000;

  static String _preview(String text) {
    if (text.length <= _maxPreviewChars) return text;
    return text.substring(0, _maxPreviewChars);
  }

  static List<String> _skillsFromPreview(String preview) {
    final String text = _preview(preview);
    final List<String> lines = _linesFromSection(text, 'SKILLS', 'CERTIFICATION');
    if (lines.isEmpty) {
      return _linesFromSection(text, 'SKILLS', 'PROJECTS');
    }
    return lines
        .expand((String l) => l.split(RegExp(r'[,;|/]')))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .take(80)
        .toList();
  }

  static List<String> _listAdded(List<String> oldList, List<String> newList) {
    final Set<String> oldNorm = oldList.map((String s) => s.toLowerCase()).toSet();
    return newList
        .where((String s) => !oldNorm.contains(s.toLowerCase()))
        .toList();
  }

  static List<String> _listRemoved(List<String> oldList, List<String> newList) {
    final Set<String> newNorm = newList.map((String s) => s.toLowerCase()).toSet();
    return oldList
        .where((String s) => !newNorm.contains(s.toLowerCase()))
        .toList();
  }
}
