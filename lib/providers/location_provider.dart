import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup_20/core/constants/app_locations.dart';

class LocationProvider extends ChangeNotifier {
  AppLocation _selectedLocation = AppLocationMasterList.defaultLocation;
  Position? _userPosition;
  bool _isLoading = false;
  bool _isAutoDetected = false;
  String? _errorMessage;

  AppLocation get selectedLocation => _selectedLocation;
  Position? get userPosition => _userPosition;
  bool get isLoading => _isLoading;
  bool get isAutoDetected => _isAutoDetected;
  String? get errorMessage => _errorMessage;

  LocationProvider() {
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('selected_location_name');
      final savedDistrict = prefs.getString('selected_location_district');

      if (savedName != null && savedDistrict != null) {
        final match = AppLocationMasterList.allLocations.firstWhere(
          (loc) => loc.name == savedName && loc.district == savedDistrict,
          orElse: () => AppLocationMasterList.defaultLocation,
        );
        _selectedLocation = match;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading saved location: $e");
    }
  }

  /// Automatically requests in-app permission and detects nearest location from the Master List
  Future<void> initLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isLoading = false;
          _errorMessage = "Location permission denied.";
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isLoading = false;
        _errorMessage = "Location permissions are permanently denied.";
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      _userPosition = position;

      // Find the nearest location in the Master List
      final nearest = findNearestLocation(position.latitude, position.longitude);
      _selectedLocation = nearest;
      _isAutoDetected = true;

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_location_name', nearest.name);
      await prefs.setString('selected_location_district', nearest.district);
    } catch (e) {
      debugPrint("Error detecting location in LocationProvider: $e");
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Finds the closest location among the 64 Master Locations
  AppLocation findNearestLocation(double userLat, double userLng) {
    AppLocation closest = AppLocationMasterList.defaultLocation;
    double minDistance = double.infinity;

    for (final loc in AppLocationMasterList.allLocations) {
      final distance = Geolocator.distanceBetween(
        userLat,
        userLng,
        loc.latitude,
        loc.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closest = loc;
      }
    }

    return closest;
  }

  /// Manually select a location from the UI
  Future<void> setLocation(AppLocation location) async {
    _selectedLocation = location;
    _isAutoDetected = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_location_name', location.name);
      await prefs.setString('selected_location_district', location.district);
    } catch (e) {
      debugPrint("Error saving selected location: $e");
    }
  }
}
