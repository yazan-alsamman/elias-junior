/// Job fit from the local RAG service (`POST /analyze-cv` on :8002).
class JobMatchReport {
  JobMatchReport({
    required this.specialization,
    required this.targetRole,
    required this.finalScore,
    required this.skillsComponent,
    required this.projectsExperienceComponent,
    required this.educationComponent,
    required this.missingSkills,
    required this.recommendedCourses,
    required this.recommendedProjects,
    required this.retrievedEvidence,
    required this.jobTitle,
    this.company = '',
    this.jobDescription = '',
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  final String specialization;
  final String targetRole;
  final int finalScore;
  final double skillsComponent;
  final double projectsExperienceComponent;
  final double educationComponent;
  final List<String> missingSkills;
  final List<String> recommendedCourses;
  final List<String> recommendedProjects;
  final List<JobMatchEvidence> retrievedEvidence;
  final String jobTitle;
  final String company;
  final String jobDescription;
  final DateTime analyzedAt;

  static const int passScoreThreshold = 70;

  bool get isSuitable => finalScore > passScoreThreshold;

  String get suitabilityHeadline {
    if (isSuitable) {
      return 'Strong fit for $targetRole — score $finalScore/100';
    }
    if (finalScore >= 50) {
      return 'Moderate fit for $targetRole — close gaps to improve ($finalScore/100)';
    }
    return 'Limited fit for $targetRole — major skill gaps ($finalScore/100)';
  }

  factory JobMatchReport.fromJson(
    Map<String, dynamic> json, {
    required String jobTitle,
    String company = '',
    String jobDescription = '',
  }) {
    final Map<String, dynamic> breakdown =
        json['score_breakdown'] is Map<String, dynamic>
            ? json['score_breakdown'] as Map<String, dynamic>
            : <String, dynamic>{};
    final List<dynamic> evidenceRaw =
        json['retrieved_evidence'] as List<dynamic>? ?? <dynamic>[];
    return JobMatchReport(
      specialization: (json['specialization'] as String?) ?? '',
      targetRole: (json['target_role'] as String?) ?? '',
      finalScore: (breakdown['final_score'] as num?)?.toInt() ?? 0,
      skillsComponent: (breakdown['skills_component'] as num?)?.toDouble() ?? 0,
      projectsExperienceComponent:
          (breakdown['projects_experience_component'] as num?)?.toDouble() ?? 0,
      educationComponent:
          (breakdown['education_component'] as num?)?.toDouble() ?? 0,
      missingSkills: _stringList(json['missing_skills']),
      recommendedCourses: _stringList(json['recommended_courses']),
      recommendedProjects: _stringList(json['recommended_projects']),
      retrievedEvidence: evidenceRaw
          .whereType<Map<String, dynamic>>()
          .map(JobMatchEvidence.fromJson)
          .toList(),
      jobTitle: (json['jobTitle'] as String?)?.isNotEmpty == true
          ? json['jobTitle'] as String
          : jobTitle,
      company: (json['company'] as String?) ?? company,
      jobDescription: (json['jobDescription'] as String?) ?? jobDescription,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'specialization': specialization,
        'target_role': targetRole,
        'score_breakdown': <String, dynamic>{
          'skills_component': skillsComponent,
          'projects_experience_component': projectsExperienceComponent,
          'education_component': educationComponent,
          'final_score': finalScore,
        },
        'missing_skills': missingSkills,
        'recommended_courses': recommendedCourses,
        'recommended_projects': recommendedProjects,
        'retrieved_evidence':
            retrievedEvidence.map((JobMatchEvidence e) => e.toJson()).toList(),
        'jobTitle': jobTitle,
        'company': company,
        'jobDescription': jobDescription,
        'analyzedAt': analyzedAt.toUtc().toIso8601String(),
      };

  static List<String> _stringList(Object? raw) {
    if (raw is! List) {
      return <String>[];
    }
    final List<String> out = <String>[];
    for (final Object? item in raw) {
      final String s = item.toString().trim();
      if (s.isNotEmpty) {
        out.add(s);
      }
    }
    return out;
  }
}

class JobMatchEvidence {
  JobMatchEvidence({
    required this.topic,
    required this.source,
    required this.score,
    required this.content,
  });

  final String topic;
  final String source;
  final double score;
  final String content;

  factory JobMatchEvidence.fromJson(Map<String, dynamic> json) {
    return JobMatchEvidence(
      topic: (json['topic'] as String?) ?? '',
      source: (json['source'] as String?) ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      content: (json['content'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'topic': topic,
        'source': source,
        'score': score,
        'content': content,
      };
}
