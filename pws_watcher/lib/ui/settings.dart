import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pws_watcher/resources/state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:pws_watcher/model/source.dart';
import 'package:highlighter_coachmark/highlighter_coachmark.dart';

class SettingsPage extends StatefulWidget {
  SettingsPage({Key key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _fabKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _addFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _editFormKey = GlobalKey<FormState>();

  var visibilityUpdateTimer = true;
  var visibilityWindSpeed = true;
  var visibilityPressure = true;
  var visibilityWindDirection = true;
  var visibilityHumidity = true;
  var visibilityTemperature = true;
  var visibilityWindChill = true;
  var visibilityRain = true;
  var visibilityDew = true;
  var visibilitySunrise = true;
  var visibilitySunset = true;
  var visibilityMoonrise = true;
  var visibilityMoonset = true;
  double refreshInterval = 15;
  bool _first = true;

  List<Source> _sources = List();
  final _addNameController = TextEditingController();
  final _addUrlController = TextEditingController();
  final _addIntervalController = TextEditingController();
  final _editNameController = TextEditingController();
  final _editUrlController = TextEditingController();
  final _editIntervalController = TextEditingController();
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  var _themeSelection = [true, false, false, false, false];

  @override
  void initState() {
    super.initState();
    _getSettings();
    _retrieveSources();
  }

  Future<bool> _onWillPop() async {
    //triggered on device's back button click
    if (_sources.length == 0) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text(
            "You should add a source in order to navigate to the home page."),
      ));
      return false;
    }
    Provider.of<ApplicationState>(context).settingsOpen = false;
    setState(() {
      Provider.of<ApplicationState>(context).updateSources = true;
    });
    return true;
  }

  void closeSettings() {
    if (_sources.length == 0) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text(
            "You should add a source in order to navigate to the home page."),
      ));
      return;
    }
    //triggered on AppBar back button click
    Provider.of<ApplicationState>(context).settingsOpen = false;
    Navigator.of(context).pop(false);
    setState(() {
      Provider.of<ApplicationState>(context).updateSources = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_first) {
      _first = false;
      setState(() {
        _themeSelection = [
          Provider.of<ApplicationState>(context).theme == PWSTheme.Day,
          Provider.of<ApplicationState>(context).theme == PWSTheme.Evening,
          Provider.of<ApplicationState>(context).theme == PWSTheme.Night,
          Provider.of<ApplicationState>(context).theme == PWSTheme.Grey,
          Provider.of<ApplicationState>(context).theme == PWSTheme.Blacked,
        ];
      });
    }
    return Theme(
      data: ThemeData(
          primarySwatch: Provider.of<ApplicationState>(context).mainColor),
      child: WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Provider.of<ApplicationState>(context).mainColorDark,
          appBar: AppBar(
            brightness: Brightness.dark,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => closeSettings(),
            ),
            backgroundColor: Provider.of<ApplicationState>(context).mainColor,
            title: Text(
              "Settings",
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor:
                Provider.of<ApplicationState>(context).theme == PWSTheme.Blacked
                    ? Colors.white
                    : Provider.of<ApplicationState>(context).mainColor,
            onPressed: _addSource,
            elevation: 2,
            icon: Icon(
              Icons.add,
              color: Provider.of<ApplicationState>(context).theme ==
                      PWSTheme.Blacked
                  ? Colors.black
                  : Colors.white,
            ),
            label: Text(
              "add",
              style: TextStyle(
                color: Provider.of<ApplicationState>(context).theme ==
                        PWSTheme.Blacked
                    ? Colors.black
                    : Colors.white,
              ),
            ),
            key: _fabKey,
          ),
          body: Builder(
            builder: (context) => ListView(
              children: <Widget>[
                Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const ListTile(
                          title: Text(
                            'Theme settings',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: <Widget>[
                              ToggleButtons(
                                children: [
                                  _toggleButton("Day", Colors.lightBlue),
                                  _toggleButton("Evening", Colors.deepOrange),
                                  _toggleButton("Night", Colors.deepPurple),
                                  _toggleButton("Grey", Colors.blueGrey),
                                  _toggleButton("Blacked", Colors.black),
                                ],
                                onPressed: (int index) async {
                                  for (int buttonIndex = 0;
                                      buttonIndex < _themeSelection.length;
                                      buttonIndex++) {
                                    if (buttonIndex == index) {
                                      _themeSelection[buttonIndex] = true;
                                    } else {
                                      _themeSelection[buttonIndex] = false;
                                    }
                                  }
                                  SharedPreferences prefs =
                                      await SharedPreferences.getInstance();
                                  switch (index) {
                                    case 0:
                                      Provider.of<ApplicationState>(context)
                                          .setTheme(PWSTheme.Day);
                                      prefs.setString("theme", "Day");
                                      break;
                                    case 1:
                                      Provider.of<ApplicationState>(context)
                                          .setTheme(PWSTheme.Evening);
                                      prefs.setString("theme", "Evening");
                                      break;
                                    case 2:
                                      Provider.of<ApplicationState>(context)
                                          .setTheme(PWSTheme.Night);
                                      prefs.setString("theme", "Night");
                                      break;
                                    case 3:
                                      Provider.of<ApplicationState>(context)
                                          .setTheme(PWSTheme.Grey);
                                      prefs.setString("theme", "Grey");
                                      break;
                                    case 4:
                                      Provider.of<ApplicationState>(context)
                                          .setTheme(PWSTheme.Blacked);
                                      prefs.setString("theme", "Blacked");
                                      break;
                                  }
                                  setState(() {});
                                },
                                isSelected: _themeSelection,
                              ),
                            ],
                          ),
                        ),
                        const ListTile(
                          title: Text(
                            'Generic settings',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Update timer visibility"),
                            Switch(
                              value: visibilityUpdateTimer,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityUpdateTimer = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityUpdateTimer", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Wind speed visibility"),
                            Switch(
                              value: visibilityWindSpeed,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityWindSpeed = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityWindSpeed", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Pressure visibility"),
                            Switch(
                              value: visibilityPressure,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityPressure = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityPressure", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Wind direction visibility"),
                            Switch(
                              value: visibilityWindDirection,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityWindDirection = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityWindDirection", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Humidity visibility"),
                            Switch(
                              value: visibilityHumidity,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityHumidity = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityHumidity", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Temperature (small) visibility"),
                            Switch(
                              value: visibilityTemperature,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityTemperature = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityTemperature", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Wind chill visibility"),
                            Switch(
                              value: visibilityWindChill,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityWindChill = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityWindChill", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Rain visibility"),
                            Switch(
                              value: visibilityRain,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityRain = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityRain", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Dew visibility"),
                            Switch(
                              value: visibilityDew,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityDew = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityDew", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Sunrise hour visibility"),
                            Switch(
                              value: visibilitySunrise,
                              onChanged: (value) async {
                                setState(() {
                                  visibilitySunrise = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilitySunrise", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Sunset hour visibility"),
                            Switch(
                              value: visibilitySunset,
                              onChanged: (value) async {
                                setState(() {
                                  visibilitySunset = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilitySunset", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Moonrise hour visibility"),
                            Switch(
                              value: visibilityMoonrise,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityMoonrise = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityMoonrise", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text("Moonset hour visibility"),
                            Switch(
                              value: visibilityMoonset,
                              onChanged: (value) async {
                                setState(() {
                                  visibilityMoonset = value;
                                });
                                Provider.of<ApplicationState>(context)
                                    .updateVisibilities = true;
                                SharedPreferences prefs =
                                    await SharedPreferences.getInstance();
                                prefs.setBool("visibilityMoonset", value);
                              },
                              activeTrackColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                              activeColor:
                                  Provider.of<ApplicationState>(context)
                                      .mainColor,
                            ),
                          ],
                        ),
                        SizedBox(height: 15.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              "Widget refresh interval (min):",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Container(
                              margin: EdgeInsets.only(
                                right: 15,
                              ),
                              child: Text(
                                '${refreshInterval.toInt()}',
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            Flexible(
                              flex: 1,
                              child: Slider(
                                value: refreshInterval,
                                activeColor:
                                    Provider.of<ApplicationState>(context)
                                        .mainColor,
                                onChanged: (value) async {
                                  setState(() => refreshInterval = value);
                                  SharedPreferences prefs =
                                      await SharedPreferences.getInstance();
                                  prefs.setInt(
                                      "widget_refresh_interval", value.toInt());
                                },
                                min: 1,
                                max: 60,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: EdgeInsets.only(bottom: 65),
                  child: ListView.builder(
                    physics: ScrollPhysics(),
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    itemCount: _sources.length,
                    itemBuilder: (context, position) {
                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 6.0),
                        child: ListTile(
                            title: Text(
                              _sources[position].name,
                              style: TextStyle(fontSize: 20.0),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _sources[position].url,
                              style: TextStyle(fontSize: 12.0),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Container(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color:
                                          Provider.of<ApplicationState>(context)
                                              .mainColorDark,
                                    ),
                                    onPressed: () {
                                      _editSource(position);
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red[700],
                                    ),
                                    onPressed: () {
                                      _deleteSource(position);
                                    },
                                  ),
                                ],
                              ),
                            )),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleButton(String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: EdgeInsets.all(8.0),
        width: 30.0,
        height: 30.0,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  _addSource() {
    showDialog(
      context: context,
      builder: (ctx) => Provider<ApplicationState>.value(
        value: Provider.of<ApplicationState>(context),
        child: AlertDialog(
          title: Text("Add source"),
          content: Form(
            key: _addFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _addNameController,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return "You must set a source name.";
                      return null;
                    },
                    decoration: InputDecoration.collapsed(
                        hintText: "Source name",
                        border: UnderlineInputBorder()),
                    maxLines: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextFormField(
                    keyboardType: TextInputType.url,
                    controller: _addUrlController,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return "You must set a source url.";
                      return null;
                    },
                    decoration: InputDecoration.collapsed(
                        hintText: "Realtime file URL",
                        border: UnderlineInputBorder()),
                    maxLines: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: TextFormField(
                    keyboardType: TextInputType.number,
                    controller: _addIntervalController,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          int.tryParse(value) == null ||
                          int.tryParse(value) < 0)
                        return "Please set a valid interval.";
                      return null;
                    },
                    decoration: InputDecoration.collapsed(
                        hintText: "Refresh interval (sec).",
                        border: UnderlineInputBorder()),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            FlatButton(
              child: Text("Add"),
              onPressed: () async {
                FocusScope.of(ctx).requestFocus(FocusNode());
                if (_addFormKey.currentState.validate()) {
                  _addFormKey.currentState.save();
                  Source source = Source(
                      Provider.of<ApplicationState>(context).countID++,
                      _addNameController.text,
                      _addUrlController.text,
                      autoUpdateInterval:
                          int.parse(_addIntervalController.text));
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  _sources.add(source);
                  List<String> sourcesJSON = List();
                  for (Source source in _sources) {
                    String sourceJSON = jsonEncode(source);
                    sourcesJSON.add(sourceJSON);
                  }
                  prefs.setStringList("sources", sourcesJSON);
                  prefs.setInt("count_id",
                      Provider.of<ApplicationState>(context).countID);
                  _retrieveSources();
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
    _addNameController.text = "";
    _addUrlController.text = "";
    _addIntervalController.text = "";
  }

  _editSource(int position) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Edit " + _sources[position].name),
            content: Form(
              key: _editFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: TextFormField(
                      controller: _editNameController,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return "You must set a source name.";
                        return null;
                      },
                      decoration: InputDecoration.collapsed(
                          hintText: "Source name",
                          border: UnderlineInputBorder()),
                      maxLines: 1,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: TextFormField(
                      keyboardType: TextInputType.url,
                      controller: _editUrlController,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return "You must set a source url.";
                        return null;
                      },
                      decoration: InputDecoration.collapsed(
                        hintText: "Realtime file URL",
                        border: UnderlineInputBorder(),
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      controller: _editIntervalController,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            int.tryParse(value) == null ||
                            int.tryParse(value) < 0)
                          return "Please set a valid interval.";
                        return null;
                      },
                      decoration: InputDecoration.collapsed(
                          hintText: "Refresh interval (sec).",
                          border: UnderlineInputBorder()),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text("Close"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              FlatButton(
                child: Text("Edit"),
                onPressed: () async {
                  if (_editFormKey.currentState.validate()) {
                    _editFormKey.currentState.save();
                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    _sources[position].name = _editNameController.text;
                    _sources[position].url = _editUrlController.text;
                    _sources[position].autoUpdateInterval =
                        int.parse(_editIntervalController.text);
                    List<String> sourcesJSON = List();
                    for (Source source in _sources) {
                      String sourceJSON = jsonEncode(source);
                      sourcesJSON.add(sourceJSON);
                    }
                    prefs.setStringList("sources", sourcesJSON);
                    _retrieveSources();
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        });
    setState(() {
      _editNameController.text = _sources[position].name;
      _editUrlController.text = _sources[position].url;
      _editIntervalController.text =
          _sources[position].autoUpdateInterval.toString();
    });
  }

  _deleteSource(int position) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: Text("Delete " + _sources[position].name + "?"),
          content: Text(
              "This operation is irreversible, if you press Yes this source will be deleted. You really want to delete it?"),
          actions: <Widget>[
            FlatButton(
              child: Text("Yes"),
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                List<String> sourcesJSON = List();
                int index = prefs.getInt("last_used_source") ?? -1;
                if (index == _sources[position].id)
                  prefs.remove("last_used_source");
                _sources.removeAt(position);
                for (Source source in _sources) {
                  String sourceJSON = jsonEncode(source);
                  sourcesJSON.add(sourceJSON);
                }
                prefs.setStringList("sources", sourcesJSON);
                _retrieveSources();
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<Null> _getSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      visibilityUpdateTimer = prefs.getBool("visibilityUpdateTimer");
      visibilityWindSpeed = prefs.getBool("visibilityWindSpeed");
      visibilityPressure = prefs.getBool("visibilityPressure");
      visibilityWindDirection = prefs.getBool("visibilityWindDirection");
      visibilityHumidity = prefs.getBool("visibilityHumidity");
      visibilityTemperature = prefs.getBool("visibilityTemperature");
      visibilityWindChill = prefs.getBool("visibilityWindChill");
      visibilityRain = prefs.getBool("visibilityRain");
      visibilityDew = prefs.getBool("visibilityDew");
      visibilitySunrise = prefs.getBool("visibilitySunrise");
      visibilitySunset = prefs.getBool("visibilitySunset");
      visibilityMoonrise = prefs.getBool("visibilityMoonrise");
      visibilityMoonset = prefs.getBool("visibilityMoonset");
      visibilityUpdateTimer ??= true;
      visibilityWindSpeed ??= true;
      visibilityPressure ??= true;
      visibilityWindDirection ??= true;
      visibilityHumidity ??= true;
      visibilityTemperature ??= true;
      visibilityWindChill ??= true;
      visibilityRain ??= true;
      visibilityDew ??= true;
      visibilitySunrise ??= true;
      visibilitySunset ??= true;
      visibilityMoonrise ??= true;
      visibilityMoonset ??= true;
      refreshInterval = prefs.getInt("widget_refresh_interval").toDouble();
    });
  }

  _retrieveSources() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _sources = List();
      List<String> sources = prefs.getStringList("sources");
      if (sources == null || sources.length == 0) {
        _showCoachMarkFAB();
      } else
        for (String sourceJSON in sources) {
          try {
            dynamic source = jsonDecode(sourceJSON);
            _sources.add(Source(source["id"], source["name"], source["url"],
                autoUpdateInterval: (source["autoUpdateInterval"] != null)
                    ? source["autoUpdateInterval"]
                    : 0));
          } catch (Exception) {
            prefs.setStringList("sources", null);
          }
        }
    });
  }

  _showCoachMarkFAB() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool("coach_mark_shown") ?? false)) {
      CoachMark coachMarkFAB = CoachMark();
      RenderBox target = _fabKey.currentContext.findRenderObject();
      Rect markRect = target.localToGlobal(Offset.zero) & target.size;
      markRect = Rect.fromCircle(
          center: markRect.center, radius: markRect.longestSide * 0.6);
      coachMarkFAB.show(
          targetContext: _fabKey.currentContext,
          markRect: markRect,
          children: [
            Center(
                child: Text("Tap here\nto add a source",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24.0,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                    )))
          ],
          duration: null,
          onClose: () async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.setBool("coach_mark_shown", true);
          });
    }
  }
}
