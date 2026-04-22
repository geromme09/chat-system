import 'package:flutter/foundation.dart';

class SessionProfile {
  const SessionProfile({
    required this.displayName,
    required this.bio,
    required this.city,
    required this.country,
    required this.sports,
    required this.skillLevel,
    required this.visible,
  });

  final String displayName;
  final String bio;
  final String city;
  final String country;
  final List<String> sports;
  final String skillLevel;
  final bool visible;

  factory SessionProfile.fromJson(Map<String, dynamic> json) {
    return SessionProfile(
      displayName: json['display_name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      sports: (json['sports'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      skillLevel: json['skill_level'] as String? ?? '',
      visible: json['visible'] as bool? ?? true,
    );
  }

  SessionProfile copyWith({
    String? displayName,
    String? bio,
    String? city,
    String? country,
    List<String>? sports,
    String? skillLevel,
    bool? visible,
  }) {
    return SessionProfile(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      country: country ?? this.country,
      sports: sports ?? this.sports,
      skillLevel: skillLevel ?? this.skillLevel,
      visible: visible ?? this.visible,
    );
  }
}

class AppSession extends ChangeNotifier {
  String? _token;
  String? _userID;
  SessionProfile? _profile;
  String? _customStatus;

  String? get token => _token;
  String? get userID => _userID;
  SessionProfile? get profile => _profile;
  String? get customStatus => _customStatus;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void setSession({
    required String token,
    required String userID,
    required SessionProfile profile,
  }) {
    _token = token;
    _userID = userID;
    _profile = profile;
    _customStatus = null;
    notifyListeners();
  }

  void updateProfile(SessionProfile profile) {
    _profile = profile;
    notifyListeners();
  }

  void updateCustomStatus(String status) {
    _customStatus = status.trim();
    notifyListeners();
  }

  void clear() {
    _token = null;
    _userID = null;
    _profile = null;
    _customStatus = null;
    notifyListeners();
  }
}

final AppSession appSession = AppSession();
