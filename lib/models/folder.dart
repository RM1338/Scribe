class Folder {
  final String id;
  final String name;
  final int colorValue;
  final String? icon;

  const Folder({
    required this.id,
    required this.name,
    required this.colorValue,
    this.icon,
  });

  factory Folder.fromJson(Map<String, dynamic> json) {
    return Folder(
      id: json['id'] as String,
      name: json['name'] as String,
      colorValue: json['colorValue'] as int,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'icon': icon,
  };
}
