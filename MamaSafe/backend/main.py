from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import joblib
import os
import numpy as np
from supabase import create_client, Client
from dotenv import load_dotenv
import json

app = FastAPI()

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "HEAD", "OPTIONS"],
    allow_headers=["*"],
)

# Load environment variables
load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

print(f"🔑 Supabase URL: {SUPABASE_URL[:20]}...")
print(f"🔑 Supabase Key: {SUPABASE_KEY[:20]}...")

# ✅ ULTRA-SIMPLE SUPABASE INIT (Works on ALL versions)
supabase = None
try:
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("Missing SUPABASE_URL or SUPABASE_KEY")
    
    # ✅ Disable proxy environment variables (fixes 'proxy' bug)
    os.environ['HTTP_PROXY'] = ''
    os.environ['HTTPS_PROXY'] = ''
    
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # ✅ Test connection
    response = supabase.table("predictions").select("count").execute()
    print(f"✅ Supabase connected! Response: {response}")
    
except Exception as e:
    print(f"❌ Supabase initialization failed: {e}")
    supabase = None

# Load the model
model_path = os.path.join(os.path.dirname(__file__), 'gdm_model.pkl')
try:
    model = joblib.load(model_path)
    print("✅ Model loaded successfully!")
    print(f"📊 Model type: {type(model)}")
except Exception as e:
    print(f"⚠️ Warning: Could not load model - {e}")
    model = None

# Define input model
class PredictionInput(BaseModel):
    age: float
    blood_pressure_systolic: float
    blood_pressure_diastolic: float
    blood_glucose: float
    patient_id: str = "placeholder_patient_id"

# Root endpoint
@app.get("/")
async def root():
    return {"message": "MamaSafe GDM Prediction API", "endpoint": "/api/predict"}

@app.post("/")
async def root_post():
    raise HTTPException(status_code=405, detail="Use POST /api/predict for predictions")

# Health check endpoint
@app.get("/api/health")
async def health_check():
    return {
        "status": "ok",
        "model_status": "loaded" if model is not None else "not loaded",
        "supabase_status": "connected" if supabase is not None else "failed",
        "features": ["Age", "Blood Pressure Systolic", "Blood Pressure Diastolic", "Blood Glucose"],
        "expected_features": 4
    }

# Prediction endpoint
@app.post("/api/predict")
@app.head("/api/predict")
async def predict(input_data: PredictionInput):
    if model is None:
        raise HTTPException(status_code=500, detail="Model not loaded")
    
    try:
        print(f"🔍 Received input data: {input_data.dict()}")
        # Prepare input data
        features = np.array([[
            input_data.age,
            input_data.blood_pressure_systolic,
            input_data.blood_pressure_diastolic,
            input_data.blood_glucose
        ]])
        print(f"📊 Input features: {features}")
        print(f"📊 Input features shape: {features.shape}")
        
        # Make prediction
        prediction = model.predict(features)
        probability = model.predict_proba(features)[0][1] if hasattr(model, 'predict_proba') else None
        print(f"🎯 Model prediction: {prediction[0]}")
        print(f"📈 Probabilities: {model.predict_proba(features)[0]}")
        
        # Map to YOUR Supabase table columns
        risk_level = "High Risk" if prediction[0] else "Low Risk"
        risk_percentage = float(probability) if probability is not None else 0.5
        confidence = float(probability) if probability is not None else 0.5
        
        # Create factors and recommendations as JSON
        factors = {
            "age": input_data.age,
            "blood_pressure_systolic": input_data.blood_pressure_systolic,
            "blood_pressure_diastolic": input_data.blood_pressure_diastolic,
            "blood_glucose": input_data.blood_glucose
        }
        recommendations = [
            "Regular blood glucose monitoring" if prediction[0] else "Continue routine prenatal care",
            "Consult endocrinologist immediately" if prediction[0] else "Maintain healthy diet",
            "Dietary modifications required" if prediction[0] else "Regular exercise"
        ]
        
        supabase_data = {
            'patient_id': input_data.patient_id,
            'health_data_id': f"gdm_{input_data.patient_id}_{int(input_data.age)}",
            'risk_level': risk_level,
            'risk_percentage': risk_percentage,
            'confidence': confidence,
            'factors': json.dumps(factors),
            'recommendations': json.dumps(recommendations)
        }
        print(f"💾 Supabase data: {supabase_data}")
        
        # Save to Supabase with detailed error handling
        if supabase is not None:
            try:
                print("🔄 Saving to Supabase predictions table...")
                response = supabase.table('predictions').insert(supabase_data).execute()
                print(f"✅ Supabase insert success: {response.data}")
            except Exception as supabase_error:
                print(f"❌ Supabase insert failed: {supabase_error}")
        else:
            print("⚠️ Supabase client not available - skipping insert")
        
        # Return prediction result
        return {
            "prediction": bool(prediction[0]),
            "probability": float(probability) if probability is not None else None,
            "message": "High risk of GDM detected" if prediction[0] else "Low risk of GDM",
            "risk_level": risk_level,
            "risk_percentage": risk_percentage
        }
    except Exception as e:
        print(f"⚠️ Prediction error: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")