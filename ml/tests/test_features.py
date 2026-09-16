from ml.prepare_features import map_label, rule_speed_label


def test_shl_labels_collapse_to_review_one_classes():
    assert map_label(1) == "stationary"
    assert map_label("Run") == "walking"
    assert map_label(4) == "cycling"
    assert map_label("Subway") == "vehicle"


def test_review_one_speed_baseline_thresholds():
    assert rule_speed_label(1.99) == "stationary"
    assert rule_speed_label(2) == "walking"
    assert rule_speed_label(7) == "cycling"
    assert rule_speed_label(20) == "cycling"
    assert rule_speed_label(20.01) == "vehicle"
