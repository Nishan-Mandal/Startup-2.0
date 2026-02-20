class CategoryField {
  final String label;
  final String type;
  final String? keyboardType;
  final List<String>? options;

  CategoryField({
    required this.label,
    required this.type,
    this.keyboardType,
    this.options,
  });

  factory CategoryField.fromJson(Map<String, dynamic> json) {
    return CategoryField(
      label: json['label'],
      type: json['type'],
      keyboardType: json['keyboardType'] ?? 'text',
      options:
          json['options'] != null ? List<String>.from(json['options']) : null,
    );
  }
}