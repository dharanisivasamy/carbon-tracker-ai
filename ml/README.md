# Review 2: SHL classical-ML pipeline

This folder is deliberately offline and has no Flutter, Node, MongoDB, or API dependency. It trains models for evaluation only; the Review-1 Dart speed rule remains the production fallback.

## Dataset and access

Use the official **Sussex-Huawei Locomotion (SHL) preview** dataset, not an unofficial mirror. It contains 59 labelled recording hours (227 phone-hours across four carry locations), with GPS/location plus accelerometer/IMU data. The full SHL collection is about 750 labelled hours and is impractical for a typical student laptop. SHL’s official portal may require registration and acceptance of its licence/terms; this is an intentional early blocker, not something this repository bypasses.

The University of Sussex description lists eight original labels: Still, Walk, Run, Bike, Car, Bus, Train, Subway. This project maps them to `stationary`, `walking` (Walk + Run), `cycling`, and `vehicle` (Car + Bus + Train + Subway). This is a judgment call matching Review 1, not a claim that vehicle types are distinguishable.

Official background: [Sussex dataset description](https://www.sussex.ac.uk/strc/research/wearable/locomotion-transportation) and [SHL challenge review](https://www.frontiersin.org/journals/computer-science/articles/10.3389/fcomp.2021.713719/full). The challenge review documents 100 Hz accelerometer/location modalities and 5-second frames; that is why this project uses non-overlapping **5-second** windows.

## Setup and official download

```powershell
cd ml
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
# Obtain the signed/direct link after registration from the official SHL portal.
python download_shl.py --url "<official-authorised-download-url>"
```

Extract the official archive under `data/raw/`. Archive layouts have changed between SHL preview/challenge releases, so convert it once into this explicit canonical layout (the adapter boundary):

```text
data/canonical/<participant>/<session>/accel.csv   # timestamp,x,y,z; seconds, m/s²
data/canonical/<participant>/<session>/gps.csv     # timestamp,latitude,longitude,speed_mps
data/canonical/<participant>/<session>/labels.csv  # timestamp,label (SHL 1–8 or label text)
```

The project does not guess proprietary/archive-specific column layouts. A small conversion script can be added once the exact registered archive is available; keeping the adapter explicit prevents silently misaligning labels, GPS, and 100 Hz IMU data.

## Run

```powershell
python prepare_features.py --input data/canonical --output data/processed/shl_features.csv
python train.py --features data/processed/shl_features.csv --output-dir artifacts
```

`shl_features.csv` has GPS average/variance/max speed and distance; acceleration-magnitude mean/variance and FFT dominant frequency; ground-truth four-class label; and the same-window Review-1 speed-rule prediction. The model split holds out complete **participants** (`GroupShuffleSplit`), never windows from the same user. This is conservative with SHL’s three participants and requires at least two users.

`artifacts/metrics.json` includes accuracy, class precision/recall/F1, macro F1, and numerical confusion matrices for Decision Tree, Random Forest, and rule baseline. `metrics_summary.csv` is the final metrics table. Metrics are intentionally **not fabricated** here: run against the licensed data before adding numbers to this README.

The printed comparison uses Wang & Jiang’s stated 86.4% F1 and Alecci et al.’s 84.5% F1 only as reference points. A lower result is expected to be plausible because this is a smaller subset, four collapsed labels, participant-held-out evaluation, and deliberately modest classical models—not their full experimental setup.

## Optional inference service

After training, serve the saved artifact independently of the Node API:

```powershell
$env:ML_MODEL_PATH = "artifacts/random_forest.joblib"
uvicorn inference_service:app --host 0.0.0.0 --port 8000
```

`POST /classify` accepts the seven feature names in `train.py` and returns
`predicted_class` plus `confidence`. Set `ML_INFERENCE_URL` in the backend to
the service address. The mobile build enables the proxy only with
`--dart-define=USE_ML_CLASSIFIER=true`; otherwise it stays fully rule based.
The Flutter app currently supplies GPS features and explicit zero IMU values
because it does not yet collect accelerometer windows. That is intentionally
logged and is not comparable to the fully multimodal offline score.

## Experimental vehicle Stage 2

`train_vehicle_stage2.py` filters original SHL `car`, `bus`, and `train`
windows and trains a separate participant-held-out Random Forest using the
existing acceleration features plus jerk magnitude, low-motion stop-transition
count, and a motion-consistency proxy. Run it after feature preparation:

```powershell
python train_vehicle_stage2.py
```

It writes `artifacts/vehicle_stage2.joblib` and a per-class report/confusion
matrix. No accuracy number is claimed until this is run on licensed SHL data.
The inference service returns the unchanged four-class `predicted_class` and,
only for a confident vehicle Stage-2 result, adds `specific_vehicle_label`.
The default threshold is 0.70. Keep this experimental flag off in the live
GPS-only app: it has no captured IMU readings yet, and bus/car stop-go traffic
plus phone-position variation are known hard cases. Existing backend emission
factors already distinguish car (0.21), bus (0.10), and train (0.04).
