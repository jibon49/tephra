// © 2026 Tephra. All rights reserved.

/// Options configuring the editor's indentation, sizing, and display mode.
final class EditorOptions {
  const EditorOptions({
    this.useTab = true,
    this.tabSize = 4,
    this.fontSize = 16,
    this.readableLineLength = true,
    this.readOnly = false,
  });

  final bool useTab;
  final int tabSize;
  final double fontSize;
  final bool readableLineLength;
  final bool readOnly;

  String get indentUnit => useTab ? '\t' : ' ' * tabSize;

  EditorOptions copyWith({
    bool? useTab,
    int? tabSize,
    double? fontSize,
    bool? readableLineLength,
    bool? readOnly,
  }) => EditorOptions(
    useTab: useTab ?? this.useTab,
    tabSize: tabSize ?? this.tabSize,
    fontSize: fontSize ?? this.fontSize,
    readableLineLength: readableLineLength ?? this.readableLineLength,
    readOnly: readOnly ?? this.readOnly,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorOptions &&
          useTab == other.useTab &&
          tabSize == other.tabSize &&
          fontSize == other.fontSize &&
          readableLineLength == other.readableLineLength &&
          readOnly == other.readOnly;

  @override
  int get hashCode =>
      Object.hash(useTab, tabSize, fontSize, readableLineLength, readOnly);

  @override
  String toString() =>
      'EditorOptions(useTab: $useTab, tabSize: $tabSize, fontSize: $fontSize, readableLineLength: $readableLineLength, readOnly: $readOnly)';
}
