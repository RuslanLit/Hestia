import 'dart:convert';

import 'package:flutter/services.dart';

class ProductContentService {
  ProductContentService._();
  static final ProductContentService instance = ProductContentService._();

  ProductContent? _content;

  Future<ProductContent> load() async {
    final cached = _content;
    if (cached != null) {
      return cached;
    }
    final raw = await rootBundle.loadString(
      'Landing_Hestia/content/product_content.json',
    );
    final content = ProductContent.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _content = content;
    return content;
  }
}

class ProductContent {
  final Map<String, ProductLocaleContent> locales;

  const ProductContent({required this.locales});

  factory ProductContent.fromJson(Map<String, dynamic> json) {
    final rawLocales = json['locales'] as Map<String, dynamic>? ?? {};
    return ProductContent(
      locales: rawLocales.map(
        (key, value) => MapEntry(
          key,
          ProductLocaleContent.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
    );
  }

  ProductLocaleContent locale(String languageCode) {
    return locales[languageCode] ?? locales['en']!;
  }
}

class ProductLocaleContent {
  final ProductTextBlock hero;
  final ProductSectionIntro featuresIntro;
  final List<ProductFeature> features;
  final ProductHowItWorks howItWorks;
  final ProductPrivacy privacy;
  final ProductDownloads downloads;
  final ProductServerChoice serverChoice;
  final ProductGetStarted getStarted;

  const ProductLocaleContent({
    required this.hero,
    required this.featuresIntro,
    required this.features,
    required this.howItWorks,
    required this.privacy,
    required this.downloads,
    required this.serverChoice,
    required this.getStarted,
  });

  factory ProductLocaleContent.fromJson(Map<String, dynamic> json) {
    return ProductLocaleContent(
      hero: ProductTextBlock.fromJson(json['hero'] as Map<String, dynamic>),
      featuresIntro: ProductSectionIntro.fromJson(
        json['featuresIntro'] as Map<String, dynamic>,
      ),
      features: (json['features'] as List<dynamic>? ?? [])
          .map((item) => ProductFeature.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      howItWorks: ProductHowItWorks.fromJson(
        json['howItWorks'] as Map<String, dynamic>,
      ),
      privacy: ProductPrivacy.fromJson(json['privacy'] as Map<String, dynamic>),
      downloads: ProductDownloads.fromJson(
        json['downloads'] as Map<String, dynamic>,
      ),
      serverChoice: ProductServerChoice.fromJson(
        json['serverChoice'] as Map<String, dynamic>,
      ),
      getStarted: ProductGetStarted.fromJson(
        json['getStarted'] as Map<String, dynamic>,
      ),
    );
  }

  ProductFeature feature(String id) =>
      features.firstWhere((item) => item.id == id, orElse: () => features.first);

  ProductStep step(String id) => howItWorks.steps.firstWhere(
        (item) => item.id == id,
        orElse: () => howItWorks.steps.first,
      );
}

class ProductTextBlock {
  final String title;
  final String body;
  final String? eyebrow;

  const ProductTextBlock({
    required this.title,
    required this.body,
    this.eyebrow,
  });

  factory ProductTextBlock.fromJson(Map<String, dynamic> json) {
    return ProductTextBlock(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      eyebrow: json['eyebrow'] as String?,
    );
  }
}

class ProductSectionIntro extends ProductTextBlock {
  const ProductSectionIntro({
    required super.title,
    required super.body,
    super.eyebrow,
  });

  factory ProductSectionIntro.fromJson(Map<String, dynamic> json) {
    return ProductSectionIntro(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      eyebrow: json['eyebrow'] as String?,
    );
  }
}

class ProductFeature {
  final String id;
  final String icon;
  final String title;
  final String body;

  const ProductFeature({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
  });

  factory ProductFeature.fromJson(Map<String, dynamic> json) {
    return ProductFeature(
      id: json['id'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class ProductHowItWorks {
  final String eyebrow;
  final String title;
  final List<ProductStep> steps;

  const ProductHowItWorks({
    required this.eyebrow,
    required this.title,
    required this.steps,
  });

  factory ProductHowItWorks.fromJson(Map<String, dynamic> json) {
    const ids = ['download', 'server', 'contacts', 'communicate'];
    final rawSteps = json['steps'] as List<dynamic>? ?? [];
    return ProductHowItWorks(
      eyebrow: json['eyebrow'] as String? ?? '',
      title: json['title'] as String? ?? '',
      steps: [
        for (var index = 0; index < rawSteps.length; index++)
          ProductStep.fromJson(
            Map<String, dynamic>.from(rawSteps[index] as Map),
            id: index < ids.length ? ids[index] : 'step$index',
          ),
      ],
    );
  }
}

class ProductStep {
  final String id;
  final String title;
  final String body;

  const ProductStep({
    required this.id,
    required this.title,
    required this.body,
  });

  factory ProductStep.fromJson(Map<String, dynamic> json, {required String id}) {
    return ProductStep(
      id: id,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }
}

class ProductPrivacy {
  final String eyebrow;
  final String title;
  final List<String> body;

  const ProductPrivacy({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  factory ProductPrivacy.fromJson(Map<String, dynamic> json) {
    return ProductPrivacy(
      eyebrow: json['eyebrow'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: (json['body'] as List<dynamic>? ?? []).whereType<String>().toList(),
    );
  }
}

class ProductDownloads {
  final String eyebrow;
  final String title;
  final String body;
  final String releaseDetails;
  final String releaseNotes;
  final String openWeb;
  final String viewDownloads;

  const ProductDownloads({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.releaseDetails,
    required this.releaseNotes,
    required this.openWeb,
    required this.viewDownloads,
  });

  factory ProductDownloads.fromJson(Map<String, dynamic> json) {
    return ProductDownloads(
      eyebrow: json['eyebrow'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      releaseDetails: json['releaseDetails'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      openWeb: json['openWeb'] as String? ?? '',
      viewDownloads: json['viewDownloads'] as String? ?? '',
    );
  }
}

class ProductServerChoice extends ProductTextBlock {
  final String defaultLabel;
  final String customLabel;
  final String customBody;

  const ProductServerChoice({
    required super.title,
    required super.body,
    required this.defaultLabel,
    required this.customLabel,
    required this.customBody,
  });

  factory ProductServerChoice.fromJson(Map<String, dynamic> json) {
    return ProductServerChoice(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      defaultLabel: json['default'] as String? ?? '',
      customLabel: json['custom'] as String? ?? '',
      customBody: json['customBody'] as String? ?? '',
    );
  }
}

class ProductGetStarted extends ProductTextBlock {
  final String primary;

  const ProductGetStarted({
    required super.title,
    required super.body,
    required this.primary,
  });

  factory ProductGetStarted.fromJson(Map<String, dynamic> json) {
    return ProductGetStarted(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      primary: json['primary'] as String? ?? '',
    );
  }
}


