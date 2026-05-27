import 'package:app/model/ats_check_report.dart';
import 'package:app/model/cv_document.dart';
import 'package:app/model/job_match_report.dart';
import 'package:app/model/parsed_cv_profile.dart';

class SkillGapEntry {
  final String name;
  /// How well your CV reflects this skill (0–100).
  final int proficiencyScore;
  /// Typical market demand for this skill (0–100).
  final int marketDemand;

  const SkillGapEntry({
    required this.name,
    required this.proficiencyScore,
    this.marketDemand = 80,
  });
}

class CourseRecommendation {
  final String category;
  final String title;
  final String platform;
  final double rating;
  final String durationLabel;

  const CourseRecommendation({
    required this.category,
    required this.title,
    required this.platform,
    required this.rating,
    required this.durationLabel,
  });
}

class ResultsAnalysis {
  final String documentLabel;
  final int atsScore;
  final String cvPreviewMarkdown;
  final List<String> strengths;
  final List<String> gaps;
  final List<SkillGapEntry> skillGaps;
  final List<CourseRecommendation> courses;
  final List<String> recommendations;
  final String suitabilityHeadline;
  /// RAG job-fit score (1–100), when a target job was analyzed.
  final int? jobFitScore;
  final String jobFitRole;
  final bool jobFitFromRag;

  const ResultsAnalysis({
    required this.documentLabel,
    required this.atsScore,
    required this.cvPreviewMarkdown,
    required this.strengths,
    required this.gaps,
    required this.skillGaps,
    required this.courses,
    this.recommendations = const <String>[],
    this.suitabilityHeadline = '',
    this.jobFitScore,
    this.jobFitRole = '',
    this.jobFitFromRag = false,
  });

  /// Universal pool of CV skills used to detect "strengths" from CV preview text.
  static const List<String> _universalSkillPool = <String>[
    'React',
    'TypeScript',
    'JavaScript',
    'Node.js',
    'Python',
    'Java',
    'C#',
    'C++',
    'SQL',
    'NoSQL',
    'MongoDB',
    'PostgreSQL',
    'MySQL',
    'Docker',
    'Kubernetes',
    'AWS',
    'Azure',
    'GCP',
    'CI/CD',
    'Git',
    'GraphQL',
    'REST APIs',
    'Agile',
    'Scrum',
    'Tailwind CSS',
    'Flutter',
    'Dart',
    'Swift',
    'Kotlin',
    'Android',
    'iOS',
    'HTML',
    'CSS',
    'Linux',
    'Bash',
    'Redux',
    'Express',
    'Django',
    'Spring',
    'TensorFlow',
    'PyTorch',
    'Machine Learning',
    'Data Analysis',
    'Microservices',
    'Terraform',
    'Jenkins',
    'GitHub Actions',
    'Figma',
    'Design Systems',
    'Accessibility',
  ];

  /// Detects which universal skills appear in the CV preview / file name.
  static List<String> _detectStrengthsFromPreview(
    String previewText,
    String fileName,
    List<String> gaps,
  ) {
    final String haystack = '$previewText\n$fileName'.toLowerCase();
    final Set<String> gapSet =
        gaps.map((String g) => g.toLowerCase()).toSet();
    final List<String> hits = <String>[];
    for (final String skill in _universalSkillPool) {
      if (gapSet.contains(skill.toLowerCase())) continue;
      final String needle = skill.toLowerCase();
      if (haystack.contains(needle)) hits.add(skill);
      if (hits.length >= 6) break;
    }
    return hits;
  }

  /// Default catalog of courses, keyed by skill keyword.
  static const Map<String, CourseRecommendation> _courseCatalog =
      <String, CourseRecommendation>{
    'docker': CourseRecommendation(
      category: 'Docker',
      title: 'Docker & Kubernetes: The Complete Guide',
      platform: 'Udemy',
      rating: 4.7,
      durationLabel: '22 hours',
    ),
    'kubernetes': CourseRecommendation(
      category: 'Kubernetes',
      title: 'Kubernetes for Developers',
      platform: 'Udemy',
      rating: 4.6,
      durationLabel: '15 hours',
    ),
    'aws': CourseRecommendation(
      category: 'AWS',
      title: 'AWS Certified Solutions Architect',
      platform: 'Coursera',
      rating: 4.6,
      durationLabel: '40 hours',
    ),
    'azure': CourseRecommendation(
      category: 'Azure',
      title: 'Microsoft Azure Fundamentals AZ-900',
      platform: 'Udemy',
      rating: 4.6,
      durationLabel: '12 hours',
    ),
    'ci/cd': CourseRecommendation(
      category: 'CI/CD',
      title: 'DevOps CI/CD with GitHub Actions',
      platform: 'Udemy',
      rating: 4.5,
      durationLabel: '12 hours',
    ),
    'github actions': CourseRecommendation(
      category: 'CI/CD',
      title: 'DevOps CI/CD with GitHub Actions',
      platform: 'Udemy',
      rating: 4.5,
      durationLabel: '12 hours',
    ),
    'agile': CourseRecommendation(
      category: 'Agile',
      title: 'Agile at Scale: Scrum & Kanban',
      platform: 'Coursera',
      rating: 4.4,
      durationLabel: '8 weeks',
    ),
    'scrum': CourseRecommendation(
      category: 'Agile',
      title: 'Professional Scrum Master Certification',
      platform: 'Coursera',
      rating: 4.5,
      durationLabel: '6 weeks',
    ),
    'graphql': CourseRecommendation(
      category: 'GraphQL',
      title: 'GraphQL with React: The Complete Developer Guide',
      platform: 'Udemy',
      rating: 4.6,
      durationLabel: '13 hours',
    ),
    'typescript': CourseRecommendation(
      category: 'TypeScript',
      title: 'Understanding TypeScript',
      platform: 'Udemy',
      rating: 4.7,
      durationLabel: '15 hours',
    ),
    'react': CourseRecommendation(
      category: 'React',
      title: 'React — The Complete Guide',
      platform: 'Udemy',
      rating: 4.7,
      durationLabel: '50 hours',
    ),
    'node.js': CourseRecommendation(
      category: 'Node.js',
      title: 'Node.js, Express, MongoDB & More — The Complete Bootcamp',
      platform: 'Udemy',
      rating: 4.7,
      durationLabel: '42 hours',
    ),
    'python': CourseRecommendation(
      category: 'Python',
      title: '100 Days of Code: Complete Python Pro Bootcamp',
      platform: 'Udemy',
      rating: 4.7,
      durationLabel: '60 hours',
    ),
    'machine learning': CourseRecommendation(
      category: 'ML',
      title: 'Machine Learning Specialization',
      platform: 'Coursera',
      rating: 4.9,
      durationLabel: '3 months',
    ),
    'sql': CourseRecommendation(
      category: 'SQL',
      title: 'The Complete SQL Bootcamp',
      platform: 'Udemy',
      rating: 4.7,
      durationLabel: '9 hours',
    ),
    'leadership': CourseRecommendation(
      category: 'Leadership',
      title: 'Leadership: Practical Leadership Skills',
      platform: 'Udemy',
      rating: 4.5,
      durationLabel: '3 hours',
    ),
    'communication': CourseRecommendation(
      category: 'Soft Skills',
      title: 'Effective Communication for Engineers',
      platform: 'Coursera',
      rating: 4.6,
      durationLabel: '4 weeks',
    ),
  };

  /// Generic fallback courses when no specific gaps match.
  static const List<CourseRecommendation> _fallbackCourses =
      <CourseRecommendation>[
    CourseRecommendation(
      category: 'CV Writing',
      title: 'Write an ATS-Friendly Resume That Gets Interviews',
      platform: 'Udemy',
      rating: 4.5,
      durationLabel: '2 hours',
    ),
    CourseRecommendation(
      category: 'Interview',
      title: 'Cracking the Coding Interview',
      platform: 'Coursera',
      rating: 4.6,
      durationLabel: '6 weeks',
    ),
    CourseRecommendation(
      category: 'Career',
      title: 'Personal Branding for Engineers',
      platform: 'LinkedIn Learning',
      rating: 4.4,
      durationLabel: '3 hours',
    ),
  ];

  static List<CourseRecommendation> _recommendCourses(List<String> gaps) {
    final List<CourseRecommendation> picks = <CourseRecommendation>[];
    final Set<String> seen = <String>{};
    for (final String g in gaps) {
      final String key = g.toLowerCase().trim();
      final CourseRecommendation? hit = _courseCatalog[key];
      if (hit != null && seen.add(hit.title)) {
        picks.add(hit);
      }
      if (picks.length >= 4) break;
    }
    if (picks.length < 3) {
      for (final CourseRecommendation c in _fallbackCourses) {
        if (seen.add(c.title)) picks.add(c);
        if (picks.length >= 4) break;
      }
    }
    return picks;
  }

  static List<SkillGapEntry> _buildSkillGaps(
    List<String> strengths,
    List<String> gaps,
  ) {
    final List<SkillGapEntry> entries = <SkillGapEntry>[];
    for (final String s in strengths.take(3)) {
      entries.add(SkillGapEntry(
        name: s,
        proficiencyScore: 85,
        marketDemand: 88,
      ));
    }
    for (final String g in gaps.take(3)) {
      entries.add(SkillGapEntry(
        name: g,
        proficiencyScore: 35,
        marketDemand: 82,
      ));
    }
    if (entries.isEmpty) {
      entries.addAll(const <SkillGapEntry>[
        SkillGapEntry(
            name: 'Communication', proficiencyScore: 70, marketDemand: 85),
        SkillGapEntry(
            name: 'Problem Solving', proficiencyScore: 65, marketDemand: 88),
        SkillGapEntry(
            name: 'Teamwork', proficiencyScore: 70, marketDemand: 80),
      ]);
    }
    return entries;
  }

  /// Default preview shown when CV text could not be extracted.
  static const String _defaultPreview = '''
PROFESSIONAL SUMMARY
Upload a CV to see its parsed content here. The ATS engine extracts text from your PDF or DOCX.

WORK EXPERIENCE
• Your roles and key achievements will appear here.

EDUCATION
• Your degrees and certifications will appear here.

SKILLS
Your skills, tools, and frameworks will appear here.
''';

  static ResultsAnalysis fromDocument(
    CVDocument? doc, {
    JobMatchReport? jobMatch,
  }) {
    if (doc == null) {
      return const ResultsAnalysis(
        documentLabel: '',
        atsScore: 0,
        cvPreviewMarkdown: 'Upload a CV to see a preview.',
        strengths: <String>[],
        gaps: <String>[],
        skillGaps: <SkillGapEntry>[],
        courses: <CourseRecommendation>[],
      );
    }

    final int score = doc.report.score;
    final ATSCheckReport ats = doc.report;
    List<String> gaps = ats.failures.isNotEmpty
        ? ats.failures
            .map((AtsRuleFailure f) => f.issue.trim())
            .where((String s) => s.isNotEmpty)
            .toList()
        : ats.missingKeywords
            .where((String s) => s.trim().isNotEmpty)
            .toList();
    if (jobMatch != null && jobMatch.missingSkills.isNotEmpty) {
      gaps = jobMatch.missingSkills
          .map((String s) => s.replaceAll('_', ' '))
          .toList();
    }
    final ParsedCvProfile? parsed = doc.parsedProfile;
    final String parsedMarkdown =
        parsed != null && parsed.toPreviewMarkdown().isNotEmpty
            ? parsed.toPreviewMarkdown()
            : '';
    final String preview = parsedMarkdown.isNotEmpty
        ? parsedMarkdown
        : (doc.contentPreview.trim().isEmpty ? _defaultPreview : doc.contentPreview);
    final List<String> strengths = parsed != null && parsed.skills.isNotEmpty
        ? parsed.skills.take(12).toList()
        : _detectStrengthsFromPreview(preview, doc.fileName, gaps);

    final List<CourseRecommendation> courses = jobMatch != null &&
            jobMatch.recommendedCourses.isNotEmpty
        ? jobMatch.recommendedCourses
            .take(6)
            .map(
              (String title) => CourseRecommendation(
                category: 'RAG',
                title: title,
                platform: 'Knowledge base',
                rating: 4.5,
                durationLabel: 'Recommended',
              ),
            )
            .toList()
        : _recommendCourses(gaps);

    final List<String> recs = <String>[
      ...doc.report.recommendations,
      if (jobMatch != null) ...jobMatch.recommendedProjects.take(4),
    ];

    return ResultsAnalysis(
      documentLabel: doc.fileName,
      atsScore: score,
      cvPreviewMarkdown: preview,
      strengths: strengths.isEmpty
          ? const <String>['Communication', 'Teamwork', 'Problem Solving']
          : strengths,
      gaps: gaps.isEmpty && !ats.isRealAts && jobMatch == null
          ? const <String>['Quantified outcomes', 'Tooling keywords']
          : gaps,
      skillGaps: _buildSkillGaps(strengths, gaps),
      courses: courses,
      recommendations: recs,
      suitabilityHeadline: jobMatch?.suitabilityHeadline.isNotEmpty == true
          ? jobMatch!.suitabilityHeadline
          : doc.report.suitabilityHeadline,
      jobFitScore: jobMatch?.finalScore,
      jobFitRole: jobMatch?.targetRole ?? '',
      jobFitFromRag: jobMatch != null,
    );
  }
}
