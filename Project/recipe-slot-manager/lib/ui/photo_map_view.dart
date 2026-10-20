import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:recipe_slot_manager/design/tokens.dart';
import 'package:recipe_slot_manager/photo/map_clusters.dart';
import 'package:recipe_slot_manager/photo/photo_query.dart';
import 'package:recipe_slot_manager/ui/photo_thumbnail.dart';

/// 찾은 사진 중 위치가 있는 것을 OpenStreetMap 위에 묶은 점으로 보인다. 점을 누르면 그 사진들.
///
/// OSM 타일 정책: 앱을 밝히는 User-Agent, 보이는 저작권 표시, 보는 화면의 타일만 받는다.
class PhotoMapView extends StatefulWidget {
  const PhotoMapView({
    super.key,
    required this.entries,
    required this.thumbnails,
    required this.onOpen,
    this.tiles = true,
  });

  final List<PhotoEntry> entries;
  final PhotoThumbnails thumbnails;
  final void Function(PhotoEntry entry) onOpen;

  /// 지도 타일을 받는다. 시험에서는 끈다.
  final bool tiles;

  @override
  State<PhotoMapView> createState() => _PhotoMapViewState();
}

class _PhotoMapViewState extends State<PhotoMapView> {
  final _controller = MapController();
  double? _zoom;

  List<PhotoEntry> get _located => [
    for (final e in widget.entries)
      if (e.photo.info?.location != null) e,
  ];

  LatLng _latLng(PhotoEntry e) {
    final location = e.photo.info!.location!;
    return LatLng(location.latitude, location.longitude);
  }

  void _openCluster(List<PhotoEntry> items) {
    if (items.length == 1) return widget.onOpen(items.single);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => GridView.count(
        padding: const EdgeInsets.all(AppSpacing.lg),
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        children: [
          for (final entry in items)
            PhotoThumbnail(
              photo: entry.photo,
              thumbnails: widget.thumbnails,
              onTap: () {
                Navigator.pop(context);
                widget.onOpen(entry);
              },
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final located = _located;
    final points = [for (final e in located) _latLng(e)];
    final clusters = clusterPoints(
      located,
      (e) => e.photo.info!.location!,
      _zoom ?? 3,
    );
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: const LatLng(36, 135),
        initialZoom: 3,
        initialCameraFit: points.isEmpty
            ? null
            : CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(48),
                maxZoom: 15,
              ),
        onMapReady: () => setState(() => _zoom = _controller.camera.zoom),
        onPositionChanged: (camera, _) {
          if (camera.zoom.round() != _zoom?.round()) {
            setState(() => _zoom = camera.zoom);
          }
        },
      ),
      children: [
        if (widget.tiles)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dev.supsuphae.recipe_slot_manager',
          ),
        MarkerLayer(
          markers: [
            for (final cluster in clusters)
              Marker(
                point: LatLng(
                  cluster.center.latitude,
                  cluster.center.longitude,
                ),
                width: 44,
                height: 44,
                child: _ClusterDot(
                  key: ValueKey('cluster-${cluster.items.length}'),
                  count: cluster.items.length,
                  onTap: () => _openCluster(cluster.items),
                ),
              ),
          ],
        ),
        if (located.isEmpty)
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  '위치가 있는 사진이 없습니다.\n'
                  'XApp 위치 정보 동기화를 켜고 찍은 사진에 위치가 들어갑니다.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        // OSM 저작권 표시. 좁은 화면에서도 줄을 바꿔 들어가도록 직접 그린다.
        const Align(
          alignment: Alignment.bottomRight,
          child: ColoredBox(
            color: Color(0xCCFFFFFF),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(color: Color(0xFF333333), fontSize: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClusterDot extends StatelessWidget {
  const _ClusterDot({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '사진 $count장',
    child: GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.text, width: 2),
        ),
        child: Center(
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}
