# GPS auto-detection physical-device checklist

1. Install on a physical Android/iOS device, enable system location services, then tap **Enable auto trip detection** on Trip History and grant foreground location permission.
2. Move for more than five seconds at walking, cycling, or vehicle speed. Verify the detector stays foreground-only and does not create a trip while stationary.
3. Stop for at least `AutoTripDetector.stationaryTimeout` (currently three minutes). Verify the confirmation card shows the detected generic mode and GPS distance.
4. Tap ✓. Verify the normal Add Trip save path completes, then verify the new trip appears in Trip History, Dashboard, Reports, and Recommendations.
5. Repeat and tap Edit. Verify distance/mode are prefilled, make a correction, save, and repeat the same dashboard/report check.
6. With no network, confirm the normal offline save works; reconnect and verify the existing pending-trip sync sends it to the backend.

Notes: vehicle maps to the existing `car` transport value only for Review 1 persistence. This is not a car/bus/train classifier. Test boundary speeds (2, 7, and 20 km/h) and tune the documented five-second noise window / three-minute timeout based on observed GPS quality.
