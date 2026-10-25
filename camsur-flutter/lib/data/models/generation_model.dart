import '../../core/utils/json_x.dart';

class GenerationModel {
  const GenerationModel({
    required this.id,
    required this.toolSlug,
    required this.status,
    this.userId,
    this.source,
    this.inputImageUrl,
    this.inputImageUrls = const [],
    this.outputImageUrl,
    this.styleNotes,
    this.settings = const {},
    this.creditCost = 0,
    this.errorMessage,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String toolSlug;
  final String status;
  final String? userId;
  final String? source;
  final String? inputImageUrl;
  /// All source photos when the API returns more than one.
  final List<String> inputImageUrls;
  final String? outputImageUrl;
  final String? styleNotes;
  final Map<String, dynamic> settings;
  final int creditCost;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? completedAt;

  bool get isTerminal =>
      status == 'completed' ||
      status == 'failed' ||
      status == 'refunded' ||
      status == 'cancelled';

  bool get isSuccess => status == 'completed';
  bool get isPending => status == 'pending' || status == 'processing';

  /// Deduped http(s) input URLs — prefers plural list, falls back to single.
  List<String> get allInputImageUrls {
    final out = <String>[];
    final seen = <String>{};
    void add(String? raw) {
      final u = raw?.trim() ?? '';
      if (u.isEmpty || !u.startsWith('http')) return;
      if (seen.add(u)) out.add(u);
    }

    for (final u in inputImageUrls) {
      add(u);
    }
    add(inputImageUrl);
    return out;
  }

  factory GenerationModel.fromJson(Map<String, dynamic> json) =>
      GenerationModel(
        id: json['id']?.toString() ?? '',
        toolSlug: json['tool_slug']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        userId: json['user_id']?.toString(),
        source: json['source']?.toString(),
        inputImageUrl: json['input_image_url']?.toString(),
        inputImageUrls: _parseUrlList(
          json['input_image_urls'] ??
              json['input_images'] ??
              json['input_image_paths'],
        ),
        outputImageUrl: json['output_image_url']?.toString(),
        styleNotes: json['style_notes']?.toString(),
        settings: json['settings'] is Map
            ? asJsonMap(json['settings'])
            : const {},
        creditCost: (json['credit_cost'] as num?)?.toInt() ?? 0,
        errorMessage: json['error_message']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.tryParse(json['completed_at'].toString())
            : null,
      );

  static List<String> _parseUrlList(dynamic raw) {
    if (raw == null) return const [];
    final out = <String>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          out.add(item.trim());
        } else if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final u = (map['url'] ?? map['image_url'] ?? map['path'])?.toString();
          if (u != null && u.trim().isNotEmpty) out.add(u.trim());
        }
      }
    }
    return out;
  }
}

class UploadResult {
  const UploadResult({required this.path, required this.url});

  final String path;
  final String url;

  factory UploadResult.fromJson(Map<String, dynamic> json) => UploadResult(
        path: json['path']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
      );
}
