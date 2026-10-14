enum FrontTier { primary, coFront, coCon }

class Alter {
  const Alter({
    required this.id,
    required this.name,
    required this.createdAt,
    this.pronouns = '',
    this.role = '',
    this.colorValue = 0xFF9B5DE5,
    this.bio = '',
    this.imagePath,
    this.bannerPath,
    this.archived = false,
    this.tags = const [],
    this.groups = const [],
    this.customFields = const {},
    this.ageYears,
    this.littleMode = 'auto',
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int? ageYears;
  final String littleMode;
  final String pronouns;
  final String role;
  final int colorValue;
  final String bio;
  final String? imagePath;
  final String? bannerPath;
  final bool archived;
  final List<String> tags;
  final List<String> groups;
  final Map<String, String> customFields;

  Alter copyWith({
    String? name,
    String? pronouns,
    String? role,
    int? colorValue,
    String? bio,
    String? imagePath,
    bool clearImage = false,
    String? bannerPath,
    bool clearBanner = false,
    bool? archived,
    List<String>? tags,
    List<String>? groups,
    Map<String, String>? customFields,
    int? ageYears,
    bool clearAge = false,
    String? littleMode,
  }) =>
      Alter(
        id: id,
        createdAt: createdAt,
        ageYears: clearAge ? null : (ageYears ?? this.ageYears),
        littleMode: littleMode ?? this.littleMode,
        name: name ?? this.name,
        pronouns: pronouns ?? this.pronouns,
        role: role ?? this.role,
        colorValue: colorValue ?? this.colorValue,
        bio: bio ?? this.bio,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        bannerPath: clearBanner ? null : (bannerPath ?? this.bannerPath),
        archived: archived ?? this.archived,
        tags: tags ?? this.tags,
        groups: groups ?? this.groups,
        customFields: customFields ?? this.customFields,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'pronouns': pronouns,
        'role': role,
        'colorValue': colorValue,
        'bio': bio,
        'imagePath': imagePath,
        'bannerPath': bannerPath,
        'archived': archived,
        'tags': tags,
        'groups': groups,
        'customFields': customFields,
        'ageYears': ageYears,
        'littleMode': littleMode,
      };

  factory Alter.fromJson(Map<String, dynamic> j) => Alter(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        pronouns: j['pronouns'] as String? ?? '',
        role: j['role'] as String? ?? '',
        colorValue: j['colorValue'] as int? ?? 0xFF9B5DE5,
        bio: j['bio'] as String? ?? '',
        imagePath: j['imagePath'] as String?,
        bannerPath: j['bannerPath'] as String?,
        archived: j['archived'] as bool? ?? false,
        tags: List<String>.from(j['tags'] as List? ?? const []),
        groups: List<String>.from(j['groups'] as List? ?? const []),
        customFields: Map<String, String>.from(j['customFields'] as Map? ?? const {}),
        ageYears: j['ageYears'] as int?,
        littleMode: j['littleMode'] as String? ?? 'auto',
      );
}

class FrontEntry {
  const FrontEntry({
    required this.id,
    required this.alterId,
    required this.tier,
    required this.start,
    this.end,
    this.note = '',
  });

  final String id;
  final String alterId;
  final FrontTier tier;
  final DateTime start;
  final DateTime? end;
  final String note;

  FrontEntry copyWith({DateTime? end}) => FrontEntry(
        id: id, alterId: alterId, tier: tier, start: start,
        end: end ?? this.end, note: note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'alterId': alterId,
        'tier': tier.name,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'note': note,
      };

  factory FrontEntry.fromJson(Map<String, dynamic> j) => FrontEntry(
        id: j['id'] as String,
        alterId: j['alterId'] as String,
        tier: FrontTier.values.byName(j['tier'] as String),
        start: DateTime.parse(j['start'] as String),
        end: j['end'] == null ? null : DateTime.parse(j['end'] as String),
        note: j['note'] as String? ?? '',
      );
}
