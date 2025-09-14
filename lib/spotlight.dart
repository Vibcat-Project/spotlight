import 'spotlight_platform_interface.dart';

class Spotlight {
  /// 显示 Spotlight 窗口
  Future<void> show() {
    return SpotlightPlatform.instance.show();
  }

  /// 隐藏 Spotlight 窗口
  Future<void> hide() {
    return SpotlightPlatform.instance.hide();
  }

  /// 更新结果内容
  static Future<void> updateResult(String text) {
    return SpotlightPlatform.instance.updateResult(text);
  }

  /// 注册 Flutter 回调 (原生调用 "onQuery" 的时候触发)
  static void setOnCallHandler(OnCallHandler handler) {
    SpotlightPlatform.instance.setOnCallHandler(handler);
  }
}
