"""Create a labelled four-class SHL feature table from canonical session CSVs.

The small adapter deliberately separates SHL's changing archive layouts from
feature engineering.  See README for converting official preview files into the
three documented canonical files, without relying on an unofficial mirror.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

WINDOW_SECONDS = 5  # Judgment call: matches the SHL 2019/2020 real-time frames.
ACCEL_SAMPLE_HZ = 100
LABEL_MAP = {
    "still": "stationary", "stationary": "stationary",
    "walk": "walking", "walking": "walking", "run": "walking",
    "bike": "cycling", "bicycle": "cycling", "cycling": "cycling",
    "car": "vehicle", "bus": "vehicle", "train": "vehicle", "subway": "vehicle", "tube": "vehicle",
    1: "stationary", 2: "walking", 3: "walking", 4: "cycling", 5: "vehicle", 6: "vehicle", 7: "vehicle", 8: "vehicle",
}


def map_label(value: object) -> str | None:
    if isinstance(value, str):
        value = value.strip().lower()
        try:
            value = int(float(value))
        except ValueError:
            pass
    return LABEL_MAP.get(value)


def vehicle_label(value: object) -> str | None:
    """Keep original SHL vehicle label for experimental Stage-2 training."""
    numeric = int(float(value)) if isinstance(value, str) and value.strip().replace('.', '', 1).isdigit() else value
    return {5: 'car', 6: 'bus', 7: 'train', 'car': 'car', 'bus': 'bus', 'train': 'train'}.get(str(numeric).lower(), {5: 'car', 6: 'bus', 7: 'train'}.get(numeric))


def dominant_frequency(magnitude: np.ndarray, sample_hz: int) -> float:
    centered = magnitude - magnitude.mean()
    spectrum = np.abs(np.fft.rfft(centered))
    frequencies = np.fft.rfftfreq(len(centered), d=1 / sample_hz)
    if len(spectrum) < 2:
        return 0.0
    spectrum[0] = 0  # exclude DC component
    return float(frequencies[int(np.argmax(spectrum))])


def rule_speed_label(speed_kmh: float) -> str:
    """Exact Review-1 fallback thresholds, for same-window baseline scoring."""
    if speed_kmh < 2:
        return "stationary"
    if speed_kmh < 7:
        return "walking"
    if speed_kmh <= 20:
        return "cycling"
    return "vehicle"


def _feature_session(session_dir: Path, user: str) -> list[dict[str, object]]:
    """Read canonical accel.csv, gps.csv and labels.csv for one session.

    accel.csv: timestamp,x,y,z (timestamp seconds); labels.csv: timestamp,label;
    gps.csv: timestamp,latitude,longitude,speed_mps.  GPS speed may be omitted;
    it is then calculated from consecutive coordinates.
    """
    accel = pd.read_csv(session_dir / "accel.csv")
    gps = pd.read_csv(session_dir / "gps.csv")
    labels = pd.read_csv(session_dir / "labels.csv")
    required_accel = {"timestamp", "x", "y", "z"}
    if not required_accel.issubset(accel.columns) or not {"timestamp", "label"}.issubset(labels.columns):
        raise ValueError(f"{session_dir}: canonical CSV columns are missing")
    accel = accel.sort_values("timestamp")
    gps = gps.sort_values("timestamp")
    if "speed_mps" not in gps:
        gps["speed_mps"] = _coordinate_speed(gps)
    start = np.ceil(accel.timestamp.min() / WINDOW_SECONDS) * WINDOW_SECONDS
    end = accel.timestamp.max()
    records: list[dict[str, object]] = []
    for window_start in np.arange(start, end - WINDOW_SECONDS + 1e-9, WINDOW_SECONDS):
        window_end = window_start + WINDOW_SECONDS
        a = accel[(accel.timestamp >= window_start) & (accel.timestamp < window_end)]
        # 80% protects FFT features from partial/missing windows.
        if len(a) < ACCEL_SAMPLE_HZ * WINDOW_SECONDS * .8:
            continue
        raw_labels = labels[(labels.timestamp >= window_start) & (labels.timestamp < window_end)].label
        label_values = raw_labels.map(map_label).dropna()
        if label_values.empty:
            continue
        label = label_values.mode().iat[0]
        vehicle_values = raw_labels.map(vehicle_label).dropna()
        g = gps[(gps.timestamp >= window_start) & (gps.timestamp < window_end)]
        speed_kmh = (g.speed_mps * 3.6).to_numpy() if not g.empty else np.array([0.0])
        magnitude = np.sqrt(a.x.to_numpy() ** 2 + a.y.to_numpy() ** 2 + a.z.to_numpy() ** 2)
        jerk = np.diff(magnitude) * ACCEL_SAMPLE_HZ
        # Stop-frequency proxy: count low-motion runs separated by active motion.
        low_motion = magnitude < np.percentile(magnitude, 25)
        stop_transitions = int(np.count_nonzero(np.diff(low_motion.astype(int)) == 1))
        records.append({
            "user": user, "session": session_dir.name, "window_start": window_start, "label": label, "vehicle_label": vehicle_values.mode().iat[0] if not vehicle_values.empty else None,
            "avg_speed_kmh": float(speed_kmh.mean()), "speed_variance_kmh2": float(speed_kmh.var()),
            "max_speed_kmh": float(speed_kmh.max()),
            # Trapezoidal integration makes this correct even if GPS is not 1 Hz.
            "distance_m": _distance_from_speed(g),
            "accel_magnitude_mean": float(magnitude.mean()), "accel_magnitude_variance": float(magnitude.var()),
            "accel_dominant_frequency_hz": dominant_frequency(magnitude, ACCEL_SAMPLE_HZ),
            "jerk_magnitude_mean": float(np.abs(jerk).mean()) if len(jerk) else 0.0,
            "jerk_magnitude_variance": float(jerk.var()) if len(jerk) else 0.0,
            "stop_transition_count": stop_transitions,
            "motion_consistency": float(1 / (1 + magnitude.var())),
            "rule_based_label": rule_speed_label(float(speed_kmh.mean())),
        })
    return records


def _coordinate_speed(gps: pd.DataFrame) -> pd.Series:
    """Fallback 1 Hz coordinate-derived speed in m/s (Haversine distance)."""
    if not {"latitude", "longitude"}.issubset(gps.columns):
        raise ValueError("gps.csv needs speed_mps or latitude and longitude")
    lat, lon = np.radians(gps.latitude), np.radians(gps.longitude)
    dlat, dlon = lat.diff(), lon.diff()
    h = np.sin(dlat / 2) ** 2 + np.cos(lat) * np.cos(lat.shift()) * np.sin(dlon / 2) ** 2
    metres = 2 * 6_371_000 * np.arctan2(np.sqrt(h), np.sqrt(1 - h))
    return (metres / gps.timestamp.diff()).replace([np.inf, -np.inf], np.nan).fillna(0)


def _distance_from_speed(gps: pd.DataFrame) -> float:
    if len(gps) < 2:
        return 0.0
    return float(np.trapz(gps.speed_mps.to_numpy(), gps.timestamp.to_numpy()))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("data/canonical"))
    parser.add_argument("--output", type=Path, default=Path("data/processed/shl_features.csv"))
    args = parser.parse_args()
    # Layout is canonical/<user>/<session>/{accel,gps,labels}.csv.
    sessions = sorted(path for path in args.input.glob("*/*") if (path / "accel.csv").exists())
    if not sessions:
        raise SystemExit("No canonical sessions found; see README's official-SHL adapter contract.")
    rows = [row for session in sessions for row in _feature_session(session, session.parent.name)]
    frame = pd.DataFrame(rows)
    if frame.empty:
        raise SystemExit("No complete labelled windows were produced.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    frame.to_csv(args.output, index=False)
    print(f"Wrote {len(frame)} windows to {args.output}")


if __name__ == "__main__":
    main()
