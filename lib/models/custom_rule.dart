enum RuleType { merchantExtraction, categorization }

class CustomRule {
  final String id;
  final RuleType ruleType;

  // Both rule types: define a "window" in the message.
  // For extraction: text between prefix and terminator IS the payee name.
  // For categorization: keywords are searched within that window.
  // Both are optional — omit prefix to start from message start, omit
  // terminator to search till end.
  final String? prefix;
  final String? terminator;

  // Categorization only: if any keyword is found inside the window → apply category.
  final List<String> keywords;

  // Categorization only (null for merchantExtraction).
  final String? category;
  final String? subCategory;

  final bool isEnabled;
  final DateTime createdAt;

  const CustomRule({
    required this.id,
    required this.ruleType,
    this.prefix,
    this.terminator,
    this.keywords = const [],
    this.category,
    this.subCategory,
    this.isEnabled = true,
    required this.createdAt,
  });

  factory CustomRule.extraction({
    String? prefix,
    String? terminator,
  }) =>
      CustomRule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ruleType: RuleType.merchantExtraction,
        prefix: _clean(prefix),
        terminator: _clean(terminator),
        createdAt: DateTime.now(),
      );

  factory CustomRule.categorization({
    String? prefix,
    String? terminator,
    required List<String> keywords,
    required String category,
    required String subCategory,
  }) =>
      CustomRule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ruleType: RuleType.categorization,
        prefix: _clean(prefix),
        terminator: _clean(terminator),
        keywords: keywords.map((k) => k.trim()).where((k) => k.isNotEmpty).toList(),
        category: category,
        subCategory: subCategory.trim(),
        createdAt: DateTime.now(),
      );

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  // ── Extraction logic ────────────────────────────────────────────────────────

  // Returns the payee name extracted from [message], or null if prefix not found.
  String? extractMerchant(String message) {
    if (!isEnabled) return null;

    String afterPrefix;
    if (prefix != null) {
      final idx = message.toLowerCase().indexOf(prefix!.toLowerCase());
      if (idx == -1) return null;
      afterPrefix = message.substring(idx + prefix!.length).trimLeft();
    } else {
      afterPrefix = message;
    }

    if (terminator != null) {
      final endIdx = afterPrefix.toLowerCase().indexOf(terminator!.toLowerCase());
      if (endIdx != -1) return afterPrefix.substring(0, endIdx).trim();
    }

    // No terminator: stop at 3+ digit run (an amount) or newline
    final stop = RegExp(r'\s+\d{3,}|\n');
    final m = stop.firstMatch(afterPrefix);
    return m != null
        ? afterPrefix.substring(0, m.start).trim()
        : afterPrefix.trim();
  }

  // ── Categorization logic ────────────────────────────────────────────────────

  // Returns true if this categorization rule matches [message].
  bool matchesMessage(String message) {
    if (!isEnabled || ruleType != RuleType.categorization) return false;
    if (keywords.isEmpty) return false;

    // Determine the window of text to search in
    String window;
    if (prefix != null) {
      final idx = message.toLowerCase().indexOf(prefix!.toLowerCase());
      if (idx == -1) return false; // prefix required but not found
      final afterPrefix = message.substring(idx + prefix!.length);
      if (terminator != null) {
        final endIdx = afterPrefix.toLowerCase().indexOf(terminator!.toLowerCase());
        window = endIdx != -1 ? afterPrefix.substring(0, endIdx) : afterPrefix;
      } else {
        window = afterPrefix;
      }
    } else {
      // No prefix: search the entire message
      window = message;
    }

    final lowerWindow = window.toLowerCase();
    return keywords.any((kw) => kw.isNotEmpty && lowerWindow.contains(kw.toLowerCase()));
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  CustomRule copyWith({bool? isEnabled}) => CustomRule(
        id: id,
        ruleType: ruleType,
        prefix: prefix,
        terminator: terminator,
        keywords: keywords,
        category: category,
        subCategory: subCategory,
        isEnabled: isEnabled ?? this.isEnabled,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'ruleType': ruleType.name,
        'prefix': prefix,
        'terminator': terminator,
        'keywords': keywords.isEmpty ? null : keywords.join(','),
        'category': category,
        'subCategory': subCategory,
        'isEnabled': isEnabled ? 1 : 0,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory CustomRule.fromMap(Map<String, dynamic> m) {
    final typeStr = m['ruleType'] as String? ?? 'merchantExtraction';
    final kwStr = m['keywords'] as String?;
    return CustomRule(
      id: m['id'] as String,
      ruleType: typeStr == 'categorization' ? RuleType.categorization : RuleType.merchantExtraction,
      prefix: m['prefix'] as String?,
      terminator: m['terminator'] as String?,
      keywords: (kwStr == null || kwStr.isEmpty)
          ? const []
          : kwStr.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty).toList(),
      category: m['category'] as String?,
      subCategory: m['subCategory'] as String?,
      isEnabled: (m['isEnabled'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    );
  }
}
