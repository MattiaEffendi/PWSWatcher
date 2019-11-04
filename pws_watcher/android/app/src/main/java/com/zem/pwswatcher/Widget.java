package com.zem.pwswatcher;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.ComponentName;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;
import android.util.TypedValue;
import android.widget.RemoteViews;

import org.json.JSONException;
import org.json.JSONObject;
import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserException;
import org.xmlpull.v1.XmlPullParserFactory;

import java.io.IOException;
import java.io.StringReader;
import java.text.SimpleDateFormat;
import java.text.DateFormat;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Date;
import java.util.List;

import com.zem.pwswatcher.model.Source;


import okhttp3.Call;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;


import static com.zem.pwswatcher.WidgetConfigurationActivity.SHARED_PREFERENCES_NAME;


public class Widget extends AppWidgetProvider {
    static final String UPDATE_FILTER = "com.zem.pwswatcher.UPDATE";
    static String prefWindUnit = "km/h";
    static String prefRainUnit = "mm";
    static String prefPressUnit = "mb";
    static String prefTempUnit = "°C";
    static String prefDewUnit = "°C";

    private void updateWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId, Bundle widgetInfo) {
        int minWidth = widgetInfo.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH);
        int width = widgetInfo.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH);
        int minHeight = widgetInfo.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT);
        int height = widgetInfo.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT);
        int wCells = (int) ((minWidth + width) / 120);
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget);
        if (wCells > 2) {
            double prop = wCells / 3.0;
            views.setTextViewTextSize(R.id.tv_location, TypedValue.COMPLEX_UNIT_SP, (float) (14 * prop));
            views.setTextViewTextSize(R.id.tv_temperature, TypedValue.COMPLEX_UNIT_SP, (float) (18 * prop));
            views.setTextViewTextSize(R.id.tv_datetime, TypedValue.COMPLEX_UNIT_SP, (float) (14 * prop));
        } else {
            views.setTextViewTextSize(R.id.tv_location, TypedValue.COMPLEX_UNIT_SP, 14f);
            views.setTextViewTextSize(R.id.tv_temperature, TypedValue.COMPLEX_UNIT_SP, 18f);
            views.setTextViewTextSize(R.id.tv_datetime, TypedValue.COMPLEX_UNIT_SP, 14f);
        }
        appWidgetManager.updateAppWidget(appWidgetId, views);
    }

    @Override
    public void onAppWidgetOptionsChanged(Context context, AppWidgetManager appWidgetManager, int appWidgetId, Bundle widgetInfo) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, widgetInfo);
        updateWidget(context, appWidgetManager, appWidgetId, widgetInfo);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent.getAction() == null)
            return;
        AppWidgetManager widgetManager = AppWidgetManager.getInstance(context);
        ComponentName widgetComponent = new ComponentName(context.getPackageName(), this.getClass().getName());
        int[] widgetId = widgetManager.getAppWidgetIds(widgetComponent);
        int widgetNum = widgetId.length;
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.widget);
        if (intent.getAction().equals(AppWidgetManager.ACTION_APPWIDGET_UPDATE)) {
            SharedPreferences sharedPrefs = context.getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE);
            Intent updateIntent = new Intent(context, Widget.class);
            updateIntent.setAction(UPDATE_FILTER);
            PendingIntent pendingUpdateIntent = PendingIntent.getBroadcast(context, 0, updateIntent, 0);
            AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            long refreshRate = sharedPrefs.getLong("flutter.widget_refresh_interval", 15);
            alarmManager.setRepeating(AlarmManager.ELAPSED_REALTIME, SystemClock.elapsedRealtime(), refreshRate * 60000, pendingUpdateIntent);
        } else if (intent.getAction().equals(UPDATE_FILTER)) {
            SharedPreferences sharedPrefs = context.getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE);
            for (int i = 0; i < widgetNum; i++) {
                String sourceJSON = sharedPrefs.getString("widget_" + widgetId[i], null);
                Widget.prefWindUnit = sharedPrefs.getString("flutter.prefWindUnit", "km/h");
                Widget.prefRainUnit= sharedPrefs.getString("flutter.prefRainUnit", "mm");
                Widget.prefPressUnit= sharedPrefs.getString("flutter.prefPressUnit", "mb");
                Widget.prefTempUnit= sharedPrefs.getString("flutter.prefTempUnit", "°C");
                Widget.prefDewUnit= sharedPrefs.getString("flutter.prefDewUnit", "°C");
                if (sourceJSON != null) {
                    Source source = null;
                    try {
                        JSONObject obj = new JSONObject(sourceJSON);
                        source = new Source(obj.getInt("id"), obj.getString("name"), obj.getString("url"));
                    } catch (JSONException ignored) {
                    }
                    if (source != null) {
                        if (source.getUrl().endsWith(".txt") || source.getUrl().endsWith(".xml")) {
                            DataElaborator dataElaborator = new DataElaborator(context, source, widgetId[i]);
                            dataElaborator.execute();
                        } else {
                            String originalSource = source.getUrl();
                            source.setUrl(originalSource + "/realtime.txt");
                            DataElaborator dataElaborator = new DataElaborator(context, source, widgetId[i]);
                            dataElaborator.execute();
                            source.setUrl(originalSource + "/realtime.xml");
                            dataElaborator = new DataElaborator(context, source, widgetId[i]);
                            dataElaborator.execute();
                        }
                    }
                }
            }
        } else if (intent.getAction().equals(AppWidgetManager.ACTION_APPWIDGET_DISABLED)) {
            Intent updateIntent = new Intent(context, Widget.class);
            updateIntent.setAction(UPDATE_FILTER);
            PendingIntent pendingUpdateIntent = PendingIntent.getBroadcast(context, 0, updateIntent, 0);
            AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            alarmManager.cancel(pendingUpdateIntent);
            SharedPreferences sharedPrefs = context.getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = sharedPrefs.edit();
            for (int i = 0; i < widgetNum; i++) {
                editor.remove("widget_" + widgetId[i]);
                Log.d("PWSWatcher", "Deleted Widget #" + widgetId[i]);
            }
            editor.apply();
        } else if (intent.getAction().equals(AppWidgetManager.ACTION_APPWIDGET_OPTIONS_CHANGED)) {
            super.onReceive(context, intent);
        }
    }

    public static class DataElaborator extends AsyncTask<String, Void, String> {
        private Context context;
        private Source source;
        private int id;

        public DataElaborator(Context context, Source source, int id) {
            this.context = context;
            this.source = source;
            this.id = id;
        }

        @Override
        protected String doInBackground(String... params) {
            try {
                OkHttpClient client = new OkHttpClient.Builder().build();
                Request request = new Request.Builder()
                        .url(this.source.getUrl())
                        .build();
                Call call = client.newCall(request);
                Response response = call.execute();
                return response.body().string();
            } catch (IOException e) {
                e.printStackTrace();
                return null;
            }
        }

        @Override
        protected void onPostExecute(String resp) {
            if (resp == null)
                return;
            RemoteViews view = new RemoteViews(context.getPackageName(), R.layout.widget);
            boolean done = false;
            try {
                if (this.source.getUrl().endsWith("clientraw.txt")) {
                    done = visualizeClientRawTXT(resp, view);
                } else if (this.source.getUrl().endsWith(".txt")) {
                    done = visualizeRealtimeTXT(resp, view);
                } else if (this.source.getUrl().endsWith(".xml")) {
                    done = visualizeRealtimeXML(resp, view);
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
            if (done) {
                AppWidgetManager manager = AppWidgetManager.getInstance(context);
                manager.updateAppWidget(this.id, view);
            }
        }

        private boolean visualizeClientRawTXT(String resp, RemoteViews view) {
            try {
                String[] values = resp.split(" ");
                view.setTextViewText(R.id.tv_location, this.source.getName());
                view.setTextViewText(R.id.tv_temperature, convertTemperature(Double.parseDouble(values[4]), "°C", Widget.prefTempUnit) + Widget.prefTempUnit);
                view.setTextViewText(R.id.tv_humidity, values[5] + "%");
                view.setTextViewText(R.id.tv_pressure, convertPressure(Double.parseDouble(values[6]), "hPa", Widget.prefPressUnit) + Widget.prefPressUnit);
                view.setTextViewText(R.id.tv_rain, convertRain(Double.parseDouble(values[7]), "mm", Widget.prefRainUnit) + Widget.prefRainUnit);
                view.setTextViewText(R.id.tv_windspeed, convertWindSpeed(Double.parseDouble(values[2]), "kts", Widget.prefWindUnit) + Widget.prefWindUnit);
                String stringDate = null;
                try {
                    String date = values[74] + " " + values[29]+ ":" + values[30]+ ":" + values[31];
                    date = date.trim().replace("/", "-").replace(".", "-");
                    SimpleDateFormat format = new SimpleDateFormat("dd-MM-yyyy hh:mm:ss");
                    Date newDate = format.parse(date);
                    stringDate = android.text.format.DateFormat.getDateFormat(context).format(newDate) + " " + android.text.format.DateFormat.getTimeFormat(context).format(newDate).replace(".000", "");
                } catch (Exception e) {
                    String date = values[74] + " " + values[29]+ ":" + values[30]+ ":" + values[31];
                    stringDate = date.trim().replace("/", "-").replace(".", "-");
                }
                view.setTextViewText(R.id.tv_datetime, stringDate);
                return true;
            } catch (Exception ignored) {
            }
            return false;
        }

        private boolean visualizeRealtimeTXT(String resp, RemoteViews view) {
            try {
                String[] values = resp.split(" ");
                view.setTextViewText(R.id.tv_location, this.source.getName());
                view.setTextViewText(R.id.tv_temperature, values[2] + (values[14].contains("°") ? "" : "°") + values[14]);
                view.setTextViewText(R.id.tv_humidity, values[3] + "%");
                view.setTextViewText(R.id.tv_pressure, values[10] + " " +values[15]);
                view.setTextViewText(R.id.tv_rain, values[9] + " " + values[16]);
                view.setTextViewText(R.id.tv_windspeed, values[5] + " " + values[13]);
                String stringDate = null;
                try {
                    String date = values[0] + " " + values[1];
                    date = date.trim().replace("/", "-").replace(".", "-");
                    int year = Calendar.getInstance().get(Calendar.YEAR);
                    date = date.substring(0, 6) +
                            Integer.toString(year).substring(0, 2) +
                            date.substring(6);
                    date = date.substring(6, 10) + "-" + date.substring(3, 5) + "-" + date.substring(0, 2) + " " + date.substring(11);
                    SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss");
                    Date newDate = format.parse(date);
                    stringDate = android.text.format.DateFormat.getDateFormat(context).format(newDate) + " " + android.text.format.DateFormat.getTimeFormat(context).format(newDate).replace(".000", "");
                } catch (Exception e) {
                    stringDate = values[0].trim() + " " + values[1].trim();
                }
                view.setTextViewText(R.id.tv_datetime, stringDate);
                return true;
            } catch (Exception ignored) {
            }
            return false;
        }

        private boolean visualizeRealtimeXML(String resp, RemoteViews view) {
            try {
                XmlPullParserFactory parserFactory;
                parserFactory = XmlPullParserFactory.newInstance();
                XmlPullParser parser = parserFactory.newPullParser();
                parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false);
                parser.setInput(new StringReader(resp));
                int eventType = parser.getEventType();
                String location = null, date = null, time = null, temp = null, tempunit = null, hum = null,
                    press = null, pressunit = null, rain = null, rainunit = null, wind = null, windunit = null;
                String[] attributes = {"misc", "realtime", "today", "yesterday", "record"};
                while (eventType != XmlPullParser.END_DOCUMENT) {
                    String eltName = null;
                    switch (eventType) {
                        case XmlPullParser.START_TAG:
                            eltName = parser.getName();
                            if ("misc".equals(eltName)) {
                                for (int i = 0; i < parser.getAttributeCount(); i++) {
                                    if (parser.getAttributeName(i).equals("data") && parser.getAttributeValue(i).equals("station_location")) {
                                        view.setTextViewText(R.id.tv_location, parser.nextText());
                                    }
                                }
                            }
                            if ("data".equals(eltName)) {
                                for (int i = 0; i < parser.getAttributeCount(); i++) {
                                    if (Arrays.asList(attributes).contains(parser.getAttributeName(i))) {
                                        if (parser.getAttributeValue(i).equals("temp")) {
                                            temp = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("tempunit")) {
                                            tempunit = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("hum")) {
                                            hum = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("press") || parser.getAttributeValue(i).equals("barometer")) {
                                            press = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("barunit")) {
                                            pressunit = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("todaysrain") || parser.getAttributeValue(i).equals("today_rainfall")) {
                                            rain = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("rainunit")) {
                                            rainunit = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("windspeed") || parser.getAttributeValue(i).equals("avg_windspeed")) {
                                            wind = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("windunit")) {
                                            windunit = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("station_date")) {
                                            date = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("station_time")) {
                                            time = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("location")) {
                                            location = parser.nextText();
                                        } else if (parser.getAttributeValue(i).equals("refresh_time")) {
                                            String tmpDatetime = parser.nextText();
                                            date = tmpDatetime.substring(0, 10);
                                            time = tmpDatetime.substring(12);
                                        }
                                    }
                                }
                            }
                            break;
                    }
                    eventType = parser.next();
                }
                view.setTextViewText(R.id.tv_location, (location != null) ? location : this.source.getName());
                view.setTextViewText(R.id.tv_temperature, ((temp != null) ? temp : "") + ((tempunit != null) ? (tempunit.contains("°") ? tempunit : "°" + tempunit) : ""));
                view.setTextViewText(R.id.tv_humidity, ((hum != null) ? (hum.contains("%") ? hum : hum + "%") : "-"));
                view.setTextViewText(R.id.tv_pressure, ((press != null) ? press : "-") + " " + ((pressunit != null) ? pressunit : ""));
                view.setTextViewText(R.id.tv_rain, ((rain != null) ? rain : "-") + " " + ((rainunit != null) ? rainunit : ""));
                view.setTextViewText(R.id.tv_windspeed, ((wind != null) ? wind : "-") + " " + ((windunit != null) ? windunit : ""));
                String stringDate = null;
                try {
                    String tmpDatetime = date.trim() + " " + time.trim();
                    tmpDatetime = tmpDatetime.trim().replace("/", "-").replace(".", "-");
                    SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd hh:mm:ss");
                    Date newDate = format.parse(tmpDatetime);
                    stringDate = android.text.format.DateFormat.getDateFormat(context).format(newDate) + " " + android.text.format.DateFormat.getTimeFormat(context).format(newDate).replace(".000", "");
                } catch (Exception e) {
                    stringDate = ((date != null) ? (date.trim() + " ") : "") + ((time != null) ? time.trim() : "");
                }
                view.setTextViewText(R.id.tv_datetime, stringDate);
                return true;
            } catch (Exception e) {
                e.printStackTrace();
            }
            return false;
        }

        private double convertWindSpeed(double value, String unit, String preferred) {
            double kmh = 0.0;
            switch (unit.trim().replaceAll("/", "").toLowerCase()) {
            case "kts":
                {
                kmh = ktsToKmh(value);
                break;
                }
            case "mph":
                {
                kmh = mphToKmh(value);
                break;
                }
            case "ms":
                {
                kmh = msToKmh(value);
                break;
                }
            default:
                {
                kmh = value;
                break;
                }
            }
            double toReturn = 0.0;
            switch (preferred.trim().replaceAll("/", "").toLowerCase()) {
            case "kts":
                {
                toReturn = roundTo2Decimal(kmhToKts(kmh));
                break;
                }
            case "mph":
                {
                toReturn = roundTo2Decimal(kmhToMph(kmh));
                break;
                }
            case "ms":
                {
                toReturn = roundTo2Decimal(kmhToMs(kmh));
                break;
                }
            default:
                {
                toReturn = roundTo2Decimal(kmh);
                break;
                }
            }
            return toReturn;
        }

        private double convertRain(double value, String unit, String preferred) {
            double toReturn = 0.0;
            if (unit.trim().replaceAll("/", "").toLowerCase() != preferred.trim().replaceAll("/", "").toLowerCase()) {
                if (unit.trim().replaceAll("/", "").toLowerCase() == "mm") {
                    toReturn = roundTo2Decimal(mmToIn(value));
                } else {
                    toReturn = roundTo2Decimal(inToMm(value));
                }
            } else
                toReturn = value;
            return toReturn;
        }

        private double convertPressure(double value, String unit, String preferred) {
            double hPa;
            switch (unit.trim().replaceAll("/", "").toLowerCase()) {
            case "inhg":
                {
                hPa = inhgToHPa(value);
                break;
                }
            case "mb":
                {
                hPa = mbToHPa(value);
                break;
                }
            default:
                {
                hPa = value;
                break;
                }
            }
            double toReturn = 0.0;
            switch (preferred.trim().replaceAll("/", "").toLowerCase()) {
            case "inhg":
                {
                toReturn = roundTo2Decimal(hPaToInhg(hPa));
                break;
                }
            case "mb":
                {
                toReturn = roundTo2Decimal(hPaToMb(hPa));
                break;
                }
            default:
                {
                toReturn = roundTo2Decimal(hPa);
                break;
                }
            }
            return toReturn;
        }

        private double convertTemperature(double value, String unit, String preferred) {
            double toReturn = 0.0;
            String newUnit = unit.trim().replaceAll("/", "").replaceAll("°", "").toLowerCase();
            String newPref = preferred.trim().replaceAll("/", "").replaceAll("°", "").toLowerCase();
            if (newUnit.charAt(newUnit.length() - 1) != newPref.charAt(newPref.length() - 1)) {
                if (newUnit.charAt(newUnit.length() - 1) == 'f') {
                    toReturn = roundTo2Decimal(fToC(value));
                } else {
                    toReturn = roundTo2Decimal(cToF(value));
                }
            } else {
                toReturn = value;
            }
            return toReturn;
        }

        double roundTo2Decimal(double value) {
            return (double) Math.round(value * 100d) / 100d;
        }

        double ktsToKmh(double kts) {
            return kts * 1.852;
        }

        double mphToKmh(double mph) {
            return mph * 1.60934;
        }

        double msToKmh(double ms) {
            return ms * 3.6;
        }

        double kmhToKts(double kmh) {
            return kmh / 1.852;
        }

        double kmhToMph(double kmh) {
            return kmh / 1.60934;
        }

        double kmhToMs(double kmh) {
            return kmh / 3.6;
        }

        double mmToIn(double mm) {
            return mm / 25.4;
        }

        double inToMm(double inc) {
            return inc * 25.4;
        }

        double inhgToHPa(double inhg) {
            return inhg * 33.86389;
        }

        double mbToHPa(double mb) {
            return mb;
        }

        double hPaToInhg(double pa) {
            return pa / 33.86389;
        }

        double hPaToMb(double pa) {
            return pa;
        }

        double fToC(double f) {
            return (f - 32) * 5 / 9;
        }

        double cToF(double c) {
            return (c * 9 / 5) + 32;
        }
    }
}
