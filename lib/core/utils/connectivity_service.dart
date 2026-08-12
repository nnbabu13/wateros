import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _controller.stream;
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  void initialize() {
    _connectivity.onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _isConnected = result != ConnectivityResult.none;
      _controller.add(_isConnected);
    });
  }

  Future<bool> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _isConnected = result != ConnectivityResult.none;
    return _isConnected;
  }

  void dispose() {
    _controller.close();
  }
}
