/*
 * Copyright (c) 2019-2020. Antonello Andrea (www.hydrologis.com). All rights reserved.
 * Use of this source code is governed by a GPL3 license that can be
 * found in the LICENSE file.
 */

import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:dart_hydrologis_db/dart_hydrologis_db.dart';
import 'package:dart_hydrologis_utils/dart_hydrologis_utils.dart';
import 'package:flutter/material.dart' hide TextStyle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_elevation/map_elevation.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:smash/eu/hydrologis/smash/gps/gps.dart';
import 'package:smash/eu/hydrologis/smash/maps/layers/core/layersource.dart';
import 'package:smash/eu/hydrologis/smash/util/elevcolor.dart';
import 'package:smash/generated/l10n.dart';
import 'package:smashlibs/smashlibs.dart';

class GeocachingSource extends VectorLayerSource {
  String? _absolutePath;
  String? _name;

  Map<int, List<dynamic>> type2NameMap = {
    2: ["TRADITIONAL", MdiIcons.archive],
    3: ["MULTI_CACHE", MdiIcons.archivePlus],
    4: ["VIRTUAL", MdiIcons.archiveOutline],
    5: ["LETTERBOX_HYBRID", MdiIcons.mailboxUp],
    6: ["EVENT", MdiIcons.calendarHeart],
    8: ["MYSTERY_UNKNOWN", MdiIcons.mapMarkerQuestion],
    11: ["WEBCAM", MdiIcons.webcam],
    12: ["LOCATIONLESS_CACHE", MdiIcons.marker],
    13: ["CACHE_IN_TRASH_OUT_EVENT", MdiIcons.recycle],
    137: ["EARTHCACHE", MdiIcons.earthBox],
    453: ["MEGA_EVENT", MdiIcons.calendarPlus],
    1304: ["GPS_ADVENTURES_EXHIBIT", MdiIcons.marker],
    1858: ["WHERIGO", MdiIcons.marker],
    3653: ["LOST_AND_FOUND_EVENT_CACHE", MdiIcons.marker],
    3773: ["GEOCACHING_HQ", MdiIcons.officeBuildingMarker],
    3774: ["GEOCACHING_LOST_AND_FOUND_CELEBRATION", MdiIcons.marker],
    4738: ["GEOCACHING_BLOCK_PARTY", MdiIcons.marker],
    7005: ["GIGA_EVENT", MdiIcons.calendarStar],
  };

  bool isVisible = true;
  String _attribution = "Geocaching HQ";
  List<dynamic> _pointsList = [];
  int _srid = SmashPrj.EPSG4326_INT;

  LatLngBounds _bounds = LatLngBounds();

  GeocachingSource.fromMap(Map<String, dynamic> map) {
    String relativePath = map[LAYERSKEY_FILE];
    _absolutePath = Workspace.makeAbsolute(relativePath);
    isVisible = map[LAYERSKEY_ISVISIBLE];
    _srid = map[LAYERSKEY_SRID] ?? _srid;
  }

  GeocachingSource(this._absolutePath);

  Future<void> load(BuildContext context) async {
    if (!isLoaded) {
      var fileName = FileUtilities.nameFromFile(_absolutePath!, false);
      _name ??= fileName;

      var jsonString = FileUtilities.readFile(_absolutePath!);
      var dataMap = jsonDecode(jsonString);
      _pointsList = dataMap['results'];
      isLoaded = true;
    }
  }

  bool hasData() {
    return _pointsList.isNotEmpty;
  }

  String? getAbsolutePath() {
    return _absolutePath;
  }

  String? getUrl() {
    return null;
  }

  String? getName() {
    return _name;
  }

  String getAttribution() {
    return _attribution;
  }

  bool isActive() {
    return isVisible;
  }

  void setActive(bool active) {
    isVisible = active;
  }

  String toJson() {
    var relativePath = Workspace.makeRelative(_absolutePath!);
    var json = '''
    {
        "$LAYERSKEY_FILE":"$relativePath",
        "$LAYERSKEY_SRID": $_srid,
        "$LAYERSKEY_ISVISIBLE": $isVisible,
    }
    ''';
    return json;
  }

  @override
  Future<List<LayerOptions>> toLayers(BuildContext context) async {
    load(context);

    List<LayerOptions> layers = [];

    if (_pointsList.isNotEmpty) {
      List<Marker> geoCaches = [];

      for (var i = 0; i < _pointsList.length; i++) {
        var pointData = _pointsList[i];
        var id = pointData['id'] ?? -1;
        var name = pointData['name'] ?? " - nv - ";
        var code = pointData['code'] ?? " - nv - ";
        var premiumOnly = pointData['premiumOnly'] ?? false;
        var geocacheType = pointData['geocacheType'] ?? 2;
        var postedCoordinates = pointData['postedCoordinates'];
        if (postedCoordinates == null) {
          // print(pointData);
          continue;
        }
        var latitude = postedCoordinates['latitude'];
        var longitude = postedCoordinates['longitude'];
        var difficulty = pointData['difficulty'] ?? -1;
        var placedDate = pointData['placedDate'] ?? " - nv - ";
        var lastFoundDate = pointData['lastFoundDate'] ?? " - nv - ";
        var owner = pointData['owner']?['username'] ?? " - nv - ";

        var color = ColorExt("#007106");
        var labelColor = ColorExt("#ffffff");
        if (premiumOnly) {
          color = ColorExt("#8b0003");
          labelColor = ColorExt("#ffffff");
        }
        List type = type2NameMap[geocacheType] ?? ["UNKNOWN", MdiIcons.archive];
        var iconData = type[1];

        double textExtraHeight = MARKER_ICON_TEXT_EXTRA_HEIGHT;
        var pointsSize = 48.0;
        Marker m = Marker(
            width: pointsSize * MARKER_ICON_TEXT_EXTRA_WIDTH_FACTOR,
            height: pointsSize + textExtraHeight,
            point: LatLng(latitude, longitude),
            builder: (ctx) => GestureDetector(
                  child: MarkerIcon(
                    iconData,
                    color,
                    pointsSize,
                    name!,
                    labelColor,
                    color.withAlpha(100),
                  ),
                  onTap: () {
                    bool sizeSnackBar = ScreenUtilities.isLargeScreen(ctx) &&
                        ScreenUtilities.isLandscape(ctx);
                    var halfWidth = ScreenUtilities.getWidth(ctx);
                    if (sizeSnackBar) {
                      halfWidth /= 2;
                      if (halfWidth < 100) {
                        halfWidth = 100;
                      }
                    }
                    ScaffoldMessenger.of(ctx).clearSnackBars();
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      behavior: SnackBarBehavior.floating,
                      width: halfWidth,
                      backgroundColor: SmashColors.snackBarColor,
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: SmashUI.defaultPadding(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Table(
                                  columnWidths: {
                                    0: FlexColumnWidth(0.4),
                                    1: FlexColumnWidth(0.6),
                                  },
                                  children: [
                                    getTableRow("name", name),
                                    getTableRow("owner", owner),
                                    getTableRow("id", id),
                                    getTableRow("code", code),
                                    getTableRow("type", type[0]),
                                    getTableRow("difficulty", "$difficulty/5"),
                                    getTableRow("placed date",
                                        placedDate.split("T")[0]),
                                    getTableRow("last found date",
                                        lastFoundDate.replaceFirst("T", " ")),
                                    getTableRow("premium", premiumOnly),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                Spacer(flex: 1),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: SmashColors.mainDecorationsDarker,
                                  ),
                                  iconSize: SmashUI.MEDIUM_ICON_SIZE,
                                  onPressed: () {
                                    ScaffoldMessenger.of(ctx)
                                        .hideCurrentSnackBar();
                                  },
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      duration: Duration(seconds: 10),
                    ));
                  },
                ));
        geoCaches.add(m);
      }
      var color = ColorExt("#007106");
      var labelColor = ColorExt("#ffffff");
      var waypointsCluster = MarkerClusterLayerOptions(
        maxClusterRadius: 60,
        size: Size(40, 40),
        fitBoundsOptions: FitBoundsOptions(
          padding: EdgeInsets.all(50),
        ),
        markers: geoCaches,
        polygonOptions: PolygonOptions(
            borderColor: color,
            color: color.withOpacity(0.2),
            borderStrokeWidth: 3),
        builder: (context, markers) {
          return FloatingActionButton(
            child: Text(markers.length.toString()),
            onPressed: null,
            backgroundColor: color,
            foregroundColor: labelColor,
            heroTag: null,
          );
        },
      );
      layers.add(waypointsCluster);
    }
    return layers;
  }

  @override
  Future<LatLngBounds> getBounds() async {
    return _bounds;
  }

  @override
  void disposeSource() {
    _bounds = LatLngBounds();
    _pointsList = [];
    _name = null;
    _absolutePath = null;
    isLoaded = false;
  }

  @override
  bool hasProperties() {
    return true;
  }

  Widget getPropertiesWidget() {
    return Container();
  }

  @override
  bool isZoomable() {
    return true;
  }

  @override
  int getSrid() {
    return _srid;
  }

  String? getUser() => null;

  String? getPassword() => null;

  IconData getIcon() => MdiIcons.archive;

  TableRow getTableRow(String key, dynamic value) {
    return TableRow(
      children: [
        TableUtilities.cellForString(key),
        TableUtilities.cellForString(value.toString()),
      ],
    );
  }
}
