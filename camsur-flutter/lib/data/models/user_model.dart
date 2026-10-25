class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.deviceId,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? deviceId;

  String get greetingName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.split(' ').first
          : email.split('@').first;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'].toString(),
        email: json['email']?.toString() ?? '',
        displayName: json['display_name']?.toString(),
        deviceId: json['device_id']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'device_id': deviceId,
      };
}
