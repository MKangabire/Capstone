from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, validator
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional, List
import joblib
import os
import numpy as np
from supabase import create_client, Client
from dotenv import load_dotenv
import traceback
from datetime import datetime

app = FastAPI(title="MamaSafe GDM Prediction API", version="1.0.0")

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Load Environment Variables
load_dotenv()
SUPABASE_URL = os.getenv("SUPABASE_URL") or "https://ntyqznoigmjsymenundu.supabase.co"
SUPABASE_KEY = os.getenv("SUPABASE_KEY") or "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im50eXF6bm9pZ21qc3ltZW51bmR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwMTY2MDYsImV4cCI6MjA3NTU5MjYwNn0.oIDPZDy_4gaY05XfMpLiQCXJrKYL7RUHc450zBU__fk"

print(f"🔑 Supabase URL: {SUPABASE_URL[:20]}...")
print(f"🔑 Supabase Key: {SUPABASE_KEY[:20]}...")

# Initialize Supabase
supabase = None
try:
    os.environ['HTTP_PROXY'] = ''
    os.environ['HTTPS_PROXY'] = ''
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    response = supabase.table("predictions").select("count").limit(1).execute()
    print(f"✅ Supabase connected!")
except Exception as e:
    print(f"❌ Supabase initialization failed: {e}")
    supabase = None

# Load ML Model
model_path = os.path.join(os.path.dirname(__file__), 'gdm_model.pkl')
try:
    model = joblib.load(model_path)
    print("✅ Model loaded successfully!")
except Exception as e:
    print(f"⚠️ Warning: Could not load model - {e}")
    model = None

# ==================== PYDANTIC MODELS ====================

class PredictionInput(BaseModel):
    age: float
    blood_pressure_systolic: float
    blood_pressure_diastolic: float
    blood_glucose: float
    patient_id: str
    
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

class NotificationCreate(BaseModel):
    chw_id: str
    patient_id: str
    message: str
    title: str
    notification_type: str = "high_risk_alert"

class PatientUpdate(BaseModel):
    full_name: Optional[str] = None
    age: Optional[int] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    phone: Optional[str] = None

# ==================== ROOT & HEALTH CHECK ====================

@app.get("/")
async def root():
    return {
        "message": "MamaSafe GDM Prediction API",
        "version": "1.0.0",
        "endpoints": {
            "prediction": "/api/predict",
            "health": "/api/health",
            "docs": "/docs"
        }
    }

@app.get("/api/health")
async def health_check():
    return {
        "status": "ok",
        "model_status": "loaded" if model is not None else "not loaded",
        "supabase_status": "connected" if supabase is not None else "failed",
        "timestamp": datetime.now().isoformat()
    }

# ==================== PREDICTION ENDPOINTS ====================

@app.post("/api/predict")
async def create_prediction(input_data: PredictionInput):
    """Make GDM prediction and save to database"""
    if model is None:
        raise HTTPException(status_code=500, detail="Model not loaded")
    
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        print(f"🔍 Received prediction request for patient: {input_data.patient_id}")
        
        # Prepare features for model
        features = np.array([[
            input_data.age,
            input_data.blood_pressure_systolic,
            input_data.blood_pressure_diastolic,
            input_data.blood_glucose
        ]])
        
        # Make prediction
        prediction = model.predict(features)
        probabilities = model.predict_proba(features)[0]
        probability = probabilities[1]
        
        print(f"🎯 Prediction: {prediction[0]}, Probability: {probability}")
        
        # Determine risk level
        is_high_risk = bool(prediction[0])
        risk_level = "High Risk" if is_high_risk else "Low Risk"
        risk_percentage = float(probability * 100)
        confidence = float(probability * 100)
        
        # Generate recommendations
        if is_high_risk:
            recommendations_list = [
                "⚠️ Consult with an endocrinologist immediately",
                "📊 Monitor blood glucose levels daily",
                "🥗 Follow a strict diabetic diet plan",
                "💊 Medication may be required - consult your doctor",
                "🏥 Schedule weekly check-ups"
            ]
            risk_factors_list = []
            if input_data.blood_glucose > 140:
                risk_factors_list.append(f"Elevated blood glucose: {input_data.blood_glucose} mg/dL")
            if input_data.blood_pressure_systolic > 130:
                risk_factors_list.append(f"High systolic BP: {input_data.blood_pressure_systolic} mmHg")
            if input_data.blood_pressure_diastolic > 85:
                risk_factors_list.append(f"High diastolic BP: {input_data.blood_pressure_diastolic} mmHg")
            if input_data.age > 35:
                risk_factors_list.append(f"Maternal age: {input_data.age} years")
            if not risk_factors_list:
                risk_factors_list.append("Multiple risk factors detected")
        else:
            recommendations_list = [
                "✅ Continue regular prenatal care",
                "🥗 Maintain a balanced, healthy diet",
                "🏃‍♀️ Regular light exercise (30 min daily)",
                "📊 Monitor blood sugar periodically",
                "💧 Stay well hydrated"
            ]
            risk_factors_list = ["No significant risk factors detected"]
        
        recommendations_text = "\n".join(recommendations_list)
        risk_factors_text = "\n".join(risk_factors_list)
        
        # Save to Supabase
        supabase_data = {
            'patient_id': input_data.patient_id,
            'health_data_id': f"gdm_{input_data.patient_id}_{int(datetime.now().timestamp())}",
            'risk_level': risk_level,
            'risk_percentage': round(risk_percentage, 2),
            'confidence': round(confidence, 2),
            'factors': risk_factors_text,
            'recommendations': recommendations_text
        }
        
        print(f"💾 Saving to Supabase...")
        response = supabase.table('predictions').insert(supabase_data).execute()
        print(f"✅ Saved successfully!")
        
        # If high risk, create notification for CHW
        if is_high_risk:
            try:
                # Get patient's assigned CHW
                chw_response = supabase.table('patients').select('chw_id').eq('id', input_data.patient_id).execute()
                if chw_response.data and chw_response.data[0].get('chw_id'):
                    chw_id = chw_response.data[0]['chw_id']
                    notification_data = {
                        'chw_id': chw_id,
                        'patient_id': input_data.patient_id,
                        'title': '🚨 High Risk GDM Alert',
                        'message': f'Patient has been identified as high risk for GDM. Risk: {round(risk_percentage, 1)}%',
                        'notification_type': 'high_risk_alert',
                        'is_read': False
                    }
                    supabase.table('notifications').insert(notification_data).execute()
                    print(f"📢 Notification sent to CHW: {chw_id}")
            except Exception as notif_error:
                print(f"⚠️ Notification failed: {notif_error}")
        
        return {
            "success": True,
            "prediction": is_high_risk,
            "probability": round(probability * 100, 1),
            "message": "⚠️ High Risk of GDM Detected" if is_high_risk else "✅ Low Risk of GDM",
            "risk_level": risk_level,
            "risk_percentage": round(risk_percentage, 1),
            "confidence": round(confidence, 1),
            "recommendations": recommendations_text,
            "risk_factors": risk_factors_text,
            "prediction_id": response.data[0]['id'] if response.data else None
        }
        
    except Exception as e:
        print(f"❌ Prediction error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

@app.get("/api/predictions/{patient_id}")
async def get_patient_predictions(patient_id: str, limit: int = 10):
    """Get all predictions for a patient"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        response = supabase.table('predictions')\
            .select('*')\
            .eq('patient_id', patient_id)\
            .order('created_at', desc=True)\
            .limit(limit)\
            .execute()
        
        return {
            "success": True,
            "count": len(response.data),
            "predictions": response.data
        }
    except Exception as e:
        print(f"❌ Error fetching predictions: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/predictions/latest/{patient_id}")
async def get_latest_prediction(patient_id: str):
    """Get the most recent prediction for a patient"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        response = supabase.table('predictions')\
            .select('*')\
            .eq('patient_id', patient_id)\
            .order('created_at', desc=True)\
            .limit(1)\
            .execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="No predictions found")
        
        return {
            "success": True,
            "prediction": response.data[0]
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching latest prediction: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== PATIENT ENDPOINTS ====================

@app.get("/api/patients/{patient_id}")
async def get_patient(patient_id: str):
    """Get patient profile details"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        response = supabase.table('patients')\
            .select('*, chw:chw_id(id, full_name, phone)')\
            .eq('id', patient_id)\
            .single()\
            .execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Patient not found")
        
        return {
            "success": True,
            "patient": response.data
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching patient: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/patients/{patient_id}")
async def update_patient(patient_id: str, update_data: PatientUpdate):
    """Update patient profile"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        # Filter out None values
        data_dict = {k: v for k, v in update_data.dict().items() if v is not None}
        
        if not data_dict:
            raise HTTPException(status_code=400, detail="No data to update")
        
        # Calculate BMI if height and weight provided
        if 'height' in data_dict and 'weight' in data_dict:
            height_m = data_dict['height'] / 100
            data_dict['bmi'] = round(data_dict['weight'] / (height_m ** 2), 2)
        
        response = supabase.table('patients')\
            .update(data_dict)\
            .eq('id', patient_id)\
            .execute()
        
        return {
            "success": True,
            "message": "Patient updated successfully",
            "patient": response.data[0] if response.data else None
        }
    except Exception as e:
        print(f"❌ Error updating patient: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/patients/{patient_id}/health-data")
async def get_patient_health_data(patient_id: str):
    """Get patient's health data history"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        response = supabase.table('health_data')\
            .select('*')\
            .eq('patient_id', patient_id)\
            .order('created_at', desc=True)\
            .execute()
        
        return {
            "success": True,
            "count": len(response.data),
            "health_data": response.data
        }
    except Exception as e:
        print(f"❌ Error fetching health data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== CHW ENDPOINTS ====================

@app.get("/api/chw/{chw_id}")
async def get_chw_details(chw_id: str):
    """Get Community Health Worker details"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        response = supabase.table('chw')\
            .select('*')\
            .eq('id', chw_id)\
            .single()\
            .execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="CHW not found")
        
        return {
            "success": True,
            "chw": response.data
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching CHW: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/chw/patients/{chw_id}")
async def get_chw_patients(chw_id: str):
    """Get all patients assigned to a CHW"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        response = supabase.table('patients')\
            .select('*')\
            .eq('chw_id', chw_id)\
            .execute()
        
        return {
            "success": True,
            "count": len(response.data),
            "patients": response.data
        }
    except Exception as e:
        print(f"❌ Error fetching CHW patients: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/chw/{chw_id}/assign-patient")
async def assign_patient_to_chw(chw_id: str, patient_id: str):
    """Assign a patient to a CHW"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        response = supabase.table('patients')\
            .update({'chw_id': chw_id})\
            .eq('id', patient_id)\
            .execute()
        
        return {
            "success": True,
            "message": "Patient assigned successfully"
        }
    except Exception as e:
        print(f"❌ Error assigning patient: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== NOTIFICATION ENDPOINTS ====================

@app.post("/api/notifications/send")
async def send_notification(notification: NotificationCreate):
    """Send notification to CHW"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        data = {
            'chw_id': notification.chw_id,
            'patient_id': notification.patient_id,
            'title': notification.title,
            'message': notification.message,
            'notification_type': notification.notification_type,
            'is_read': False
        }
        
        response = supabase.table('notifications').insert(data).execute()
        
        return {
            "success": True,
            "message": "Notification sent successfully",
            "notification_id": response.data[0]['id'] if response.data else None
        }
    except Exception as e:
        print(f"❌ Error sending notification: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/notifications/{chw_id}")
async def get_chw_notifications(chw_id: str, unread_only: bool = False):
    """Get all notifications for a CHW"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        query = supabase.table('notifications')\
            .select('*, patient:patient_id(full_name)')\
            .eq('chw_id', chw_id)\
            .order('created_at', desc=True)
        
        if unread_only:
            query = query.eq('is_read', False)
        
        response = query.execute()
        
        return {
            "success": True,
            "count": len(response.data),
            "unread_count": len([n for n in response.data if not n.get('is_read', True)]),
            "notifications": response.data
        }
    except Exception as e:
        print(f"❌ Error fetching notifications: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/notifications/{notification_id}/mark-read")
async def mark_notification_read(notification_id: str):
    """Mark notification as read"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        response = supabase.table('notifications')\
            .update({'is_read': True})\
            .eq('id', notification_id)\
            .execute()
        
        return {
            "success": True,
            "message": "Notification marked as read"
        }
    except Exception as e:
        print(f"❌ Error updating notification: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== HEAD REQUEST SUPPORT ====================

@app.head("/api/predict")
async def predict_head():
    return {"status": "ok"}