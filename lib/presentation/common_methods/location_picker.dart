import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';

class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();

  final TextEditingController _longitudeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // fetch user's current location on load
  }

  // ✅ Get current location
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location permissions are permanently denied"),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng pos = LatLng(position.latitude, position.longitude);

      _addressController.text = await CommonMethods.getAddressFromLatLng(pos);
      setState(() => _currentLatLng = pos);

      _latitudeController.text = pos.latitude.toStringAsFixed(6);

      _longitudeController.text = pos.longitude.toStringAsFixed(6);

      // Move camera to user's location
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
    } catch (e) {
      debugPrint("Error getting location: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _moveToCoordinates() async {
    final lat = double.tryParse(_latitudeController.text);

    final lng = double.tryParse(_longitudeController.text);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid coordinates")));
      return;
    }

    final position = LatLng(lat, lng);

    setState(() {
      _currentLatLng = position;
    });

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));

    _addressController.text = await CommonMethods.getAddressFromLatLng(
      position,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentLatLng == null
              ? const Center(child: Text('Fetching location...'))
              : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLatLng!,
                      zoom: 15,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    onCameraMove: (position) {
                      setState(() {
                        _currentLatLng = position.target;
                      });
                    },
                    onCameraIdle: () async {
                      if (_currentLatLng != null) {
                        _addressController
                            .text = await CommonMethods.getAddressFromLatLng(
                          _currentLatLng!,
                        );

                        _latitudeController.text = _currentLatLng!.latitude
                            .toStringAsFixed(6);

                        _longitudeController.text = _currentLatLng!.longitude
                            .toStringAsFixed(6);
                        if (!mounted) return;
                        setState(() {});
                      }
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                  ),

                  // Center marker (fixed)
                  const Center(
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 45,
                    ),
                  ),

                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: Icon(
                        Icons.gps_fixed,
                        color:
                            _addressController.text.isEmpty
                                ? Colors.black54
                                : Colors.blue,
                      ),
                      onPressed: _getCurrentLocation,
                    ),
                  ),

                  // Bottom section with address + confirm
                  Positioned(
                    bottom: 30,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        // Address text field
                        Column(
                          children: [
                            Container(
                              color: Colors.white,
                              child: TextFormField(
                                controller: _addressController,
                                decoration: const InputDecoration(
                                  labelText: "*Address",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _latitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: "Latitude",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                Expanded(
                                  child: TextFormField(
                                    controller: _longitudeController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: "Longitude",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _moveToCoordinates,
                                icon: const Icon(Icons.location_searching),
                                label: const Text("Locate Coordinates"),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SafeArea(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Address address = Address(
                                latLng: _currentLatLng!,
                                addressText: _addressController.text,
                              );
                              Navigator.pop(context, address);
                            },
                            icon: const Icon(
                              Icons.check,
                              color: AppColors.WHITE,
                            ),
                            label: const Text(
                              'Confirm Location',
                              style: TextStyle(color: AppColors.WHITE),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(45),
                              backgroundColor: AppColors.THEME_COLOR,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}

class Address {
  LatLng latLng;
  String addressText;

  Address({required this.latLng, required this.addressText});
}
