import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as provider;
import 'package:pws_watcher/model/parsing_utilities.dart';
import 'package:pws_watcher/model/pws.dart';
import 'package:pws_watcher/model/state\.dart';
import 'package:pws_watcher/model/value_setting.dart';
import 'package:pws_watcher/pages/detail/detail.dart';
import 'package:pws_watcher/pages/home/widgets/pws_state_header.dart';
import 'package:pws_watcher/pages/home/widgets/update_timer.dart';
import 'package:pws_watcher/pages/home/widgets/variable_row.dart';
import 'package:pws_watcher/services/parsing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pws_temperature_row.dart';
import 'snapshot_preview.dart';

class PWSStatePage extends StatefulWidget {
  PWSStatePage(this.source);

  final PWS source;

  @override
  _PWSStatePageState createState() => _PWSStatePageState();
}

class _PWSStatePageState extends State<PWSStatePage> {
  GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();
  ParsingService _parsingService;

  Map<String, bool> _visibilityMap = {};
  bool _visibilityCurrentWeatherIcon = true;
  bool _visibilityUpdateTimer = true;

  @override
  void initState() {
    // Retrieves visibility preferences
    _retrievePreferences();

    // Initialize the parsing service with this PWS as source
    _parsingService = ParsingService(
      widget.source,
      provider.Provider.of<ApplicationState>(context, listen: false),
    );

    super.initState();
  }

  @override
  void didUpdateWidget(PWSStatePage oldWidget) {
    if (oldWidget.source != widget.source) {
      // If source changed, update the parsing service source so it continues to work
      _parsingService.setSource(widget.source);
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (provider.Provider.of<ApplicationState>(context, listen: false)
        .updatePreferences) {
      // If preferences changed force an update
      provider.Provider.of<ApplicationState>(context, listen: false)
          .updatePreferences = false;

      _retrievePreferences();

      _parsingService.setApplicationState(
        provider.Provider.of<ApplicationState>(context, listen: false),
      );
    }

    return StreamBuilder<Object>(
      stream: _parsingService.variables$,
      builder: (context, snapshot) {
        Widget emptyPage = _buildPage([
          SizedBox(height: 50.0),
          Center(
            child: Container(
              height: 100.0,
              width: 100.0,
              child: CircularProgressIndicator(),
            ),
          )
        ]);

        if (snapshot.hasError || !snapshot.hasData) {
          // Return an empty page with a spinning indicator
          return emptyPage;
        }

        Map<String, String> data = snapshot.data as Map<String, String>;

        // Retrieve significant data from parsing service
        var location = data["location"] ?? "Location";
        var datetime = data["datetime"] ?? "--/--/---- --:--:--";
        var temperature = data["temperature"] ?? "-";
        var tempUnit = data["tempUnit"] ?? "°C";

        // Retrieve current condition icon
        var currentConditionIndex =
            (int.parse(data["currentConditionIndex"] ?? "-1"));
        String currentConditionAsset;
        if (currentConditionIndex >= 0 &&
            currentConditionIndex < currentConditionDesc.length &&
            currentConditionMapping
                .containsKey(currentConditionDesc[currentConditionIndex])) {
          currentConditionAsset = getCurrentConditionAsset(
            currentConditionMapping[
                currentConditionDesc[currentConditionIndex]],
          );
        }

        bool thereIsUrl = widget.source.snapshotUrl != null &&
            widget.source.snapshotUrl.trim().isNotEmpty;

        return FutureBuilder(
          future: _buildValuesTable(data),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<Widget>> snapshot,
          ) {
            if (snapshot.hasError || !snapshot.hasData) {
              return emptyPage;
            }

            return _buildPage(
              [
                SizedBox(height: 20.0),
                PWSStateHeader(
                  location,
                  datetime,
                ),
                SizedBox(height: 30.0),
                PWSTemperatureRow(
                  '$temperature$tempUnit',
                  asset: _visibilityCurrentWeatherIcon
                      ? currentConditionAsset
                      : null,
                ),
                SizedBox(height: 50.0),
              ]
                ..addAll(snapshot.data)
                ..addAll([
                  thereIsUrl ? SizedBox(height: 30) : Container(),
                  thereIsUrl ? SnapshotPreview(widget.source) : Container(),
                  SizedBox(height: thereIsUrl ? 20.0 : 40.0),
                  _buildDetailButton(),
                ]),
            );
          },
        );
      },
    );
  }

  // FUNCTIONS

  Future<void> _refresh() async {
    _refreshKey.currentState.show();

    await _parsingService.updateData(force: true);
  }

  _openDetailPage() async {
    if (_parsingService.allDataSubject.value != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => provider.Provider<ApplicationState>.value(
            value:
                provider.Provider.of<ApplicationState>(context, listen: false),
            child: DetailPage(_parsingService.allDataSubject.value),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text("Error"),
            content: Text("Can't show more informations."),
            actions: <Widget>[
              FlatButton(
                textColor: Colors.deepOrange,
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
  }

  Future<Null> _retrievePreferences() async {
    try {
      List<ValueSetting> settings = await _retrieveValueSettings();

      SharedPreferences prefs = await SharedPreferences.getInstance();

      _visibilityCurrentWeatherIcon =
          prefs.getBool("visibilityCurrentWeatherIcon") ?? true;
      _visibilityUpdateTimer = prefs.getBool("visibilityUpdateTimer") ?? true;

      // Populate visibility map
      _visibilityMap.clear();
      for (ValueSetting setting in settings) {
        _visibilityMap[setting.visibilityVarName] =
            prefs.getBool(setting.visibilityVarName) ??
                setting.visibilityDefaultValue;
      }

      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  Future<List<ValueSetting>> _retrieveValueSettings() async {
    // Read values settings from assets
    String jsonString = await rootBundle.loadString("assets/values.json");
    List<dynamic> jsonResponse = jsonDecode(jsonString);

    // Parse the JSON
    List<ValueSetting> toReturn = [];
    for (dynamic valueSettings in jsonResponse) {
      toReturn.add(
        ValueSetting(
          name: valueSettings['name'],
          asset: valueSettings['asset'],
          valueVarName: valueSettings['valueVarName'],
          unitVarName: valueSettings['unitVarName'],
          visibilityVarName: valueSettings['visibilityVarName'],
          valueDefaultValue: valueSettings['valueDefaultValue'],
          unitDefaultValue: valueSettings['unitDefaultValue'],
          visibilityDefaultValue: valueSettings['visibilityDefaultValue'],
        ),
      );
    }

    return toReturn;
  }

  // WIDGETS

  Widget _buildUpdateIndicator(PWS source) {
    if (source.autoUpdateInterval != null) {
      if (source.autoUpdateInterval == 0) {
        // Show the manual update button
        return Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            tooltip: "Update",
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).accentColor,
            ),
            padding: EdgeInsets.all(0),
            onPressed: _refresh,
          ),
        );
      } else if (_visibilityUpdateTimer) {
        // Show the circular timer indicator
        return Align(
          alignment: Alignment.topLeft,
          child: Tooltip(
            message: "Update timer",
            child: UpdateTimer(
              Duration(seconds: source.autoUpdateInterval),
              () => _parsingService.setSource(widget.source),
            ),
          ),
        );
      } else {
        // Show nothings
        return Container(height: 40.0);
      }
    } else {
      return Container(height: 40.0);
    }
  }

  Widget _buildPage(List<Widget> children) {
    return RefreshIndicator(
      color: Theme.of(context).primaryColor,
      backgroundColor: Theme.of(context).accentColor,
      key: _refreshKey,
      onRefresh: _refresh,
      child: ListView(
        physics: AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        shrinkWrap: true,
        children: [_buildUpdateIndicator(widget.source)]..addAll(children),
      ),
    );
  }

  Widget _buildDetailButton() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          Text(
            "SEE ALL",
            maxLines: 1,
            style: Theme.of(context)
                .textTheme
                .subtitle1
                .copyWith(color: Theme.of(context).accentColor),
          ),
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Theme.of(context).accentColor,
            ),
            onPressed: _openDetailPage,
          ),
        ],
      ),
    );
  }

  Future<List<Widget>> _buildValuesTable(Map<String, String> values) async {
    List<ValueSetting> settings = await _retrieveValueSettings();

    List<Widget> toReturn = [];

    // Build the values table according to the settings and visibility map
    for (int i = 0; i < settings.length; i += 2) {
      ValueSetting leftSetting = settings[i];
      ValueSetting rightSetting =
          i + 1 < settings.length ? settings[i + 1] : null;

      toReturn.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: DoubleVariableRow(
            leftSetting.name,
            leftSetting.asset,
            values[leftSetting.valueVarName] ?? leftSetting.valueDefaultValue,
            values[leftSetting.unitVarName] ?? leftSetting.unitDefaultValue,
            rightSetting != null ? rightSetting.name : null,
            rightSetting != null ? rightSetting.asset : null,
            rightSetting != null
                ? (values[rightSetting.valueVarName] ??
                    rightSetting.valueDefaultValue)
                : null,
            rightSetting != null
                ? (values[rightSetting.unitVarName] ??
                    rightSetting.unitDefaultValue)
                : null,
            visibilityLeft: _visibilityMap[leftSetting.visibilityVarName],
            visibilityRight: rightSetting != null
                ? _visibilityMap[rightSetting.visibilityVarName]
                : false,
          ),
        ),
      );

      if (i + 2 < settings.length) {
        toReturn.add(SizedBox(height: 20.0));
      }
    }

    return toReturn;
  }
}
