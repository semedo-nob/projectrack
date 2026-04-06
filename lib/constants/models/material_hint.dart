// lib/constants/models/material_hint.dart

/// Optional metadata when resolving smart unit suggestions.
class MaterialHint {
  const MaterialHint({
    this.normalizedName = '',
    this.categoryGuess,
  });

  final String normalizedName;
  final String? categoryGuess;
}
