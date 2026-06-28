/// Paramètres pour l'import depuis "chuut".
///
/// On stocke uniquement le jeton de connexion (Bearer). Il expire au bout d'un
/// certain temps : l'utilisateur peut le remplacer depuis l'écran Paramètres.
class LtdsSettings {
  final String token;

  LtdsSettings({this.token = ''});

  LtdsSettings copyWith({String? token}) {
    return LtdsSettings(token: token ?? this.token);
  }

  factory LtdsSettings.fromJson(Map<String, dynamic> json) {
    return LtdsSettings(token: json['token'] as String? ?? '');
  }

  Map<String, dynamic> toJson() => {'token': token};

  bool get isConfigured => token.trim().isNotEmpty;
}
