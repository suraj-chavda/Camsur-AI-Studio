import '../../core/utils/json_x.dart';

class ToolModel {
  const ToolModel({
    required this.slug,
    required this.name,
    required this.description,
    required this.category,
    required this.creditCost,
    this.width = 1024,
    this.height = 1024,
    this.minInputImages = 1,
    this.maxInputImages = 1,
    this.imageUrl,
    this.sortOrder = 100,
    this.settings = const [],
    this.isTrending = false,
    this.trendingSortOrder = 100,
  });

  final String slug;
  final String name;
  final String description;
  final String category;
  final int creditCost;
  final int width;
  final int height;
  final int minInputImages;
  final int maxInputImages;
  final String? imageUrl;
  final int sortOrder;
  final List<ToolSetting> settings;
  final bool isTrending;
  final int trendingSortOrder;

  factory ToolModel.fromJson(Map<String, dynamic> json) {
    final minImgs = (json['min_input_images'] as num?)?.toInt() ?? 1;
    final maxImgs = (json['max_input_images'] as num?)?.toInt() ?? minImgs;
    return ToolModel(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'portrait',
      creditCost: (json['credit_cost'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 1024,
      height: (json['height'] as num?)?.toInt() ?? 1024,
      minInputImages: minImgs.clamp(1, 5),
      maxInputImages: maxImgs.clamp(minImgs.clamp(1, 5), 5),
      imageUrl: json['image_url']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      isTrending: json['is_trending'] == true,
      trendingSortOrder: (json['trending_sort_order'] as num?)?.toInt() ?? 100,
      settings: asJsonList(json['settings'])
          .whereType<Object>()
          .map((e) {
            try {
              return ToolSetting.fromJson(asJsonMap(e));
            } catch (_) {
              return null;
            }
          })
          .whereType<ToolSetting>()
          .toList(),
    );
  }
}

class ToolSetting {
  const ToolSetting({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
    this.locked = false,
    this.options = const [],
  });

  final String key;
  final String label;
  final String type;
  final String? defaultValue;
  final bool locked;
  final List<ToolSettingOption> options;

  factory ToolSetting.fromJson(Map<String, dynamic> json) => ToolSetting(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        type: json['type']?.toString() ?? 'select',
        defaultValue: json['default']?.toString(),
        locked: json['locked'] == true,
        options: asJsonList(json['options'])
            .whereType<Object>()
            .map((e) => ToolSettingOption.fromJson(asJsonMap(e)))
            .toList(),
      );
}

class ToolSettingOption {
  const ToolSettingOption({required this.value, required this.label});

  final String value;
  final String label;

  factory ToolSettingOption.fromJson(Map<String, dynamic> json) =>
      ToolSettingOption(
        value: json['value']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );
}

class ToolCategoryModel {
  const ToolCategoryModel({
    required this.slug,
    required this.name,
    required this.description,
    this.icon,
    this.imageUrl,
    this.sortOrder = 100,
    this.tools = const [],
  });

  final String slug;
  final String name;
  final String description;
  final String? icon;
  final String? imageUrl;
  final int sortOrder;
  final List<ToolModel> tools;

  factory ToolCategoryModel.fromJson(Map<String, dynamic> json) =>
      ToolCategoryModel(
        slug: json['slug']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        icon: json['icon']?.toString(),
        imageUrl: json['image_url']?.toString(),
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
        tools: asJsonList(json['tools'])
            .whereType<Object>()
            .map((e) => ToolModel.fromJson(asJsonMap(e)))
            .toList(),
      );
}

class BannerModel {
  const BannerModel({
    required this.slug,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
    this.linkType = 'none',
    this.linkValue,
    this.sortOrder = 100,
  });

  final String slug;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String linkType;
  final String? linkValue;
  final int sortOrder;

  factory BannerModel.fromJson(Map<String, dynamic> json) => BannerModel(
        slug: json['slug']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        imageUrl: json['image_url']?.toString(),
        linkType: json['link_type']?.toString() ?? 'none',
        linkValue: json['link_value']?.toString(),
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      );
}

class OnboardingSlideModel {
  const OnboardingSlideModel({
    required this.slug,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
    this.icon,
    this.sortOrder = 100,
  });

  final String slug;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? icon;
  final int sortOrder;

  factory OnboardingSlideModel.fromJson(Map<String, dynamic> json) =>
      OnboardingSlideModel(
        slug: json['slug']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        imageUrl: json['image_url']?.toString(),
        icon: json['icon']?.toString(),
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      );

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'icon': icon,
        'sort_order': sortOrder,
      };
}
