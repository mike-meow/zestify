/// Base model class that all models should extend
abstract class BaseModel {
  /// Convert model to JSON map
  Map<String, dynamic> toJson();
}
