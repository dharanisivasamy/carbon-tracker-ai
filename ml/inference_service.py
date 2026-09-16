"""Independently deployable HTTP inference service for a trained SHL artifact."""
from __future__ import annotations

import os
from pathlib import Path

import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

MODEL_PATH = Path(os.getenv("ML_MODEL_PATH", "artifacts/random_forest.joblib"))
STAGE2_MODEL_PATH = Path(os.getenv("ML_STAGE2_MODEL_PATH", "artifacts/vehicle_stage2.joblib"))
STAGE2_CONFIDENCE_THRESHOLD = float(os.getenv("ML_STAGE2_CONFIDENCE_THRESHOLD", "0.70"))
app = FastAPI(title="Carbon Tracker ML inference", version="1.0")
_artifact: dict | None = None
_stage2_artifact: dict | None = None


class FeatureWindow(BaseModel):
    avg_speed_kmh: float = Field(ge=0)
    speed_variance_kmh2: float = Field(ge=0)
    max_speed_kmh: float = Field(ge=0)
    distance_m: float = Field(ge=0)
    accel_magnitude_mean: float = 0
    accel_magnitude_variance: float = Field(default=0, ge=0)
    accel_dominant_frequency_hz: float = Field(default=0, ge=0)
    jerk_magnitude_mean: float = Field(default=0, ge=0)
    jerk_magnitude_variance: float = Field(default=0, ge=0)
    stop_transition_count: float = Field(default=0, ge=0)
    motion_consistency: float = Field(default=0, ge=0)


def artifact() -> dict:
    global _artifact
    if _artifact is None:
        if not MODEL_PATH.is_file():
            raise HTTPException(503, f"Model artifact is unavailable: {MODEL_PATH}")
        loaded = joblib.load(MODEL_PATH)
        if not isinstance(loaded, dict) or "model" not in loaded or "features" not in loaded:
            raise HTTPException(500, "Model artifact has an unsupported format")
        _artifact = loaded
    return _artifact

def stage2_artifact() -> dict | None:
    global _stage2_artifact
    if not STAGE2_MODEL_PATH.is_file(): return None
    if _stage2_artifact is None: _stage2_artifact = joblib.load(STAGE2_MODEL_PATH)
    return _stage2_artifact


@app.get("/health")
def health() -> dict:
    return {"ok": MODEL_PATH.is_file(), "model_path": str(MODEL_PATH)}


@app.post("/classify")
def classify(window: FeatureWindow) -> dict:
    loaded = artifact()
    features = list(loaded["features"])
    values = window.model_dump()
    missing = [name for name in features if name not in values]
    if missing:
        raise HTTPException(422, f"Request does not contain model features: {missing}")
    row = pd.DataFrame([[values[name] for name in features]], columns=features)
    model = loaded["model"]
    predicted = str(model.predict(row)[0])
    confidence = float(max(model.predict_proba(row)[0])) if hasattr(model, "predict_proba") else None
    specific_label = None
    specific_confidence = None
    # Experimental opt-in: missing artifact/IMU-compatible features preserves
    # the stable four-class contract and returns generic vehicle.
    second = stage2_artifact() if predicted == "vehicle" else None
    if second is not None:
        stage2_row = pd.DataFrame([[values[name] for name in second["features"]]], columns=second["features"])
        candidate = str(second["model"].predict(stage2_row)[0])
        specific_confidence = float(max(second["model"].predict_proba(stage2_row)[0]))
        if specific_confidence >= STAGE2_CONFIDENCE_THRESHOLD: specific_label = candidate
    return {"predicted_class": predicted, "confidence": confidence, "specific_vehicle_label": specific_label, "specific_vehicle_confidence": specific_confidence}


# Run independently: ML_MODEL_PATH=artifacts/random_forest.joblib uvicorn inference_service:app --host 0.0.0.0 --port 8000
