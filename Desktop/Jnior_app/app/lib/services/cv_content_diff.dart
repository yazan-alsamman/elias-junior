import 'package:app/services/cv_compare_engine.dart';

/// Structured deltas between two CV versions (older → newer).
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

  static CvContentDiff fromSnapshots(
    CvCompareSnapshot older,
    CvCompareSnapshot newer,
  ) {
    final Set<String> oldSkills = _normSet(older.skills);
    final Set<String> newSkills = _normSet(newer.skills);
    final Set<String> oldCerts = _normSet(older.certifications);
    final Set<String> newCerts = _normSet(newer.certifications);
    final Set<String> oldRules =
        older.ruleIssues.map((String s) => s.toLowerCase()).toSet();
    final Set<String> newRules =
        newer.ruleIssues.map((String s) => s.toLowerCase()).toSet();

    return CvContentDiff(
      skillsAdded: _addedLabels(oldSkills, newSkills, newer.skills),
      skillsRemoved: _removedLabels(oldSkills, newSkills, older.skills),
      certificationsAdded:
          _addedLabels(oldCerts, newCerts, newer.certifications),
      certificationsRemoved:
          _removedLabels(oldCerts, newCerts, older.certifications),
      experienceAdded: _listAdded(older.experience, newer.experience),
      experienceRemoved: _listRemoved(older.experience, newer.experience),
      educationAdded: _listAdded(older.education, newer.education),
      educationRemoved: _listRemoved(older.education, newer.education),
      rulesFixed: older.ruleIssues
          .where((String issue) => !newRules.contains(issue.toLowerCase()))
          .toList(),
      rulesRegressed: newer.ruleIssues
          .where((String issue) => !oldRules.contains(issue.toLowerCase()))
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
    final Set<String> seen = <String>{};
    for (final String label in displayOrder) {
      final String key = label.trim().toLowerCase();
      if (added.contains(key) && seen.add(key)) {
        out.add(label.trim());
      }
    }
    for (final String k in added) {
      if (seen.add(k)) {
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
    final Set<String> seen = <String>{};
    for (final String label in displayOrder) {
      final String key = label.trim().toLowerCase();
      if (removed.contains(key) && seen.add(key)) {
        out.add(label.trim());
      }
    }
    for (final String k in removed) {
      if (seen.add(k)) {
        out.add(k);
      }
    }
    return out;
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
