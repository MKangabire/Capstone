import os
from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime
import joblib
from supabase import create_client, Client

# ---------------------------------------------------------
# FASTAPI INITIALIZATION
# ---------------------------------------------------------

app = FastAPI(title="MamaSafe Prediction API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Adjust for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------
# LOAD ENVIRONMENT VARIABLES
# ---------------------------------------------------------

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_API_KEY")

supabase: Client = None

try:
    if SUPABASE_URL and SUPABASE_KEY:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("🔗 Connected to Supabase successfully!")
    else:
        print("❌ Missing Supabase environment variables!")
except Exception as e:
    print("❌ Failed to initialize Supabase:", str(e))

# ---------------------------------------------------------
# MODEL LOADING (Using joblib)
# ---------------------------------------------------------

model = None

try:
    base_path = Path(__file__).resolve().parent
    model_path = base_path / "xgboost_best_model.pkl"

    print("🔍 Searching for model at:", model_path)

    if model_path.exists():
        model = joblib.load(str(model_path))
        print("✅ Model loaded successfully!")
        print("   → Type:", type(model))
        print("   → Classes:", getattr(model, "classes_", "N/A"))

    else:
        print("⚠️ Model not found at main path. Trying alternative...")
        alt_path = Path(os.getcwd()) / "xgboost_best_model.pkl"
        print("🔍 Checking alternative path:", alt_path)

        if alt_path.exists():
            model = joblib.load(str(alt_path))
            print("✅ Model loaded from alternative path!")
        else:
            print("❌ Model not found in any known path!")

except Exception as e:
    print("❌ MODEL LOAD FAILED:", str(e))
    import traceback
    print(traceback.format_exc())

# ---------------------------------------------------------
# REQUEST BODY SCHEMA
# ---------------------------------------------------------

class PredictionInput(BaseModel):
    patient_id: str
    chw_id: str
    age: float
    bmi: float
    glucose: float
    insulin: float
    blood_pressure: float
    skin_thickness: float
    pregnancies: int

# ---------------------------------------------------------
# PREDICTION ENDPOINT
# ---------------------------------------------------------

@app.post("/api/predict")
async def create_prediction(input_data: PredictionInput):
    """Make a GDM prediction and save to Supabase."""

    if model is None:
        raise HTTPException(status_code=500, detail="Model is not loaded")

    if supabase is None:
        raise HTTPException(status_code=500, detail="Supabase connection failed")

    print(f"🔍 Prediction request received for patient: {input_data.patient_id}")

    try:
        features = [
            [
                input_data.age,
                input_data.bmi,
                input_data.glucose,
                input_data.insulin,
                input_data.blood_pressure,
                input_data.skin_thickness,
                input_data.pregnancies,
            ]
        ]

        prediction = model.predict(features)[0]

        if hasattr(model, "predict_proba"):
            probability = model.predict_proba(features)[0][1]  # Prob of class 1
        else:
            probability = float(prediction)

        risk_category = (
            "Low Risk" if probability < 0.4 
            else "Moderate Risk" if probability < 0.7 
            else "High Risk"
        )

        data_to_insert = {
            "patient_id": input_data.patient_id,
            "chw_id": input_data.chw_id,
            "prediction": int(prediction),
            "probability": float(probability),
            "risk_category": risk_category,
            "timestamp": datetime.utcnow().isoformat(),
        }

        response = supabase.table("predictions").insert(data_to_insert).execute()

        print("📌 Inserted prediction:", data_to_insert)

        return {
            "success": True,
            "prediction": int(prediction),
            "probability": probability,
            "risk_category": risk_category,
        }

    except Exception as e:
        print("❌ Prediction error:", str(e))
        raise HTTPException(status_code=500, detail=str(e))

# ---------------------------------------------------------
# GET ALL PREDICTIONS
# ---------------------------------------------------------

@app.get("/api/predictions")
async def get_all_predictions():
    if supabase is None:
        raise HTTPException(status_code=500, detail="Supabase connection failed")

    try:
        result = supabase.table("predictions").select("*").order("timestamp", desc=True).execute()
        return {"data": result.data}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ---------------------------------------------------------
# GET PREDICTIONS FOR SPECIFIC CHW
# ---------------------------------------------------------

@app.get("/api/predictions/{chw_id}")
async def get_predictions_by_chw(chw_id: str):
    if supabase is None:
        raise HTTPException(status_code=500, detail="Supabase connection failed")

    try:
        result = supabase.table("predictions").select("*").eq("chw_id", chw_id).execute()
        return {"data": result.data}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ---------------------------------------------------------
# ROOT
# ---------------------------------------------------------

@app.get("/")
def root():
    return {"message": "MamaSafe API is running"}

