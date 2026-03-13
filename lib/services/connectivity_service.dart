import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal() {
    _initialize();
  }

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  Stream<bool> get onlineStream => _onlineController.stream;

  Future<void> _initialize() async {
    await refreshStatus();

    _subscription ??= _connectivity.onConnectivityChanged.listen((result) {
      final online = _isConnected(result);
      _isOnline = online;
      _onlineController.add(online);
    });
  }

  Future<bool> refreshStatus() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result);
    _onlineController.add(_isOnline);
    return _isOnline;
  }

  bool _isConnected(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }

    if (result is List<ConnectivityResult>) {
      return result.any((r) => r != ConnectivityResult.none);
    }

    return true;
  }
}
