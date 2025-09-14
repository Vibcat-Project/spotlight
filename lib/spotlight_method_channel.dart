import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:spotlight/ext.dart';

import 'spotlight_platform_interface.dart';

/// An implementation of [SpotlightPlatform] that uses method channels.
class MethodChannelSpotlight extends SpotlightPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('spotlight');

  late final ResultUpdater _resultUpdater;

  MethodChannelSpotlight() {
    methodChannel.setMethodCallHandler(_handleCall);
    _resultUpdater = ResultUpdater(updateResult);
  }

  Future<void> _handleCall(MethodCall call) async {
    if (onCallHandler == null) return;

    final input = call.arguments as String?;
    if (input == null) return;

    CallHandlerType? type = call.method.toEnum(CallHandlerType.values);
    if (type == null) return;

    await onCallHandler!(type, input, _resultUpdater);
  }

  @override
  Future<void> show() => methodChannel.invokeMethod('show');

  @override
  Future<void> hide() => methodChannel.invokeMethod('hide');

  @override
  Future<void> updateResult(String? text) =>
      methodChannel.invokeMethod('updateResult', text);
}
