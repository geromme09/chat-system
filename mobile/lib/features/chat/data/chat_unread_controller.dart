import 'package:flutter/foundation.dart';

import '../../../core/session/app_session.dart';
import 'chat_api.dart';

class ChatUnreadController extends ChangeNotifier {
  ChatUnreadController({
    ChatApi? api,
  }) : _api = api ?? ChatApi();

  final ChatApi _api;

  int _total = 0;
  bool _isLoading = false;

  int get total => _total;
  bool get hasUnread => _total > 0;
  String get badgeLabel => _total > 99 ? '99+' : '$_total';

  Future<void> refresh() async {
    final token = appSession.token;
    if (token == null || token.isEmpty || _isLoading) {
      if (token == null || token.isEmpty) {
        _total = 0;
        notifyListeners();
      }
      return;
    }

    _isLoading = true;
    try {
      final unread = await _api.getUnreadCount(token: token);
      _total = unread.total;
      notifyListeners();
    } catch (_) {
      // Keep the last known badge value if refresh fails.
    } finally {
      _isLoading = false;
    }
  }

  void clear() {
    _total = 0;
    notifyListeners();
  }
}

final ChatUnreadController chatUnreadController = ChatUnreadController();
