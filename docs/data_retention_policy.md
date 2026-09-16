# Trip-data retention and privacy policy

The app stores trip records, labelled feature windows, and—only after explicit opt-in—GPS traces associated with a candidate trip. Feature windows contain derived speed statistics, distance, timestamped coordinates, and the final four-class label. The current app does not collect accelerometer data.

Raw coordinates remain on the device and are included only in the user-controlled training-window export. The ML inference service receives derived features only (speed, variance, maximum speed, and distance), never raw coordinates, following the cited speed-only privacy approach. Training exports must be kept in the project’s access-controlled study storage and deleted after aggregation; raw traces should be deleted within 90 days and derived labelled windows within 12 months, unless the participant requests deletion sooner.

Users can use **Settings → Delete my data** to remove locally stored trips and labelled windows and request deletion of server-side trips. Individual-trip deletion remains available. Research exports already transferred to an external study store must be removed by the study administrator on request; this limitation is disclosed to participants.
