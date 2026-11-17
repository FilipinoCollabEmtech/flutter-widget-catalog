import 'package:latlong2/latlong.dart';

/// A named point of interest in Cebu City.
///
/// Loaded from `assets/data/landmarks.csv` (columns:
/// `name,lat,lng,category,code,barangay,address`).  Only `name`, `lat` and
/// `lng` are required; the rest may be blank in the source file.
class Landmark {
  final String name;
  final LatLng point;
  final String category;
  final String code;
  final String barangay;
  final String address;

  const Landmark({
    required this.name,
    required this.point,
    this.category = '',
    this.code = '',
    this.barangay = '',
    this.address = '',
  });

  @override
  String toString() => 'Landmark($name, ${point.latitude}, ${point.longitude})';
}
