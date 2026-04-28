import 'package:flutter/foundation.dart';

class SessionProfile {
  const SessionProfile({
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    required this.city,
    required this.country,
    required this.gender,
    required this.hobbiesText,
    required this.visible,
  });

  final String displayName;
  final String bio;
  final String avatarUrl;
  final String city;
  final String country;
  final String gender;
  final String hobbiesText;
  final bool visible;

  factory SessionProfile.fromJson(Map<String, dynamic> json) {
    return SessionProfile(
      displayName: json['display_name'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      hobbiesText: json['hobbies_text'] as String? ?? '',
      visible: json['visible'] as bool? ?? true,
    );
  }

  SessionProfile copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? city,
    String? country,
    String? gender,
    String? hobbiesText,
    bool? visible,
  }) {
    return SessionProfile(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      city: city ?? this.city,
      country: country ?? this.country,
      gender: gender ?? this.gender,
      hobbiesText: hobbiesText ?? this.hobbiesText,
      visible: visible ?? this.visible,
    );
  }
}

class AppSession extends ChangeNotifier {
  String? _token;
  String? _userID;
  String? _username;
  String? _email;
  SessionProfile? _profile;
  bool _profileComplete = false;
  String? _customStatus;

  String? get token => _token;
  String? get userID => _userID;
  String? get username => _username;
  String? get email => _email;
  SessionProfile? get profile => _profile;
  bool get profileComplete => _profileComplete;
  String? get customStatus => _customStatus;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  void setSession({
    required String token,
    required String userID,
    required SessionProfile profile,
    required bool profileComplete,
    String username = '',
    String email = '',
  }) {
    _token = token;
    _userID = userID;
    _username = username;
    _email = email;
    _profile = profile;
    _profileComplete = profileComplete;
    _customStatus = null;
    notifyListeners();
  }

  void updateProfile(SessionProfile profile, {bool? profileComplete}) {
    _profile = profile;
    _profileComplete = profileComplete ?? _profileComplete;
    notifyListeners();
  }

  void updateCustomStatus(String status) {
    _customStatus = status.trim();
    notifyListeners();
  }

  void clear() {
    _token = null;
    _userID = null;
    _username = null;
    _email = null;
    _profile = null;
    _profileComplete = false;
    _customStatus = null;
    notifyListeners();
  }
}

final AppSession appSession = AppSession();
