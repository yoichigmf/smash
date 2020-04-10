/*
 * Copyright (c) 2019-2020. Antonello Andrea (www.hydrologis.com). All rights reserved.
 * Use of this source code is governed by a GPL3 license that can be
 * found in the LICENSE file.
 */

import 'dart:convert';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:smash/eu/hydrologis/flutterlibs/filesystem/filemanagement.dart';
import 'package:smash/eu/hydrologis/smash/maps/layers/types/geopackage.dart';
import 'package:smash/eu/hydrologis/smash/maps/layers/types/gpx.dart';
import 'package:smash/eu/hydrologis/smash/maps/layers/types/tiles.dart';
import 'package:smash/eu/hydrologis/smash/maps/layers/types/worldimage.dart';
import 'package:smash/eu/hydrologis/smash/util/logging.dart';

const LAYERSKEY_FILE = 'file';
const LAYERSKEY_URL = 'url';
const LAYERSKEY_TYPE = 'type';
const LAYERSKEY_FORMAT = 'format';
const LAYERSKEY_ISVECTOR = 'isVector';
const LAYERSKEY_LABEL = 'label';
const LAYERSKEY_ISVISIBLE = 'isvisible';
const LAYERSKEY_OPACITY = 'opacity';
const LAYERSKEY_ATTRIBUTION = 'attribution';
const LAYERSKEY_SUBDOMAINS = 'subdomains';
const LAYERSKEY_MINZOOM = 'minzoom';
const LAYERSKEY_MAXZOOM = 'maxzoom';

const LAYERSTYPE_WMS = 'wms';
const LAYERSTYPE_TMS = 'tms';
const LAYERSTYPE_FORMAT_JPG = "image/jpeg";
const LAYERSTYPE_FORMAT_PNG = "image/png";

/// A generic persistable layer source.
abstract class LayerSource {
  /// Get the optional absolute file path, if file based.
  String getAbsolutePath();

  /// Get the optional URL if URL based.
  String getUrl();

  /// Get the name for this layerSource.
  String getName();

  /// Get the optional attribution of the dataset.
  String getAttribution();

  /// Convert the current layer source to an array of layers
  /// with their data loaded and ready to be displayed in map.
  Future<List<LayerOptions>> toLayers(BuildContext context);

  /// Returns the active flag of the layer (usually visible/non visible).
  bool isActive();

  /// Toggle the active flag.
  void setActive(bool active);

  /// Get the bounds for the resource.
  Future<LatLngBounds> getBounds();

  /// Dispose the current layeresource.
  void disposeSource();

  /// Check if the layersource is online.
  bool isOnlineService() {
    return getUrl() != null;
  }

  /// Return true if the layersource supports zooming to bounds.
  bool isZoomable();

  /// Returns true if the layersource can be styled or configured.
  bool hasProperties();

  /// Convert the source to json for persistence.
  String toJson();

  /// Create a layersource from a presistence [json].
  static List<LayerSource> fromJson(String json) {
    try {
      var map = jsonDecode(json);

      String file = map[LAYERSKEY_FILE];
      if (file != null && FileManager.isGpx(file)) {
        GpxSource gpx = GpxSource.fromMap(map);
        return [gpx];
      } else if (file != null && FileManager.isWorldImage(file)) {
        WorldImageSource world = WorldImageSource.fromMap(map);
        return [world];
      } else if (file != null && FileManager.isGeopackage(file)) {
        bool isVector = map[LAYERSKEY_ISVECTOR];
        if (isVector == null || !isVector) {
          TileSource ts = TileSource.fromMap(map);
          return [ts];
        } else {
          GeopackageSource gpkg = GeopackageSource.fromMap(map);
          return [gpkg];
        }
      } else {
        TileSource ts = TileSource.fromMap(map);
        return [ts];
      }
    } catch (e) {
      GpLogger().e("Error while loading layer: \n$json", e);
      return [];
    }
  }

  bool operator ==(dynamic other) {
    if (other is LayerSource) {
      if (getUrl() != null &&
          (getName() != other.getName() || getUrl() != other.getUrl())) {
        return false;
      } else if (getAbsolutePath() != null &&
          (getName() != other.getName() ||
              getAbsolutePath() != other.getAbsolutePath())) {
        return false;
      } else {
        return true;
      }
    } else {
      return false;
    }
  }

  int get hashCode {
    if (getUrl() != null) {
      return getUrl().hashCode;
    } else if (getAbsolutePath() != null) {
      return getAbsolutePath().hashCode;
    }
    return getName().hashCode;
  }
}

/// Interface for vector data based layersources.
abstract class VectorLayerSource extends LayerSource {
  Future<void> load(BuildContext context);
}

/// Interface for raster data based layersources.
abstract class RasterLayerSource extends LayerSource {
  Future<void> load(BuildContext context);
}

/// Interface for raster data based layersources.
abstract class TiledRasterLayerSource extends RasterLayerSource {}

/// List of default online tile layer sources.
final List<TileSource> onlinesTilesSources = [
  TileSource.Open_Street_Map_Standard(),
  TileSource.Wikimedia_Map(),
  TileSource.Opnvkarte_Transport(),
  TileSource.Stamen_Watercolor(),
  TileSource.OpenTopoMap(),
  TileSource.Esri_Satellite(),
];