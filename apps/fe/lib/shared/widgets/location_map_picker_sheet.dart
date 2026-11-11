import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Structured result returned when a user selects a delivery or meetup point
/// on the interactive map picker.
class PickedLocationResult {
  const PickedLocationResult({
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.detailNote,
  });

  final String title;
  final String address;
  final double latitude;
  final double longitude;
  final String? detailNote;

  /// Full formatted address string suitable for `shippingAddress` or `meetupLocation`.
  String get formattedAddress {
    final parts = <String>[];
    if (detailNote != null && detailNote!.trim().isNotEmpty) {
      parts.add(detailNote!.trim());
    }
    if (title.trim().isNotEmpty &&
        !address.toLowerCase().contains(title.trim().toLowerCase())) {
      parts.add(title.trim());
    }
    if (address.trim().isNotEmpty) {
      parts.add(address.trim());
    }
    final joined = parts.join(', ');
    return joined.isNotEmpty
        ? joined
        : 'Vị trí (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
  }
}

/// Curated university campuses, dormitories, and popular meetup/delivery hubs.
class MapPresetLocation {
  const MapPresetLocation({
    required this.shortLabel,
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.city,
  });

  final String shortLabel;
  final String title;
  final String address;
  final double latitude;
  final double longitude;
  final String city;
}

const List<MapPresetLocation> kVietnamStudentMapPresets = <MapPresetLocation>[
  MapPresetLocation(
    shortLabel: 'KTX Khu B ĐHQG',
    title: 'Ký túc xá Khu B — ĐHQG TP.HCM',
    address: 'Đường Tạ Quang Bửu, Đông Hòa, Dĩ An, Bình Dương (Làng ĐH Thủ Đức)',
    latitude: 10.8825,
    longitude: 106.7825,
    city: 'TP.HCM / Thủ Đức',
  ),
  MapPresetLocation(
    shortLabel: 'KTX Khu A ĐHQG',
    title: 'Ký túc xá Khu A — ĐHQG TP.HCM',
    address: 'Đường Quảng Trường Sáng Tạo, Linh Trung, TP. Thủ Đức, TP.HCM',
    latitude: 10.8758,
    longitude: 106.8019,
    city: 'TP.HCM / Thủ Đức',
  ),
  MapPresetLocation(
    shortLabel: 'ĐH CNTT (UIT)',
    title: 'Trường ĐH Công nghệ Thông tin (UIT — ĐHQG TP.HCM)',
    address: 'Đường Hàn Thuyên, Khu phố 6, Linh Trung, TP. Thủ Đức, TP.HCM',
    latitude: 10.8700,
    longitude: 106.8031,
    city: 'TP.HCM / Thủ Đức',
  ),
  MapPresetLocation(
    shortLabel: 'ĐH Bách Khoa Q.10',
    title: 'Trường ĐH Bách Khoa TP.HCM (Cơ sở 1)',
    address: '268 Lý Thường Kiệt, Phường 14, Quận 10, TP.HCM',
    latitude: 10.7726,
    longitude: 106.6579,
    city: 'TP.HCM',
  ),
  MapPresetLocation(
    shortLabel: 'ĐH Kinh tế (UEH)',
    title: 'Trường ĐH Kinh tế TP.HCM (Cơ sở A)',
    address: '59C Nguyễn Đình Chiểu, Phường Võ Thị Sáu, Quận 3, TP.HCM',
    latitude: 10.7828,
    longitude: 106.6952,
    city: 'TP.HCM',
  ),
  MapPresetLocation(
    shortLabel: 'ĐH KHTN Q.5',
    title: 'Trường ĐH Khoa học Tự nhiên TP.HCM',
    address: '227 Nguyễn Văn Cừ, Phường 4, Quận 5, TP.HCM',
    latitude: 10.7629,
    longitude: 106.6822,
    city: 'TP.HCM',
  ),
  MapPresetLocation(
    shortLabel: 'ĐH FPT Thủ Đức',
    title: 'Trường ĐH FPT TP.HCM (Khu Công nghệ cao)',
    address: 'Lô E2a-7, Đường D1, Khu Công nghệ cao, P. Long Thạnh Mỹ, TP. Thủ Đức',
    latitude: 10.8412,
    longitude: 106.8099,
    city: 'TP.HCM / Thủ Đức',
  ),
  MapPresetLocation(
    shortLabel: 'ĐH Sư phạm Kỹ thuật',
    title: 'Trường ĐH Sư phạm Kỹ thuật TP.HCM (HCMUTE)',
    address: '01 Võ Văn Ngân, Phường Linh Chiểu, TP. Thủ Đức, TP.HCM',
    latitude: 10.8506,
    longitude: 106.7719,
    city: 'TP.HCM / Thủ Đức',
  ),
  MapPresetLocation(
    shortLabel: 'Chợ Bến Thành Q.1',
    title: 'Khu vực Ga Metro / Chợ Bến Thành',
    address: 'Quảng trường Quách Thị Trang, Phường Bến Thành, Quận 1, TP.HCM',
    latitude: 10.7721,
    longitude: 106.6983,
    city: 'TP.HCM',
  ),
  MapPresetLocation(
    shortLabel: 'ĐH Bách Khoa Hà Nội',
    title: 'Đại học Bách Khoa Hà Nội (HUST)',
    address: 'Số 1 Đại Cồ Việt, Phường Bách Khoa, Quận Hai Bà Trưng, Hà Nội',
    latitude: 21.0071,
    longitude: 105.8432,
    city: 'Hà Nội',
  ),
  MapPresetLocation(
    shortLabel: 'ĐHQG Hà Nội (Cầu Giấy)',
    title: 'Đại học Quốc gia Hà Nội — Khu vực Xuân Thủy',
    address: '144 Xuân Thủy, Phường Dịch Vọng Hậu, Quận Cầu Giấy, Hà Nội',
    latitude: 21.0368,
    longitude: 105.7821,
    city: 'Hà Nội',
  ),
];

/// Resolves an initial preset or approximate coordinates from a free-text address.
MapPresetLocation resolveInitialMapLocation(String? existingAddress) {
  if (existingAddress != null && existingAddress.trim().isNotEmpty) {
    final normalized = existingAddress.toLowerCase();
    for (final preset in kVietnamStudentMapPresets) {
      if (normalized.contains(preset.shortLabel.toLowerCase()) ||
          normalized.contains(preset.title.toLowerCase())) {
        return preset;
      }
    }
    if (normalized.contains('khu b') || normalized.contains('dĩ an')) {
      return kVietnamStudentMapPresets[0];
    }
    if (normalized.contains('khu a') || normalized.contains('linh trung')) {
      return kVietnamStudentMapPresets[1];
    }
    if (normalized.contains('uit') || normalized.contains('công nghệ thông tin')) {
      return kVietnamStudentMapPresets[2];
    }
    if (normalized.contains('quận 10') || normalized.contains('bách khoa')) {
      return kVietnamStudentMapPresets[3];
    }
    if (normalized.contains('cầu giấy') || normalized.contains('xuân thủy')) {
      return kVietnamStudentMapPresets[10];
    }
    if (normalized.contains('hà nội') || normalized.contains('hai bà trưng')) {
      return kVietnamStudentMapPresets[9];
    }
  }
  return kVietnamStudentMapPresets.first;
}

/// Interactive modal bottom sheet allowing the user to pan/zoom an OpenStreetMap
/// view, tap to drop a pin, search addresses, or pick a campus hotspot.
class LocationMapPickerSheet extends StatefulWidget {
  const LocationMapPickerSheet({
    super.key,
    this.initialAddress,
    this.isMeetup = false,
    this.readOnly = false,
  });

  final String? initialAddress;
  final bool isMeetup;
  final bool readOnly;

  /// Opens the interactive map picker and returns the chosen [PickedLocationResult].
  static Future<PickedLocationResult?> show(
    BuildContext context, {
    String? initialAddress,
    bool isMeetup = false,
  }) {
    return showModalBottomSheet<PickedLocationResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationMapPickerSheet(
        initialAddress: initialAddress,
        isMeetup: isMeetup,
      ),
    );
  }

  /// Opens the map in read-only preview mode for an existing order/listing address.
  static Future<void> showPreview(
    BuildContext context, {
    required String address,
    bool isMeetup = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationMapPickerSheet(
        initialAddress: address,
        isMeetup: isMeetup,
        readOnly: true,
      ),
    );
  }

  @override
  State<LocationMapPickerSheet> createState() => _LocationMapPickerSheetState();
}

class _LocationMapPickerSheetState extends State<LocationMapPickerSheet> {
  late double _latitude;
  late double _longitude;
  int _zoom = 16;
  late String _selectedTitle;
  late String _selectedAddress;
  bool _isGeocoding = false;
  List<MapPresetLocation> _searchResults = const <MapPresetLocation>[];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _detailNoteController = TextEditingController();
  final Dio _nominatimDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: const <String, dynamic>{
        'Accept': 'application/json',
      },
    ),
  );

  @override
  void initState() {
    super.initState();
    final initialPreset = resolveInitialMapLocation(widget.initialAddress);
    _latitude = initialPreset.latitude;
    _longitude = initialPreset.longitude;
    if (widget.initialAddress != null &&
        widget.initialAddress!.trim().isNotEmpty) {
      _selectedTitle = initialPreset.title;
      _selectedAddress = widget.initialAddress!.trim();
    } else {
      _selectedTitle = initialPreset.title;
      _selectedAddress = initialPreset.address;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _detailNoteController.dispose();
    _nominatimDio.close();
    super.dispose();
  }

  void _selectPreset(MapPresetLocation preset) {
    setState(() {
      _latitude = preset.latitude;
      _longitude = preset.longitude;
      _selectedTitle = preset.title;
      _selectedAddress = preset.address;
      _searchResults = const <MapPresetLocation>[];
    });
  }

  Future<void> _handleSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _searchResults = const <MapPresetLocation>[]);
      return;
    }

    final lower = trimmed.toLowerCase();
    final localMatches = kVietnamStudentMapPresets.where((item) {
      return item.shortLabel.toLowerCase().contains(lower) ||
          item.title.toLowerCase().contains(lower) ||
          item.address.toLowerCase().contains(lower) ||
          item.city.toLowerCase().contains(lower);
    }).toList();

    setState(() {
      _isGeocoding = true;
      _searchResults = localMatches;
    });

    try {
      final response = await _nominatimDio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: <String, dynamic>{
          'format': 'json',
          'q': '$trimmed, Việt Nam',
          'countrycodes': 'vn',
          'limit': 5,
          'accept-language': 'vi',
        },
      );
      final data = response.data;
      if (data != null && data.isNotEmpty && mounted) {
        final remoteItems = <MapPresetLocation>[];
        for (final raw in data) {
          if (raw is Map<String, dynamic>) {
            final lat = double.tryParse('${raw['lat'] ?? ''}');
            final lon = double.tryParse('${raw['lon'] ?? ''}');
            final displayName = '${raw['display_name'] ?? ''}'.trim();
            if (lat != null && lon != null && displayName.isNotEmpty) {
              final firstSegment = displayName.split(',').first.trim();
              remoteItems.add(
                MapPresetLocation(
                  shortLabel: firstSegment,
                  title: firstSegment,
                  address: displayName,
                  latitude: lat,
                  longitude: lon,
                  city: 'Việt Nam',
                ),
              );
            }
          }
        }
        if (remoteItems.isNotEmpty) {
          setState(() {
            _searchResults = <MapPresetLocation>[
              ...localMatches,
              ...remoteItems,
            ];
          });
        }
      }
    } catch (_) {
      // Fallback gracefully to local campus & city matches if offline
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  Future<void> _reverseGeocodeCurrentPin() async {
    final nearest = _findNearestPreset(_latitude, _longitude);
    setState(() {
      _isGeocoding = true;
      _selectedTitle =
          'Vị trí ghim gần ${nearest.shortLabel} (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})';
      _selectedAddress =
          'Khu vực lân cận ${nearest.address}';
    });

    try {
      final response = await _nominatimDio.get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: <String, dynamic>{
          'format': 'json',
          'lat': _latitude,
          'lon': _longitude,
          'zoom': 18,
          'accept-language': 'vi',
        },
      );
      final data = response.data;
      if (data != null && mounted) {
        final displayName = '${data['display_name'] ?? ''}'.trim();
        if (displayName.isNotEmpty) {
          final segments = displayName.split(',');
          setState(() {
            _selectedTitle = segments.first.trim();
            _selectedAddress = displayName;
          });
        }
      }
    } catch (_) {
      // Keep nearest preset fallback
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  MapPresetLocation _findNearestPreset(double lat, double lng) {
    MapPresetLocation best = kVietnamStudentMapPresets.first;
    double bestDist = double.infinity;
    for (final preset in kVietnamStudentMapPresets) {
      final dLat = preset.latitude - lat;
      final dLng = preset.longitude - lng;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < bestDist) {
        bestDist = dist;
        best = preset;
      }
    }
    return best;
  }

  void _onMapPanDelta(Offset delta, Size viewSize) {
    if (widget.readOnly) return;
    // Web Mercator degrees per pixel at current zoom
    final scale = 256.0 * math.pow(2.0, _zoom);
    final dLng = -(delta.dx / scale) * 360.0;
    final cosLat = math.cos(_latitude * math.pi / 180.0).clamp(0.2, 1.0);
    final dLat = (delta.dy / scale) * 360.0 * cosLat;

    setState(() {
      _latitude = (_latitude + dLat).clamp(8.0, 23.5);
      _longitude = (_longitude + dLng).clamp(102.0, 110.0);
    });
  }

  void _onMapTapOffset(Offset localPosition, Size viewSize) {
    if (widget.readOnly) return;
    final dxFromCenter = localPosition.dx - viewSize.width / 2;
    final dyFromCenter = localPosition.dy - viewSize.height / 2;

    final scale = 256.0 * math.pow(2.0, _zoom);
    final dLng = (dxFromCenter / scale) * 360.0;
    final cosLat = math.cos(_latitude * math.pi / 180.0).clamp(0.2, 1.0);
    final dLat = -(dyFromCenter / scale) * 360.0 * cosLat;

    setState(() {
      _latitude = (_latitude + dLat).clamp(8.0, 23.5);
      _longitude = (_longitude + dLng).clamp(102.0, 110.0);
    });
    _reverseGeocodeCurrentPin();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      height: screenHeight * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          // Top Grab Handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
            child: Column(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTintBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.isMeetup
                            ? Icons.handshake_outlined
                            : Icons.map_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.readOnly
                                ? 'Bản đồ vị trí giao nhận'
                                : (widget.isMeetup
                                    ? 'Chọn địa điểm hẹn gặp trên bản đồ'
                                    : 'Chọn địa điểm giao hàng trên bản đồ'),
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            widget.readOnly
                                ? 'Tọa độ: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}'
                                : 'Kéo bản đồ hoặc chạm vào điểm bất kỳ để ghim vị trí',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar & Campus Quick Chips (only in interactive picker mode)
          if (!widget.readOnly) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _handleSearch,
                onChanged: (value) {
                  if (value.trim().length >= 2) {
                    final lower = value.trim().toLowerCase();
                    setState(() {
                      _searchResults = kVietnamStudentMapPresets.where((item) {
                        return item.shortLabel.toLowerCase().contains(lower) ||
                            item.title.toLowerCase().contains(lower) ||
                            item.address.toLowerCase().contains(lower);
                      }).toList();
                    });
                  } else if (value.trim().isEmpty) {
                    setState(() => _searchResults = const <MapPresetLocation>[]);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Tìm đường, tòa nhà, KTX, trường đại học...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(
                              () => _searchResults = const <MapPresetLocation>[],
                            );
                          },
                        ),
                      TextButton(
                        onPressed: () => _handleSearch(_searchController.text),
                        child: const Text('Tìm'),
                      ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: kVietnamStudentMapPresets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final preset = kVietnamStudentMapPresets[index];
                  final isSelected =
                      (_latitude - preset.latitude).abs() < 0.0008 &&
                          (_longitude - preset.longitude).abs() < 0.0008;
                  return ActionChip(
                    avatar: Icon(
                      Icons.place_rounded,
                      size: 15,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                    backgroundColor:
                        isSelected ? AppColors.primary : AppColors.background,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                    label: Text(
                      preset.shortLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    onPressed: () => _selectPreset(preset),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Interactive Map Area + Overlay Search Results
          Expanded(
            child: Stack(
              children: <Widget>[
                // OpenStreetMap Tile + Vector Map Canvas
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return GestureDetector(
                          onPanUpdate: (details) =>
                              _onMapPanDelta(details.delta, size),
                          onPanEnd: (_) {
                            if (!widget.readOnly) {
                              _reverseGeocodeCurrentPin();
                            }
                          },
                          onTapUp: (details) =>
                              _onMapTapOffset(details.localPosition, size),
                          child: _InteractiveOsmMapViewport(
                            latitude: _latitude,
                            longitude: _longitude,
                            zoom: _zoom,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Center Location Pin
                Center(
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${_latitude.toStringAsFixed(4)}°N, ${_longitude.toStringAsFixed(4)}°E',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(
                          Icons.location_on_rounded,
                          size: 46,
                          color: Color(0xFFDC2626),
                        ),
                        Container(
                          width: 12,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),

                // Map Zoom Controls (+ / - / Reset)
                Positioned(
                  right: 14,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _MapControlButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Phóng to bản đồ',
                        onTap: () {
                          setState(() => _zoom = (_zoom + 1).clamp(11, 18));
                        },
                      ),
                      const SizedBox(height: 6),
                      _MapControlButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Thu nhỏ bản đồ',
                        onTap: () {
                          setState(() => _zoom = (_zoom - 1).clamp(11, 18));
                        },
                      ),
                      const SizedBox(height: 6),
                      _MapControlButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Về khu vực Làng ĐH Thủ Đức',
                        onTap: () => _selectPreset(kVietnamStudentMapPresets[0]),
                      ),
                    ],
                  ),
                ),

                // OpenStreetMap attribution badge
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Dropdown search results overlay
                if (_searchResults.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _searchResults[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primary,
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              subtitle: Text(
                                item.address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () => _selectPreset(item),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Selected Address Card & Confirm Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTintBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _isGeocoding
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.pin_drop_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _selectedTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!widget.readOnly) ...<Widget>[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _detailNoteController,
                      decoration: InputDecoration(
                        labelText: widget.isMeetup
                            ? 'Ghi chú điểm hẹn cụ thể (Cổng, Quán cafe, Tòa nhà...)'
                            : 'Số nhà, Tòa nhà / Phòng KTX, Ngõ/Hẻm (tùy chọn)',
                        hintText: widget.isMeetup
                            ? 'VD: Trước sảnh Tòa B4 / Quán Highlands cổng chính'
                            : 'VD: Phòng 402 Tòa B4 / Gọi khi tới cổng bảo vệ',
                        prefixIcon: const Icon(
                          Icons.edit_location_alt_outlined,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(
                            PickedLocationResult(
                              title: _selectedTitle,
                              address: _selectedAddress,
                              latitude: _latitude,
                              longitude: _longitude,
                              detailNote: _detailNoteController.text,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          widget.isMeetup
                              ? 'Xác nhận điểm hẹn gặp này'
                              : 'Xác nhận địa chỉ giao hàng này',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders OpenStreetMap Slippy Map tiles (`tile.openstreetmap.org`) centered on
/// `(latitude, longitude)` at `zoom`, backed by a stylized vector street grid.
class _InteractiveOsmMapViewport extends StatelessWidget {
  const _InteractiveOsmMapViewport({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final int zoom;

  @override
  Widget build(BuildContext context) {
    final n = math.pow(2.0, zoom);
    final exactTileX = ((longitude + 180.0) / 360.0) * n;
    final latRad = latitude * math.pi / 180.0;
    final exactTileY =
        (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
            2.0 *
            n;

    final centerTileX = exactTileX.floor();
    final centerTileY = exactTileY.floor();
    final fracX = exactTileX - centerTileX;
    final fracY = exactTileY - centerTileY;

    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final maxTileIndex = n.toInt() - 1;

        final tiles = <Widget>[];
        for (int dy = -2; dy <= 2; dy++) {
          for (int dx = -2; dx <= 2; dx++) {
            final tx = (centerTileX + dx).clamp(0, maxTileIndex);
            final ty = (centerTileY + dy).clamp(0, maxTileIndex);
            final left = centerX + (dx - fracX) * 256.0;
            final top = centerY + (dy - fracY) * 256.0;

            tiles.add(
              Positioned(
                left: left,
                top: top,
                width: 256,
                height: 256,
                child: Image.network(
                  'https://tile.openstreetmap.org/$zoom/$tx/$ty.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            );
          }
        }

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _FallbackMapCanvasPainter(
                  latitude: latitude,
                  longitude: longitude,
                  zoom: zoom,
                ),
              ),
            ),
            ...tiles,
          ],
        );
      },
    );
  }
}

class _FallbackMapCanvasPainter extends CustomPainter {
  const _FallbackMapCanvasPainter({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final int zoom;

  @override
  void paint(Canvas canvas, Size size) {
    // Base map land color
    final bgPaint = Paint()..color = const Color(0xFFEEF2F6);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Park / campus green zones
    final parkPaint = Paint()..color = const Color(0xFFDCECE2);
    final shiftX = ((longitude * 1000) % 120);
    final shiftY = ((latitude * 1000) % 120);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12 - shiftX * 0.3, size.height * 0.15 - shiftY * 0.2, 130, 90),
        const Radius.circular(18),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62 - shiftX * 0.2, size.height * 0.58 - shiftY * 0.3, 150, 100),
        const Radius.circular(22),
      ),
      parkPaint,
    );

    // Water / canal feature
    final waterPaint = Paint()
      ..color = const Color(0xFFBFDBFE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final waterPath = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.62,
        size.width,
        size.height * 0.85,
      );
    canvas.drawPath(waterPath, waterPaint);

    // Minor street grid
    final gridPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0;
    const step = 48.0;
    for (double x = (shiftX % step); x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = (shiftY % step); y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Major arterial roads
    final highwayPaint = Paint()
      ..color = const Color(0xFFFDE68A)
      ..strokeWidth = 8.0;
    canvas.drawLine(
      Offset(0, size.height * 0.42),
      Offset(size.width, size.height * 0.52),
      highwayPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.48, 0),
      Offset(size.width * 0.54, size.height),
      highwayPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FallbackMapCanvasPainter oldDelegate) {
    return oldDelegate.latitude != latitude ||
        oldDelegate.longitude != longitude ||
        oldDelegate.zoom != zoom;
  }
}

/// Compact map preview banner card displayed underneath an address field
/// or inside OrderDetailScreen so users can open/change the location on map.
class LocationMapPreviewBanner extends StatelessWidget {
  const LocationMapPreviewBanner({
    super.key,
    required this.address,
    required this.onTap,
    this.isMeetup = false,
    this.actionLabel = 'Mở bản đồ chọn vị trí',
  });

  final String address;
  final VoidCallback onTap;
  final bool isMeetup;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final preset = resolveInitialMapLocation(address);
    final hasAddress = address.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryTintBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.map_rounded,
              color: AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              actionLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                hasAddress
                    ? '• $address'
                    : '• (${preset.shortLabel})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
