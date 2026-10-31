class AppLocation {
  final String name;
  final String district;
  final String state;
  final double latitude;
  final double longitude;

  const AppLocation({
    required this.name,
    required this.district,
    this.state = "West Bengal",
    required this.latitude,
    required this.longitude,
  });

  String get shortName => name;
  String get displayName => "$name, $district";
  String get fullDisplayName => "$name, $state";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppLocation &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          district == other.district;

  @override
  int get hashCode => name.hashCode ^ district.hashCode;
}

class AppLocationMasterList {
  static const AppLocation defaultLocation = AppLocation(
    name: "Haldia",
    district: "Purba Medinipur",
    latitude: 22.0638,
    longitude: 88.0772,
  );

  /// 🔹 A. Purba Medinipur (East Midnapore) - 39 Locations
  static const List<AppLocation> purbaMedinipur = [
    AppLocation(name: "Bajkul", district: "Purba Medinipur", latitude: 22.0150, longitude: 87.7950),
    AppLocation(name: "Barda", district: "Purba Medinipur", latitude: 22.1200, longitude: 88.0100),
    AppLocation(name: "Basantia", district: "Purba Medinipur", latitude: 21.8900, longitude: 87.6800),
    AppLocation(name: "Bhagabanpur", district: "Purba Medinipur", latitude: 22.0300, longitude: 87.7500),
    AppLocation(name: "Bhogpur", district: "Purba Medinipur", latitude: 22.4000, longitude: 87.8500),
    AppLocation(name: "Bhupatinagar", district: "Purba Medinipur", latitude: 21.9600, longitude: 87.6500),
    AppLocation(name: "Chaitanyapur", district: "Purba Medinipur", latitude: 22.1800, longitude: 88.0800),
    AppLocation(name: "Chandipur", district: "Purba Medinipur", latitude: 22.1100, longitude: 87.8600),
    AppLocation(name: "Contai", district: "Purba Medinipur", latitude: 21.7800, longitude: 87.7500),
    AppLocation(name: "Deulihat", district: "Purba Medinipur", latitude: 22.2500, longitude: 87.9000),
    AppLocation(name: "Deshapran", district: "Purba Medinipur", latitude: 21.7500, longitude: 87.8000),
    AppLocation(name: "Digha", district: "Purba Medinipur", latitude: 21.6266, longitude: 87.5074),
    AppLocation(name: "Durgachak", district: "Purba Medinipur", latitude: 22.0600, longitude: 88.1100),
    AppLocation(name: "Egra", district: "Purba Medinipur", latitude: 21.9000, longitude: 87.5400),
    AppLocation(name: "Geonkhali", district: "Purba Medinipur", latitude: 22.2100, longitude: 88.0500),
    AppLocation(name: "Haldia", district: "Purba Medinipur", latitude: 22.0638, longitude: 88.0772),
    AppLocation(name: "Heria", district: "Purba Medinipur", latitude: 21.9300, longitude: 87.8000),
    AppLocation(name: "Junput", district: "Purba Medinipur", latitude: 21.7200, longitude: 87.8200),
    AppLocation(name: "Kajlagarh", district: "Purba Medinipur", latitude: 22.0200, longitude: 87.7800),
    AppLocation(name: "Khejuri", district: "Purba Medinipur", latitude: 21.8700, longitude: 87.9300),
    AppLocation(name: "Kolaghat", district: "Purba Medinipur", latitude: 22.4300, longitude: 87.8700),
    AppLocation(name: "Mahishadal", district: "Purba Medinipur", latitude: 22.1800, longitude: 87.9800),
    AppLocation(name: "Mandarmani", district: "Purba Medinipur", latitude: 21.6700, longitude: 87.7100),
    AppLocation(name: "Marishda", district: "Purba Medinipur", latitude: 21.8400, longitude: 87.7700),
    AppLocation(name: "Mecheda", district: "Purba Medinipur", latitude: 22.4200, longitude: 87.8600),
    AppLocation(name: "Moyna", district: "Purba Medinipur", latitude: 22.2500, longitude: 87.7800),
    AppLocation(name: "Mugberia", district: "Purba Medinipur", latitude: 21.9800, longitude: 87.6700),
    AppLocation(name: "Nandakumar", district: "Purba Medinipur", latitude: 22.2100, longitude: 87.9100),
    AppLocation(name: "Nandigram", district: "Purba Medinipur", latitude: 22.0000, longitude: 87.9900),
    AppLocation(name: "Nachinda", district: "Purba Medinipur", latitude: 21.7300, longitude: 87.6500),
    AppLocation(name: "Paniparul", district: "Purba Medinipur", latitude: 21.8500, longitude: 87.5000),
    AppLocation(name: "Panskura", district: "Purba Medinipur", latitude: 22.4200, longitude: 87.7400),
    AppLocation(name: "Patashpur", district: "Purba Medinipur", latitude: 22.0400, longitude: 87.5800),
    AppLocation(name: "Radhamani", district: "Purba Medinipur", latitude: 22.2800, longitude: 87.8800),
    AppLocation(name: "Ramnagar", district: "Purba Medinipur", latitude: 21.6800, longitude: 87.5500),
    AppLocation(name: "Shankarpur", district: "Purba Medinipur", latitude: 21.6400, longitude: 87.5700),
    AppLocation(name: "Sutahata", district: "Purba Medinipur", latitude: 22.1400, longitude: 88.0800),
    AppLocation(name: "Tajpur", district: "Purba Medinipur", latitude: 21.6500, longitude: 87.6300),
    AppLocation(name: "Tamluk", district: "Purba Medinipur", latitude: 22.3000, longitude: 87.9200),
  ];

  /// 🔹 B. Paschim Medinipur (West Midnapore) - 25 Locations
  static const List<AppLocation> paschimMedinipur = [
    AppLocation(name: "Anandapur", district: "Paschim Medinipur", latitude: 22.6000, longitude: 87.4500),
    AppLocation(name: "Belda", district: "Paschim Medinipur", latitude: 22.0800, longitude: 87.3500),
    AppLocation(name: "Chandrakona", district: "Paschim Medinipur", latitude: 22.7300, longitude: 87.5200),
    AppLocation(name: "Chandrakona Road", district: "Paschim Medinipur", latitude: 22.6800, longitude: 87.3500),
    AppLocation(name: "Dantan", district: "Paschim Medinipur", latitude: 21.9500, longitude: 87.2700),
    AppLocation(name: "Daspur", district: "Paschim Medinipur", latitude: 22.6100, longitude: 87.7200),
    AppLocation(name: "Debra", district: "Paschim Medinipur", latitude: 22.3900, longitude: 87.5700),
    AppLocation(name: "Garhbeta", district: "Paschim Medinipur", latitude: 22.8600, longitude: 87.3500),
    AppLocation(name: "Ghatal", district: "Paschim Medinipur", latitude: 22.6700, longitude: 87.7200),
    AppLocation(name: "Goaltore", district: "Paschim Medinipur", latitude: 22.7100, longitude: 87.1800),
    AppLocation(name: "Hijli", district: "Paschim Medinipur", latitude: 22.3200, longitude: 87.3100),
    AppLocation(name: "Kalaikunda", district: "Paschim Medinipur", latitude: 22.3400, longitude: 87.2200),
    AppLocation(name: "Keshpur", district: "Paschim Medinipur", latitude: 22.5500, longitude: 87.4600),
    AppLocation(name: "Keshiary", district: "Paschim Medinipur", latitude: 22.1200, longitude: 87.2300),
    AppLocation(name: "Kharagpur", district: "Paschim Medinipur", latitude: 22.3400, longitude: 87.3200),
    AppLocation(name: "Kharar", district: "Paschim Medinipur", latitude: 22.7000, longitude: 87.6800),
    AppLocation(name: "Khirpai", district: "Paschim Medinipur", latitude: 22.7100, longitude: 87.6200),
    AppLocation(name: "Medinipur", district: "Paschim Medinipur", latitude: 22.4300, longitude: 87.3200),
    AppLocation(name: "Mohanpur", district: "Paschim Medinipur", latitude: 21.8400, longitude: 87.3800),
    AppLocation(name: "Narayangarh", district: "Paschim Medinipur", latitude: 22.1800, longitude: 87.3800),
    AppLocation(name: "Pingla", district: "Paschim Medinipur", latitude: 22.2700, longitude: 87.5800),
    AppLocation(name: "Ramjibanpur", district: "Paschim Medinipur", latitude: 22.8300, longitude: 87.6200),
    AppLocation(name: "Rohini", district: "Paschim Medinipur", latitude: 22.0200, longitude: 87.1500),
    AppLocation(name: "Sabang", district: "Paschim Medinipur", latitude: 22.1700, longitude: 87.6000),
    AppLocation(name: "Salboni", district: "Paschim Medinipur", latitude: 22.6400, longitude: 87.3200),
  ];

  /// 🔹 All 64 Locations combined
  static List<AppLocation> get allLocations => [
    ...purbaMedinipur,
    ...paschimMedinipur,
  ];
}
