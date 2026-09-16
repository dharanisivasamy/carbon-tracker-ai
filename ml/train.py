"""Train small explainable classifiers and compare them to the speed rule."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, f1_score
from sklearn.model_selection import GroupShuffleSplit
from sklearn.tree import DecisionTreeClassifier

FEATURES = [
    "avg_speed_kmh", "speed_variance_kmh2", "max_speed_kmh", "distance_m",
    "accel_magnitude_mean", "accel_magnitude_variance", "accel_dominant_frequency_hz",
]
CLASSES = ["stationary", "walking", "cycling", "vehicle"]


def score(name: str, truth: pd.Series, predicted: pd.Series) -> dict:
    return {
        "name": name,
        "accuracy": accuracy_score(truth, predicted),
        "macro_f1": f1_score(truth, predicted, labels=CLASSES, average="macro", zero_division=0),
        "per_class": classification_report(truth, predicted, labels=CLASSES, output_dict=True, zero_division=0),
        "confusion_matrix": confusion_matrix(truth, predicted, labels=CLASSES).tolist(),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--features", type=Path, default=Path("data/processed/shl_features.csv"))
    parser.add_argument("--output-dir", type=Path, default=Path("artifacts"))
    parser.add_argument("--test-size", type=float, default=.25)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    frame = pd.read_csv(args.features).dropna(subset=FEATURES + ["label", "user"])
    if frame.user.nunique() < 2:
        raise SystemExit("Need at least two SHL users: user-group split prevents same-user window leakage.")
    # Judgment call: hold out whole users, which is stricter and more honest than
    # random window splitting. With three SHL participants this is a small test set.
    splitter = GroupShuffleSplit(n_splits=1, test_size=args.test_size, random_state=args.seed)
    train_idx, test_idx = next(splitter.split(frame, groups=frame.user))
    train, test = frame.iloc[train_idx], frame.iloc[test_idx]
    models = {
        "decision_tree": DecisionTreeClassifier(max_depth=12, min_samples_leaf=10, class_weight="balanced", random_state=args.seed),
        "random_forest": RandomForestClassifier(n_estimators=200, max_depth=16, min_samples_leaf=5, class_weight="balanced", n_jobs=-1, random_state=args.seed),
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    results = {"classes": CLASSES, "split": {"train_users": sorted(train.user.unique()), "test_users": sorted(test.user.unique()), "test_size": args.test_size}}
    for name, model in models.items():
        model.fit(train[FEATURES], train.label)
        joblib.dump({"model": model, "features": FEATURES, "classes": CLASSES}, args.output_dir / f"{name}.joblib")
        results[name] = score(name, test.label, model.predict(test[FEATURES]))
    results["rule_based_speed_baseline"] = score("rule_based_speed_baseline", test.label, test.rule_based_label)
    (args.output_dir / "metrics.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    summary = pd.DataFrame({key: {"accuracy": value["accuracy"], "macro_f1": value["macro_f1"]} for key, value in results.items() if isinstance(value, dict) and "accuracy" in value}).T
    summary.to_csv(args.output_dir / "metrics_summary.csv")
    print(summary.round(4).to_string())
    print(f"\nWrote models and confusion matrices/metrics to {args.output_dir}")
    for name in ("decision_tree", "random_forest"):
        f1 = results[name]["macro_f1"] * 100
        print(f"{name}: {f1:.1f}% macro F1; published reference points: Wang & Jiang 86.4%, Alecci et al. 84.5%.")
    print("Do not treat those papers as directly comparable: this pipeline uses four collapsed classes, a participant-held-out split, and modest classical models.")


if __name__ == "__main__":
    main()
