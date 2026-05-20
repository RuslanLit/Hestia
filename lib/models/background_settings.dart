enum BackgroundType {
  defaultTheme,
  color,
  image,
}

class BackgroundSettings {
  final BackgroundType type;
  final int? colorValue;
  final String? imagePath;

  const BackgroundSettings({
    this.type = BackgroundType.defaultTheme,
    this.colorValue,
    this.imagePath,
  });

  factory BackgroundSettings.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = switch (typeName) {
      'color' => BackgroundType.color,
      'image' => BackgroundType.image,
      _ => BackgroundType.defaultTheme,
    };

    return BackgroundSettings(
      type: type,
      colorValue: (json['color'] as num?)?.toInt(),
      imagePath: json['imagePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': switch (type) {
          BackgroundType.defaultTheme => 'default',
          BackgroundType.color => 'color',
          BackgroundType.image => 'image',
        },
        if (colorValue != null) 'color': colorValue,
        if (imagePath != null) 'imagePath': imagePath,
      };

  BackgroundSettings copyWith({
    BackgroundType? type,
    int? colorValue,
    String? imagePath,
  }) =>
      BackgroundSettings(
        type: type ?? this.type,
        colorValue: colorValue ?? this.colorValue,
        imagePath: imagePath ?? this.imagePath,
      );
}


