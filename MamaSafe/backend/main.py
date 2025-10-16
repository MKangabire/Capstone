from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, ValidationError, validator
from fastapi.middleware.cors import CORSMiddleware
import joblib
import os
import numpy as np
from supabase import create_client, Client
from dotenv import load_dotenv
import json
from fastapi import Request
from fastapi.responses import JSONResponse
import traceback

app = FastAPI()

@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    error_details = exc.errors()
    print(f"❌ Validation error: {error_details}")
    return JSONResponse(status_code=400, content={"detail": error_details})

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "HEAD", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL") or "https://ntyqznoigmjsymenundu.supabase.co"
SUPABASE_KEY = os.getenv("SUPABASE_KEY") or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im50eXF6bm9pZ21qc3ltZW51bmR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwMTY2MDYsImV4cCI6MjA3NTU5MjYwNn0.oIDPZDy_4gaY05XfMpLiQCXJrKYL7RUHc450zBU__fk"

print(f"🔑 Supabase URL: {SUPABASE_URL[:20]}...")
print(f"🔑 Supabase Key: {SUPABASE_KEY[:20]}...")

supabase = None
try:
    os.environ['HTTP_PROXY'] = ''
    os.environ['HTTPS_PROXY'] = ''
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    response = supabase.table("predictions").select("count").limit(1).execute()
    print(f"✅ Supabase connected! Response: {response}")
except Exception as e:
    print(f"❌ Supabase initialization failed: {e}")
    supabase = None

model_path = os.path.join(os.path.dirname(__file__), 'gdm_model.pkl')
try:
    model = joblib.load(model_path)
    print("✅ Model loaded successfully!")
    print(f"📊 Model type: {type(model)}")
except Exception as e:
    print(f"⚠️ Warning: Could not load model - {e}")
    model = None

class PredictionInput(BaseModel):
    age: float
    blood_pressure_systolic: float
    blood_pressure_diastolic: float
    blood_glucose: float
    patient_id: str = "placeholder_patient_id"
    
    @validator('age')
    def validate_age(cls, v):
        if v < 18 or v > 50:
            raise ValueError('Age must be between 18-50 years')
        return v
    
    @validator('blood_pressure_systolic')
    def validate_systolic(cls, v):
        if v < 80 or v > 200:
            raise ValueError('Systolic BP must be between 80-200 mmHg')
        return v
    
    @validator('blood_pressure_diastolic')
    def validate_diastolic(cls, v):
        if v < 40 or v > 130:
            raise ValueError('Diastolic BP must be between 40-130 mmHg')
        return v
    
    @validator('blood_glucose')
    def validate_glucose(cls, v):
        if v < 40 or v > 400:
            raise ValueError('Blood glucose must be between 40-400 mg/dL')
        return v

@app.get("/")
async def root():
    return {"message": "MamaSafe GDM Prediction API", "endpoint": "/api/predict"}

@app.get("/api/health")
async def health_check():
    return {
        "status": "ok",
        "model_status": "loaded" if model is not None else "not loaded",
        "supabase_status": "connected" if supabase is not None else "failed",
        "features": ["Age", "Blood Pressure Systolic", "Blood Pressure Diastolic", "Blood Glucose"],
        "expected_features": 4
    }

@app.post("/api/predict")
async def predict(input_data: PredictionInput):
    if model is None:
        raise HTTPException(status_code=500, detail="Model not loaded")
    
    try:
        print(f"🔍 Received input data: {input_data.dict()}")
        
        features = np.array([[
            input_data.age,
            input_data.blood_pressure_systolic,
            input_data.blood_pressure_diastolic,
            input_data.blood_glucose
        ]])
        print(f"📊 Input features: {features}")
        print(f"📊 Input features shape: {features.shape}")
        
        prediction = model.predict(features)
        probabilities = model.predict_proba(features)[0] if hasattr(model, 'predict_proba') else [0.5, 0.5]
        probability = probabilities[1]
        
        print(f"🎯 Model prediction: {prediction[0]}")
        print(f"📈 Probabilities: {probabilities}")
        
        is_high_risk = bool(prediction[0])
        risk_level = "High Risk" if is_high_risk else "Low Risk"
        risk_percentage = float(probability * 100)
        confidence = float(probability * 100)
        
        recommendations_list = []
        risk_factors_list = []
        
        if is_high_risk:
            recommendations_list.extend([
                "⚠️ Consult with an endocrinologist immediately",
                "📊 Monitor blood glucose levels daily",
                "🥗 Follow a strict diabetic diet plan",
                "💊 Medication may be required - consult your doctor"
            ])
            if input_data.blood_glucose > 140:
                risk_factors_list.append(f"Elevated blood glucose: {input_data.blood_glucose} mg/dL")
            if input_data.age > 35:
                risk_factors_list.append(f"Maternal age: {input_data.age} years")
        else:
            recommendations_list.extend([
                "✅ Continue regular prenatal care",
                "🥗 Maintain a balanced, healthy diet",
                "🏃‍♀️ Regular light exercise (30 min daily)",
                "📊 Monitor blood sugar periodically"
            ])
            risk_factors_list.append("No significant risk factors detected")
        
        recommendations_text = "\n".join([f"• {rec}" for rec in recommendations_list])
        risk_factors_text = "\n".join([f"• {factor}" for factor in risk_factors_list])
        
        # ✅ SUPABASE INSERT WITH FULL LOGGING
        print("💾 === STARTING SUPABASE INSERT ===")
        if supabase is not None:
            supabase_data = {
                'patient_id': input_data.patient_id,
                'health_data_id': f"gdm_{input_data.patient_id}_{int(input_data.age)}",
                'risk_level': risk_level,
                'risk_percentage': round(risk_percentage, 2),
                'confidence': round(confidence, 2),
                'factors': risk_factors_text,
                'recommendations': recommendations_text
            }
            
            print(f"💾 Data prepared: {supabase_data}")
            try:
                print("🔄 Executing insert...")
                response = supabase.table('predictions').insert(supabase_data).execute()
                print(f"✅ SUPABASE INSERT SUCCESS!")
                print(f"✅ Response: {response.data}")
            except Exception as supabase_error:
                print(f"❌ SUPABASE INSERT FAILED!")
                print(f"❌ Error: {supabase_error}")
                print(f"❌ Type: {type(supabase_error)}")
                print(f"❌ Traceback: {traceback.format_exc()}")
        else:
            print("⚠️ Supabase not available")
        print("💾 === END SUPABASE INSERT ===")
        
        return {
            "prediction": is_high_risk,
            "probability": round(probability * 100, 1),
            "message": "⚠️ High Risk of GDM Detected" if is_high_risk else "✅ Low Risk of GDM",
            "risk_level": risk_level,
            "risk_percentage": round(risk_percentage, 1),
            "confidence": round(confidence, 1),
            "recommendations": recommendations_text,
            "risk_factors": risk_factors_text
        }
        
    except Exception as e:
        print(f"⚠️ Prediction error: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

@app.head("/api/predict")
async def predict_head():
    return JSONResponse(content={}, status_code=200)