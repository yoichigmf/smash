/*
 * Copyright (c) 2019. Antonello Andrea (www.hydrologis.com). All rights reserved.
 * Use of this source code is governed by a GPL3 license that can be
 * found in the LICENSE file.
 */
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:smash/eu/hydrologis/flutterlibs/eventhandlers.dart';
import 'models.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'project_tables.dart';
import 'package:latlong/latlong.dart';
import 'package:smash/eu/hydrologis/dartlibs/dartlibs.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/colors.dart';
import 'package:smash/eu/hydrologis/flutterlibs/database.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/ui.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/validators.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/preferences.dart';
import 'package:smash/eu/hydrologis/flutterlibs/util/icons.dart';

/// Log object dedicated to the list of logs widget.
class Log4ListWidget {
  int id;
  String name;
  double width;
  int startTime = 0;
  int endTime = 0;
  double lengthm = 0.0;
  String color;
  int isVisible;
}

/// [QueryObjectBuilder] to allow easy extraction from the db.
class Log4ListWidgetBuilder extends QueryObjectBuilder<Log4ListWidget> {
  @override
  Log4ListWidget fromMap(Map<String, dynamic> map) {
    Log4ListWidget l = new Log4ListWidget()
      ..id = map[LOGS_COLUMN_ID]
      ..name = map[LOGS_COLUMN_TEXT]
      ..startTime = map[LOGS_COLUMN_STARTTS]
      ..endTime = map[LOGS_COLUMN_ENDTS]
      ..lengthm = map[LOGS_COLUMN_LENGTHM]
      ..color = map[LOGSPROP_COLUMN_COLOR]
      ..width = map[LOGSPROP_COLUMN_WIDTH]
      ..isVisible = map[LOGSPROP_COLUMN_VISIBLE];
    return l;
  }

  @override
  String insertSql() {
    // TODO
    return null;
  }

  @override
  String querySql() {
    String sql = '''
        SELECT l.$LOGS_COLUMN_ID, l.$LOGS_COLUMN_TEXT, l.$LOGS_COLUMN_STARTTS, l.$LOGS_COLUMN_ENDTS, 
               l.$LOGS_COLUMN_LENGTHM, p.$LOGSPROP_COLUMN_COLOR, p.$LOGSPROP_COLUMN_WIDTH, p.$LOGSPROP_COLUMN_VISIBLE
        FROM $TABLE_GPSLOGS l, $TABLE_GPSLOG_PROPERTIES p 
        WHERE l.$LOGS_COLUMN_ID=p.$LOGSPROP_COLUMN_LOGID
        ORDER BY l.$LOGS_COLUMN_ID
    ''';
    return sql;
  }

  @override
  Map<String, dynamic> toMap(Log4ListWidget item) {
    // TODO
    return null;
  }
}

/// The log list widget.
class LogListWidget extends StatefulWidget {
  final MainEventHandler _eventHandler;

  LogListWidget(this._eventHandler);

  @override
  State<StatefulWidget> createState() {
    return LogListWidgetState();
  }
}

/// The log list widget state.
class LogListWidgetState extends State<LogListWidget> {
  List<Log4ListWidget> _logsList = [];

  Future<bool> loadLogs() async {
    var db = await GPProject().getDatabase();
    var itemsList = await db.getQueryObjectsList(Log4ListWidgetBuilder());
    if (itemsList != null) {
      _logsList = itemsList;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("GPS Logs list"),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.check),
              tooltip: "Select all",
              onPressed: () async {
                var db = await GPProject().getDatabase();
                db.updateGpsLogVisibility(true);
                setState(() {});
              },
            ),
            IconButton(
              tooltip: "Unselect all",
              icon: Icon(Icons.check_box_outline_blank),
              onPressed: () async {
                var db = await GPProject().getDatabase();
                db.updateGpsLogVisibility(false);
                setState(() {});
              },
            ),
            IconButton(
              tooltip: "Invert selection",
              icon: Icon(Icons.check_box),
              onPressed: () async {
                var db = await GPProject().getDatabase();
                db.invertGpsLogsVisibility();
                setState(() {});
              },
            ),
          ],
        ),
        body: FutureBuilder<void>(
          future: loadLogs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // If the Future is complete, display the preview.
              return ListView.builder(
                  itemCount: _logsList.length,
                  itemBuilder: (context, index) {
                    Log4ListWidget logItem = _logsList[index];
                    return Dismissible(
                      confirmDismiss: _confirmLogDismiss,
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        GPProject().getDatabase().then((db) async {
                          await db.deleteGpslog(logItem.id);
                          widget._eventHandler.reloadProjectFunction();
                        });
                      },
                      key: Key("${logItem.id}"),
                      background: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        color: Colors.red,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0),
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.timeline,
                              color: ColorExt(logItem.color),
                              size: SmashUI.MEDIUM_ICON_SIZE,
                            ),
                            Checkbox(
                                value: logItem.isVisible == 1 ? true : false,
                                onChanged: (isVisible) async {
                                  logItem.isVisible = isVisible ? 1 : 0;
                                  var db = await GPProject().getDatabase();
                                  await db.updateGpsLogVisibility(isVisible, logItem.id);
                                  widget._eventHandler.reloadProjectFunction();
                                  setState(() {});
                                }),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_right),
                        title: Text('${logItem.name}'),
                        subtitle: Text('${_getTime(logItem)} ${_getLength(logItem)}'),
                        onTap: () => _navigateToLogProperties(context, logItem),
                        onLongPress: () async {
                          var db = await GPProject().getDatabase();
                          LatLng position = await db.getLogStartPosition(logItem.id);
                          widget._eventHandler.moveToFunction(position);
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  });
            } else {
              // Otherwise, display a loading indicator.
              return Center(child: CircularProgressIndicator());
            }
          },
        ));
  }

  _getTime(Log4ListWidget item) {
    var minutes = (item.endTime - item.startTime) / 1000 / 60;
    if (minutes > 60) {
      var hours = minutes / 60;
      var h = (hours * 10).toInt() / 10.0;
      return "Hours: $h";
    } else {
      var m = minutes.toInt();
      return "Minutes: $m";
    }
  }

  _getLength(Log4ListWidget item) {
    var length = item.lengthm.toInt();
    if (length > 1000) {
      var lengthKm = length / 1000;
      var l = (lengthKm * 10).toInt() / 10.0;
      return "Km: $l";
    } else {
      return "Meters: $length";
    }
  }

  Future<bool> _confirmLogDismiss(DismissDirection direction) async {
    return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm'),
            content: Text('Are you sure you want to delete the log?'),
            actions: <Widget>[
              FlatButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Text('Yes')),
              FlatButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: Text('No')),
            ],
          );
        });
  }

  _navigateToLogProperties(BuildContext context, Log4ListWidget logItem) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => LogPropertiesWidget(widget._eventHandler, logItem)));
  }
}

/// The log properties page.
class LogPropertiesWidget extends StatefulWidget {
  var _logItem;
  final MainEventHandler _eventHandler;

  LogPropertiesWidget(this._eventHandler, this._logItem);

  @override
  State<StatefulWidget> createState() {
    return LogPropertiesWidgetState(_logItem);
  }
}

class LogPropertiesWidgetState extends State<LogPropertiesWidget> {
  Log4ListWidget _logItem;
  double _widthSliderValue;
  ColorExt _logColor;
  double maxWidth = 20.0;
  bool _somethingChanged = false;

  LogPropertiesWidgetState(this._logItem);

  @override
  void initState() {
    _widthSliderValue = _logItem.width;
    if (_widthSliderValue > maxWidth) {
      _widthSliderValue = maxWidth;
    }
    _logColor = ColorExt(_logItem.color);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (_somethingChanged) {
            // save color and width
            _logItem.width = _widthSliderValue;
            _logItem.color = ColorExt.asHex(_logColor);

            var db = await GPProject().getDatabase();
            await db.updateGpsLogStyle(_logItem.id, _logItem.color, _logItem.width);
            widget._eventHandler.reloadProjectFunction();
          }
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text("GPS Log Properties"),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: SmashUI.defaultPadding(),
                  child: Card(
                    elevation: SmashUI.DEFAULT_ELEVATION,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Padding(
                      padding: SmashUI.defaultPadding(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Table(
                            columnWidths: {
                              0: FlexColumnWidth(0.2),
                              1: FlexColumnWidth(0.8),
                            },
                            children: _getInfoTableCells(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ));
  }

  _getInfoTableCells(BuildContext context) {
    return [
      TableRow(
        children: [
          TableUtilities.cellForString("Name"),
          cellForEditableName(context, _logItem),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Start"),
          TableUtilities.cellForString(TimeUtilities.ISO8601_TS_FORMATTER.format(new DateTime.fromMillisecondsSinceEpoch(_logItem.startTime))),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("End"),
          TableUtilities.cellForString(TimeUtilities.ISO8601_TS_FORMATTER.format(new DateTime.fromMillisecondsSinceEpoch(_logItem.endTime))),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Color"),
          MaterialColorPicker(
              allowShades: false,
              onColorChange: (Color color) {
                _logColor = ColorExt.fromColor(color);
                _somethingChanged = true;
              },
              onMainColorChange: (mColor) {
                _logColor = ColorExt.fromColor(mColor);
                _somethingChanged = true;
              },
              selectedColor: Color(_logColor.value)),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Width"),
          Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Flexible(
                  flex: 1,
                  child: Slider(
                    activeColor: SmashColors.mainSelection,
                    min: 1.0,
                    max: 20.0,
                    divisions: 10,
                    onChanged: (newRating) {
                      _somethingChanged = true;
                      setState(() => _widthSliderValue = newRating);
                    },
                    value: _widthSliderValue,
                  )),
              Container(
                width: 50.0,
                alignment: Alignment.center,
                child: SmashUI.normalText(
                  '${_widthSliderValue.toInt()}',
                ),
              ),
            ],
          )
        ],
      ),
    ];
  }

  TableCell cellForEditableName(BuildContext context, Log4ListWidget item) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: GestureDetector(
          child: SmashUI.normalText(item.name, color: SmashColors.mainDecorationsDark),
          onDoubleTap: () {
            _changeLogName(context, item);
          },
        ),
      ),
    );
  }

  _changeLogName(BuildContext context, Log4ListWidget logItem) async {
    String result = await showInputDialog(
      context,
      "Change log name",
      "Please enter a new name for the log",
      defaultText: logItem.name,
      validationFunction: noEmptyValidator,
    );
    if (result != null) {
      var db = await GPProject().getDatabase();
      await db.updateGpsLogName(logItem.id, result);
      setState(() {
        logItem.name = result;
      });
    }
  }
}

class NotePropertiesWidgetState extends State<NotePropertiesWidget> {
  Note _note;
  double _sizeSliderValue = 10;
  double _maxSize = 100.0;
  ColorExt _noteColor;
  String _marker = 'marker';
  bool _somethingChanged = false;
  var chosenIconsList = [];

  NotePropertiesWidgetState(this._note);

  @override
  void initState() {
    _sizeSliderValue = _note?.noteExt?.size;
    if (_sizeSliderValue > _maxSize) {
      _sizeSliderValue = _maxSize;
    }
    _noteColor = ColorExt(_note.noteExt.color);
    _marker = _note.noteExt.marker;

    chosenIconsList.addAll(GpPreferences().getStringListSync(KEY_ICONS_LIST, DEFAULT_NOTES_ICONDATA));
    if (!chosenIconsList.contains(_marker)) {
      chosenIconsList.insert(0, _marker);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<GridTile> _iconButtons = [];
    chosenIconsList.forEach((iconName) {
      var color = SmashColors.mainDecorations;
      if (iconName == _marker) color = SmashColors.mainSelection;
      var but = GridTile(
          child: Card(
        margin: EdgeInsets.all(10),
        elevation: 5,
        color: SmashColors.mainBackground,
        child: IconButton(
          icon: Icon(getIcon(iconName)),
          color: color,
          onPressed: () {
            _marker = iconName;
            _somethingChanged = true;
            setState(() {});
          },
        ),
      ));
      _iconButtons.add(but);
    });

    return WillPopScope(
        onWillPop: () async {
          if (_somethingChanged) {
            _note.noteExt.color = ColorExt.asHex(_noteColor);
            _note.noteExt.marker = _marker;
            _note.noteExt.size = _sizeSliderValue;

            var db = await GPProject().getDatabase();
            await db.updateNote(_note);
            widget._eventHandler.reloadProjectFunction();
          }
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text("Note Properties"),
          ),
          body: Center(
            child: ListView(
              children: <Widget>[
                Padding(
                  padding: SmashUI.defaultPadding(),
                  child: Card(
                    elevation: SmashUI.DEFAULT_ELEVATION,
                    shape: SmashUI.defaultShapeBorder(),
                    child: Padding(
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
                            children: _getInfoTableCells(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: SmashUI.defaultPadding(),
                  child: Card(
                    elevation: SmashUI.DEFAULT_ELEVATION,
                    shape: SmashUI.defaultShapeBorder(),
                    child: Padding(
                      padding: SmashUI.defaultPadding(),
                      child: MaterialColorPicker(
                          allowShades: false,
                          circleSize: 45,
                          onColorChange: (Color color) {
                            _noteColor = ColorExt.fromColor(color);
                            _somethingChanged = true;
                          },
                          onMainColorChange: (mColor) {
                            _noteColor = ColorExt.fromColor(mColor);
                            _somethingChanged = true;
                          },
                          selectedColor: Color(_noteColor.value)),
                    ),
                  ),
                ),
                Padding(
                  padding: SmashUI.defaultPadding(),
                  child: Card(
                    elevation: SmashUI.DEFAULT_ELEVATION,
                    shape: SmashUI.defaultShapeBorder(),
                    child: Padding(
                      padding: SmashUI.defaultPadding(),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          SmashUI.normalText("Size"),
                          Flexible(
                              flex: 1,
                              child: Slider(
                                activeColor: SmashColors.mainSelection,
                                min: 1.0,
                                max: _maxSize,
                                divisions: 20,
                                onChanged: (newRating) {
                                  _somethingChanged = true;
                                  setState(() => _sizeSliderValue = newRating);
                                },
                                value: _sizeSliderValue,
                              )),
                          Container(
                            width: 50.0,
                            alignment: Alignment.center,
                            child: SmashUI.normalText(
                              '${_sizeSliderValue.toInt()}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: SmashUI.defaultPadding(),
                  child: Card(
                    elevation: SmashUI.DEFAULT_ELEVATION,
                    shape: SmashUI.defaultShapeBorder(),
                    child: Padding(
                      padding: SmashUI.defaultPadding(),
                      child: OrientationBuilder(
                        builder: (context, orientation) {
                          return GridView.count(
                            shrinkWrap: true,
                            physics: BouncingScrollPhysics(),
                            crossAxisCount: orientation == Orientation.portrait ? 5 : 10,
                            childAspectRatio: 1,
                            padding: EdgeInsets.all(5),
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                            children: _iconButtons,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  _getInfoTableCells(BuildContext context) {
    return [
      TableRow(
        children: [
          TableUtilities.cellForString("Note"),
          _cellForNoteText(context, _note),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Timestamp"),
          TableUtilities.cellForString(TimeUtilities.ISO8601_TS_FORMATTER.format(DateTime.fromMillisecondsSinceEpoch(_note.timeStamp))),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Altitude"),
          TableUtilities.cellForString(_note.altim.toInt().toString()),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Longitude"),
          TableUtilities.cellForString(_note.lon.toString()),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Latitude"),
          TableUtilities.cellForString(_note.lat.toString()),
        ],
      ),
    ];
  }

  TableCell _cellForNoteText(BuildContext context, Note item) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: GestureDetector(
          child: SmashUI.normalText(item.text, color: SmashColors.mainDecorationsDark),
          onDoubleTap: () async {
            String result = await showInputDialog(
              context,
              "Change note text",
              "Please enter a new text for the note",
              defaultText: _note.text,
              validationFunction: noEmptyValidator,
            );
            if (result != null) {
              _note.text = result;
              _somethingChanged = true;
              setState(() {});
            }
          },
        ),
      ),
    );
  }
}

/// The notes properties page.
class NotePropertiesWidget extends StatefulWidget {
  var _note;
  MainEventHandler _eventHandler;

  NotePropertiesWidget(this._eventHandler, this._note);

  @override
  State<StatefulWidget> createState() {
    return NotePropertiesWidgetState(_note);
  }
}

/// The notes list widget.
class NotesListWidget extends StatefulWidget {
  final MainEventHandler _eventHandler;
  final bool _doSimpleNotes;

  NotesListWidget(this._eventHandler, this._doSimpleNotes);

  @override
  State<StatefulWidget> createState() {
    return NotesListWidgetState();
  }
}

/// The log list widget state.
class NotesListWidgetState extends State<NotesListWidget> {
  List<dynamic> _notesList = [];

  Future<bool> loadNotes() async {
    _notesList.clear();
    var db = await GPProject().getDatabase();
    dynamic itemsList = await db.getNotes(doSimple: widget._doSimpleNotes);
    if (itemsList != null) {
      _notesList.addAll(itemsList);
    }
    if (widget._doSimpleNotes) {
      itemsList = await db.getImages();
      if (itemsList != null) {
        _notesList.addAll(itemsList);
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget._doSimpleNotes ? "Simple Notes List" : "Form Notes List"),
        ),
        body: FutureBuilder<void>(
          future: loadNotes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // If the Future is complete, display the preview.
              return ListView.builder(
                  itemCount: _notesList.length,
                  itemBuilder: (context, index) {
                    dynamic dynNote = _notesList[index];
                    int id;
                    var markerName;
                    var markerColor;
                    String text;
                    bool hasProperties = true;
                    int ts;
                    double lat;
                    double lon;
                    if (dynNote is Note) {
                      id = dynNote.id;
                      markerName = dynNote.noteExt.marker;
                      markerColor = dynNote.noteExt.color;
                      text = dynNote.text;
                      ts = dynNote.timeStamp;
                      lon = dynNote.lon;
                      lat = dynNote.lat;
                      if (dynNote.form != null) {
                        hasProperties = false;
                      }
                    } else {
                      hasProperties = false;
                      id = dynNote.id;
                      markerName = 'camera';
                      markerColor = ColorExt.asHex(SmashColors.mainDecorationsDark);
                      text = dynNote.text;
                      ts = dynNote.timeStamp;
                      lon = dynNote.lon;
                      lat = dynNote.lat;
                    }

                    return Dismissible(
                      confirmDismiss: _confirmNoteDismiss,
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        GPProject().getDatabase().then((db) async {
                          await db.deleteNote(id);
                          widget._eventHandler.reloadProjectFunction();
                        });
                      },
                      key: Key("${id}"),
                      background: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        color: Colors.red,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0),
                          child: Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              getIcon(markerName) ?? MdiIcons.mapMarker,
                              color: ColorExt(markerColor),
                              size: SmashUI.MEDIUM_ICON_SIZE,
                            ),
//                            Checkbox(
//                                value: note.isVisible == 1 ? true : false,
//                                onChanged: (isVisible) async {
//                                  note.isVisible = isVisible ? 1 : 0;
//                                  var db = await gpProjectModel.getDatabase();
//                                  await db.updateGpsLogVisibility(
//                                      isVisible, note.id);
//                                  widget._eventHandler.reloadProjectFunction();
//                                  setState(() {});
//                                }),
                          ],
                        ),
                        trailing: hasProperties ? Icon(Icons.arrow_right) : SmashUI.getTransparentIcon(),
                        title: Text('${text}'),
                        subtitle: Text('${TimeUtilities.ISO8601_TS_FORMATTER.format(DateTime.fromMillisecondsSinceEpoch(ts))}'),
                        onTap: () {
                          if (hasProperties) {
                            _navigateToNoteProperties(context, dynNote);
                          }
                        },
                        onLongPress: () {
                          LatLng position = LatLng(lat, lon);
                          widget._eventHandler.moveToFunction(position);
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  });
            } else {
              // Otherwise, display a loading indicator.
              return Center(child: CircularProgressIndicator());
            }
          },
        ));
  }

  Future<bool> _confirmNoteDismiss(DismissDirection direction) async {
    return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm'),
            content: Text('Are you sure you want to delete the note?'),
            actions: <Widget>[
              FlatButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Text('Yes')),
              FlatButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: Text('No')),
            ],
          );
        });
  }

  _navigateToNoteProperties(BuildContext context, Note note) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => NotePropertiesWidget(widget._eventHandler, note)));
  }
}
