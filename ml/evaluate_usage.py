"""Create Objective-5 metrics from exported JSON/CSV trip evaluation events."""
import argparse
import json
from pathlib import Path
import pandas as pd

FACTORS={'walking':0,'cycling':0,'vehicle':.21}

def main():
    p=argparse.ArgumentParser(); p.add_argument('input',type=Path); p.add_argument('--output',type=Path,default=Path('artifacts/usage_evaluation.csv')); a=p.parse_args()
    raw=json.loads(a.input.read_text()) if a.input.suffix=='.json' else pd.read_csv(a.input).to_dict('records')
    df=pd.DataFrame(raw)
    required={'method','initial_label','confirmed_label','distance_km','entry_seconds','taps','detection_latency_ms','battery_estimate_mah'}
    missing=required-set(df.columns)
    if missing: raise SystemExit(f'Missing fields: {sorted(missing)}')
    df['correct']=df.initial_label==df.confirmed_label
    df['carbon_error_kg']=(df.initial_label.map(FACTORS).fillna(.21)-df.confirmed_label.map(FACTORS).fillna(.21)).abs()*df.distance_km
    result=df.groupby('method').agg(sample_size=('method','size'),classification_accuracy=('correct','mean'),mean_absolute_carbon_error_kg=('carbon_error_kg','mean'),average_taps=('taps','mean'),average_entry_seconds=('entry_seconds','mean'),average_detection_latency_ms=('detection_latency_ms','mean'),average_battery_estimate_mah=('battery_estimate_mah','mean')).reset_index()
    result['limitation']=result.sample_size.map(lambda n:'SMALL SAMPLE — descriptive only' if n<30 else '')
    a.output.parent.mkdir(parents=True,exist_ok=True); result.to_csv(a.output,index=False); print(result.round(3).to_string(index=False)); print(f'Wrote slide-ready table: {a.output}')
if __name__=='__main__': main()
