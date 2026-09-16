# Labelled trip-window collection

When auto detection completes, the app stores a separate local training record keyed by a temporary candidate ID. It contains only the four-class training fields: speed summary, distance, and timestamped GPS points. No accelerometer readings are collected until the app has an IMU stream.

The one-time consent dialog appears before auto detection begins. A confirmation or edited save labels the matching record with the final four-class choice (`car` becomes `vehicle`). Records use SharedPreferences and survive offline/restarts independently of Trip records; Trip, carbon, dashboard, and report schemas are unchanged.

For the present small team study, the export button in Trip History copies labelled JSON to the clipboard for manual collection. This is deliberately manual and does not force any upload. Team members should securely paste it into the project’s controlled collection location and remove it from the clipboard afterwards. A future server-side research-data endpoint can consume this format without changing the trip pipeline.
