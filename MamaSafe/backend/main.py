from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, validator
from fastapi.middleware.cors import CORSMiddleware
import joblib
import os
import numpy as np
from supabase import create_client, Client
from dotenv import load_dotenv
import json
from fastapi import Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError

app = FastAPI()

# Exception handler for validation errors
@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    error_details = exc.errors()
    print(f"❌ Validation error: {error_details}")
    return JSONResponse(status_code=400, content={"detail": error_details})

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "HEAD", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Load environment variables
load_dotenv()

# Fallback to hardcoded values if .env not found (for local testing)
SUPABASE_URL = os.getenv("SUPABASE_URL") or "https://ntyqznoigmjsymenundu.supabase.co"
SUPABASE_KEY = os.getenv("SUPABASE_KEY") or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im50eXF6bm9pZ21qc3ltZW51bmR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwMTY2MDYsImV4cCI6MjA3NTU5MjYwNn0.oIDPZDy_4gaY05XfMpLiQCXJrKYL7RUHc450zBU__fk"

print(f"🔑 Supabase URL: {SUPABASE_URL[:20]}..." if SUPABASE_URL else "⚠️ No SUPABASE_URL")
print(f"🔑 Supabase Key: {SUPABASE_KEY[:20]}..." if SUPABASE_KEY else "⚠️ No SUPABASE_KEY")

# Initialize Supabase
supabase = None
try:
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("Missing SUPABASE_URL or SUPABASE_KEY")
    
    os.environ['HTTP_PROXY'] = ''
    os.environ['HTTPS_PROXY'] = ''
    
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    # Test connection
    response = supabase.table("predictions").select("count").limit(1).execute()
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

# Define input model with validation
class PredictionInput(BaseModel):
    age: float
    blood_pressure_systolic: float
    blood_pressure_diastolic: float
    blood_glucose: float
    patient_id: str = "placeholder_patient_id"
    
    # Add validation
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
        probabilities = model.predict_proba(features)[0] if hasattr(model, 'predict_proba') else [0.5, 0.5]
        probability = probabilities[1]  # Probability of positive class
        
        print(f"🎯 Model prediction: {prediction[0]}")
        print(f"📈 Probabilities: {probabilities}")
        
        # Determine risk level
        is_high_risk = bool(prediction[0])
        risk_level = "High Risk" if is_high_risk else "Low Risk"
        risk_percentage = float(probability * 100)
        confidence = float(probability * 100)
        
        # Generate recommendations based on risk level and input values
        recommendations_list = []
        risk_factors_list = []
        
        if is_high_risk:
            recommendations_list.append("⚠️ Consult with an endocrinologist immediately")
            recommendations_list.append("📊 Monitor blood glucose levels daily")
            recommendations_list.append("🥗 Follow a strict diabetic diet plan")
            recommendations_list.append("💊 Medication may be required - consult your doctor")
            
            # Identify specific risk factors
            if input_data.blood_glucose > 140:
                risk_factors_list.append(f"Elevated blood glucose: {input_data.blood_glucose} mg/dL (Normal: 70-100)")
            if input_data.blood_pressure_systolic > 130:
                risk_factors_list.append(f"High systolic BP: {input_data.blood_pressure_systolic} mmHg (Normal: 90-120)")
            if input_data.blood_pressure_diastolic > 85:
                risk_factors_list.append(f"High diastolic BP: {input_data.blood_pressure_diastolic} mmHg (Normal: 60-80)")
            if input_data.age > 35:
                risk_factors_list.append(f"Maternal age: {input_data.age} years (Higher risk after 35)")
        else:
            recommendations_list.append("✅ Continue regular prenatal care")
            recommendations_list.append("🥗 Maintain a balanced, healthy diet")
            recommendations_list.append("🏃‍♀️ Regular light exercise (30 min daily)")
            recommendations_list.append("📊 Monitor blood sugar periodically")
            
            risk_factors_list.append("No significant risk factors detected")
        
        # Format for display (newline-separated for Flutter)
        recommendations_text = "\n".join([f"{rec}" for rec in recommendations_list])
        risk_factors_text = "\n".join([f"{factor}" for factor in risk_factors_list])
        
        print(f"💬 Recommendations: {recommendations_text}")
        print(f"💬 Risk Factors: {risk_factors_text}")
        
        # Save to Supabase
        supabase_success = False
        if supabase is not None:
            try:
                supabase_data = {
                    'patient_id': input_data.patient_id,
                    'health_data_id': f"gdm_{input_data.patient_id}_{int(input_data.age)}",
                    'risk_level': risk_level,
                    'risk_percentage': round(risk_percentage, 2),
                    'confidence': round(confidence, 2),
                    'factors': risk_factors_text,  # Plain text, not JSON
                    'recommendations': recommendations_text  # Plain text, not JSON
                }
                
                print(f"💾 Attempting to save to Supabase...")
                print(f"💾 Data to insert: {supabase_data}")
                
                response = supabase.table('predictions').insert(supabase_data).execute()
                
                print(f"✅ Supabase insert SUCCESS!")
                print(f"✅ Response data: {response.data}")
                print(f"✅ Response count: {len(response.data) if response.data else 0}")
                supabase_success = True
                
            except Exception as supabase_error:
                print(f"❌ Supabase insert FAILED!")
                print(f"❌ Error: {supabase_error}")
                print(f"❌ Error type: {type(supabase_error).__name__}")
                import traceback
                print(f"❌ Full traceback:\n{traceback.format_exc()}")
                # Don't fail the request if Supabase fails
        else:
            print("⚠️ Supabase client is None - skipping database insert")
        
        # Return prediction result (this goes to Flutter)
        return {
            "prediction": is_high_risk,
            "probability": round(probability * 100, 1),
            "message": "⚠️ High Risk of GDM Detected" if is_high_risk else "✅ Low Risk of GDM",
            "risk_level": risk_level,
            "risk_percentage": round(risk_percentage, 1),
            "confidence": round(confidence, 1),
            "recommendations": recommendations_text,  # Send as text to Flutter
            "risk_factors": risk_factors_text,  # Send as text to Flutter
            "supabase_saved": supabase_success  # For debugging
        }
        
    except Exception as e:
        print(f"⚠️ Prediction error: {e}")
        print(f"⚠️ Error type: {type(e).__name__}")
        import traceback
        print(f"⚠️ Traceback:\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

# Handle HEAD requests
@app.head("/api/predict")
async def predict_head():
    return JSONResponse(content={}, status_code=200)