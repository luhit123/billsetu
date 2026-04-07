import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Owner/Co-owner screen to set the office geofence location via map.
class OfficeLocationScreen extends StatefulWidget {
  const OfficeLocationScreen({super.key});

  @override
  State<OfficeLocationScreen> createState() => _OfficeLocationScreenState();
}

class _OfficeLocationScreenState extends State<OfficeLocationScreen> {
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  LatLng? _selectedLocation;
  double _radius = 200;
  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  GoogleMapController? _mapController;

  // Default to India center
  static const _defaultCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final team = TeamService.instance.cachedTeam;
    if (team != null && team.hasOfficeLocation) {
      _selectedLocation = LatLng(team.officeLatitude!, team.officeLongitude!);
      _radius = team.officeRadius;
      _addressController.text = team.officeAddress;
      _syncCoordinateFields();
    }
    setState(() => _loading = false);
  }

  void _syncCoordinateFields() {
    if (_selectedLocation == null) {
      _latController.clear();
      _lngController.clear();
      return;
    }
    _latController.text = _selectedLocation!.latitude.toStringAsFixed(6);
    _lngController.text = _selectedLocation!.longitude.toStringAsFixed(6);
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable Location Services in device settings'),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Enable in Settings.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final loc = LatLng(position.latitude, position.longitude);

      _updateSelectedLocation(loc);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 17));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFriendlyError(
                e,
                fallback: 'Could not get your location. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _searchAddress() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Web address search is not available yet. Enter the address manually and use current location or coordinates below.',
            ),
          ),
        );
      }
      return;
    }
    final query = _addressController.text.trim();
    if (query.isEmpty) return;
    setState(() => _locating = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = LatLng(locations.first.latitude, locations.first.longitude);
        _updateSelectedLocation(loc);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 17));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Address not found')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFriendlyError(
                e,
                fallback: 'Address search failed. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onMapTap(LatLng position) {
    _updateSelectedLocation(position);
  }

  Future<void> _updateSelectedLocation(LatLng loc) async {
    setState(() => _selectedLocation = loc);
    _syncCoordinateFields();
    if (kIsWeb) {
      if (mounted) setState(() {});
      return;
    }
    // Reverse geocode
    try {
      final placemarks = await placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final address = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        if (address.isNotEmpty) {
          _addressController.text = address;
        }
      }
    } catch (e) {
      debugPrint('[OfficeLocation] Reverse geocoding failed: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _applyManualCoordinates() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid latitude and longitude values'),
        ),
      );
      return;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Latitude must be between -90 and 90, longitude between -180 and 180',
          ),
        ),
      );
      return;
    }
    final loc = LatLng(lat, lng);
    await _updateSelectedLocation(loc);
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 17));
  }

  Future<void> _openInMaps() async {
    final location = _selectedLocation;
    if (location == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _save() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap the map to set a location')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await TeamService.instance.updateOfficeLocation(
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        radius: _radius,
        address: _addressController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Office location saved!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFriendlyError(
                e,
                fallback: 'Failed to save office location. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Office Location')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Office Location'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      hintText: 'Search address...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onSubmitted: (_) => _searchAddress(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _locating ? null : _goToCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 20),
                  tooltip: 'My location',
                ),
              ],
            ),
          ),

          Expanded(
            child: kIsWeb ? _buildWebLocationPanel() : _buildNativeMapPanel(),
          ),

          // Radius slider
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: context.cs.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Geofence Radius: ${_radius.toInt()}m',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _radius,
                  min: 50,
                  max: 500,
                  divisions: 18,
                  label: '${_radius.toInt()}m',
                  onChanged: (v) => setState(() => _radius = v),
                ),
              ],
            ),
          ),

          // Selected location info
          if (_selectedLocation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              color: context.cs.surface,
              child: Text(
                '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 11,
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNativeMapPanel() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _selectedLocation ?? _defaultCenter,
            zoom: _selectedLocation != null ? 17 : 5,
          ),
          onMapCreated: (controller) => _mapController = controller,
          onTap: _onMapTap,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: _selectedLocation != null
              ? {
                  Marker(
                    markerId: const MarkerId('office'),
                    position: _selectedLocation!,
                    infoWindow: const InfoWindow(title: 'Office Location'),
                  ),
                }
              : {},
          circles: _selectedLocation != null
              ? {
                  Circle(
                    circleId: const CircleId('geofence'),
                    center: _selectedLocation!,
                    radius: _radius,
                    fillColor: kPrimary.withAlpha(30),
                    strokeColor: kPrimary,
                    strokeWidth: 2,
                  ),
                }
              : {},
        ),
        if (_selectedLocation == null)
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Tap on the map to set office location',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebLocationPanel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [kSubtleShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set office location on web',
                style: TextStyle(
                  color: context.cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use your current location or enter latitude and longitude manually. The address field above will be saved as entered.',
                style: TextStyle(
                  color: context.cs.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _applyManualCoordinates,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Apply Coordinates'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _goToCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('Use Current Location'),
                  ),
                  if (_selectedLocation != null)
                    OutlinedButton.icon(
                      onPressed: _openInMaps,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open in Maps'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _selectedLocation == null
                ? context.cs.surfaceContainerLow
                : context.cs.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _selectedLocation == null
                ? 'No office location selected yet.'
                : 'Selected: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
            style: TextStyle(
              color: context.cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
