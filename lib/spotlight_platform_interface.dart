import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'spotlight_method_channel.dart';

typedef OnCallHandler =
    Future<void> Function(
      CallHandlerType type,
      String input,
      ResultUpdater updater,
    );

enum CallHandlerType { onTranslate, onSearch }

class ResultUpdater {
  final Future<void> Function(String? text) _updater;

  const ResultUpdater(this._updater);

  Future<void> update(String text) => _updater(text);

  Future<void> finished() => _updater(null);
}

abstract class SpotlightPlatform extends PlatformInterface {
  /// Constructs a SpotlightPlatform.
  SpotlightPlatform() : super(token: _token);

  static final Object _token = Object();

  static SpotlightPlatform _instance = MethodChannelSpotlight();

  /// The default instance of [SpotlightPlatform] to use.
  ///
  /// Defaults to [MethodChannelSpotlight].
  static SpotlightPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SpotlightPlatform] when
  /// they register themselves.
  static set instance(SpotlightPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  OnCallHandler? _onCallHandler;

  OnCallHandler? get onCallHandler => _onCallHandler;

  Future<void> show();

  Future<void> hide();

  Future<void> updateResult(String? text);

  void setOnCallHandler(OnCallHandler handler) {
    _onCallHandler = handler;
  }
}
