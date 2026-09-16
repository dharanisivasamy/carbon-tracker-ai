"""Experimental car/bus/train classifier; does not alter four-class Stage 1."""
import argparse, json
from pathlib import Path
import joblib, pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from sklearn.model_selection import GroupShuffleSplit

FEATURES=['accel_magnitude_mean','accel_magnitude_variance','accel_dominant_frequency_hz','jerk_magnitude_mean','jerk_magnitude_variance','stop_transition_count','motion_consistency','avg_speed_kmh','speed_variance_kmh2']
CLASSES=['car','bus','train']
def main():
 p=argparse.ArgumentParser();p.add_argument('--features',type=Path,default=Path('data/processed/shl_features.csv'));p.add_argument('--output-dir',type=Path,default=Path('artifacts'));a=p.parse_args()
 df=pd.read_csv(a.features).dropna(subset=FEATURES+['vehicle_label','user']);df=df[df.vehicle_label.isin(CLASSES)]
 if df.user.nunique()<2: raise SystemExit('Need two participants for leakage-safe Stage-2 evaluation.')
 tr,te=next(GroupShuffleSplit(n_splits=1,test_size=.25,random_state=42).split(df,groups=df.user));train,test=df.iloc[tr],df.iloc[te]
 model=RandomForestClassifier(n_estimators=150,max_depth=12,min_samples_leaf=8,class_weight='balanced',random_state=42,n_jobs=-1).fit(train[FEATURES],train.vehicle_label)
 pred=model.predict(test[FEATURES]);a.output_dir.mkdir(parents=True,exist_ok=True);joblib.dump({'model':model,'features':FEATURES,'classes':CLASSES},a.output_dir/'vehicle_stage2.joblib')
 metrics={'macro_f1':f1_score(test.vehicle_label,pred,labels=CLASSES,average='macro',zero_division=0),'report':classification_report(test.vehicle_label,pred,labels=CLASSES,output_dict=True,zero_division=0),'confusion_matrix':confusion_matrix(test.vehicle_label,pred,labels=CLASSES).tolist(),'test_users':sorted(test.user.unique())}
 (a.output_dir/'vehicle_stage2_metrics.json').write_text(json.dumps(metrics,indent=2));print(json.dumps(metrics,indent=2))
if __name__=='__main__':main()
