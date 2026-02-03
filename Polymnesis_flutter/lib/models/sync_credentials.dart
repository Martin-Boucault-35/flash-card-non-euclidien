/// Credentials pour la synchronisation Supabase
class SyncCredentials {
  final String url;
  final String key;
  final bool enabled;

  SyncCredentials({
    this.url = '',
    this.key = '',
    this.enabled = false,
  });

  SyncCredentials copyWith({
    String? url,
    String? key,
    bool? enabled,
  }) {
    return SyncCredentials(
      url: url ?? this.url,
      key: key ?? this.key,
      enabled: enabled ?? this.enabled,
    );
  }

  factory SyncCredentials.fromJson(Map<String, dynamic> json) {
    return SyncCredentials(
      url: json['url'] as String? ?? '',
      key: json['key'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'key': key,
      'enabled': enabled,
    };
  }

  bool get isConfigured => url.isNotEmpty && key.isNotEmpty;
}
