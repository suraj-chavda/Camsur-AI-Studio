/// Safe JSON map/list casting for Dio / jsonDecode payloads.
Map<String, dynamic> asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected a JSON object, got ${value.runtimeType}');
}

List<dynamic> asJsonList(dynamic value) {
  if (value == null) return const [];
  if (value is List<dynamic>) return value;
  if (value is List) return List<dynamic>.from(value);
  throw FormatException('Expected a JSON array, got ${value.runtimeType}');
}
