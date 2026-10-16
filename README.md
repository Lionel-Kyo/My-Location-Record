# My Location Record

A production-ready Flutter application built exclusively for Android that records device locations at custom minute intervals using a reliable native Android Foreground Service. Powered entirely by free resources and OpenStreetMap, it groups recorded trajectories by custom daily time windows (e.g., 06:00 to 06:00) while properly handling UTC storage and timezone adjustments, with full export capabilities to `.json` and `.gpx` files.

---

## Features

- **Android Native Background Service:** Uses a foreground service coupled with `FusedLocationProviderClient` to ensure continuous background tracking even when the app is minimized or closed.
- **100% Free Maps:** Integrated with `flutter_map` and OpenStreetMap tile layers—no paid API keys, credit cards, or external mapping subscriptions required.
- **Custom Minute Intervals:** Configure how frequently background location coordinates are captured.
- **Custom Daily Time Windows:** Group records by custom start/end hour boundaries (default `06:00` to `06:00`, or `00:00` to `00:00`).
- **Timezone-Aware UTC Storage:** Stores timestamps in UTC and gracefully adjusts bounds to local device time.
- **Data Export:** Instantly export any day's route record into standard `.json` or `.gpx` (XML) formats.

---

## Usage Instructions

1. **Grant Permissions:** Upon launching the app, allow foreground and background location permissions when prompted.
2. **Configure Intervals:** Use the slider to set your desired recording interval in minutes (1 to 60 mins).
3. **Select Day Window:** Choose your preferred tracking day cycle start hour (e.g., `6:00` for 06:00–06:00 daily splits).
4. **Start/Stop Recording:** Tap **Start Recording** to initiate the native Android foreground service. You can safely minimize or close the app while it runs.
5. **View & Export:** Navigate to the **Saved Records** list to view your route on the OpenStreetMap interface or export data to JSON/GPX formats.

---

## License

This project is open-source and available under the MIT License.