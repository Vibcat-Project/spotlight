extension EnumExt on String {
  /// 将 String 转换为 Enum
  /// - [values] 是枚举类的 `values`
  /// - [orElse] 可选，找不到时的默认值
  T? toEnum<T extends Enum>(Iterable<T> values, {T? orElse}) {
    try {
      return values.firstWhere((e) => e.name == this);
    } catch (_) {
      return orElse;
    }
  }
}
