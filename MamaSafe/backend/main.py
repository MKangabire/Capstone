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

# Load ML Model (will use as fallback only)
model_path = os.path.join(os.path.dirname(__file__), 'xgboost_best_model.pkl')
model = None

try:
    if os.path.exists(model_path):
        model = joblib.load(model_path)
        print("✅ Model loaded (using as secondary reference)")
except Exception as e:
    print(f"⚠️ Model load failed: {e} - Using clinical rules only")

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

# ==================== CLINICAL RULES ENGINE ====================

def calculate_gdm_risk(input_data: PredictionInput) -> dict:
    """
    Calculate GDM risk using evidence-based clinical guidelines
    Based on WHO and ADA criteria for gestational diabetes
    """
    risk_score = 0
    risk_factors = []
    severity_level = "normal"
    
    # === BLOOD GLUCOSE (PRIMARY INDICATOR) ===
    # WHO/ADA GDM Diagnostic Criteria:
    # - Fasting: ≥92 mg/dL (5.1 mmol/L)
    # - 1-hour OGTT: ≥180 mg/dL (10.0 mmol/L)
    # - 2-hour OGTT: ≥153 mg/dL (8.5 mmol/L)
    # - Random: ≥200 mg/dL indicates diabetes
    
    glucose = input_data.blood_glucose
    
    if glucose >= 300:
        risk_score += 90
        severity_level = "critical"
        risk_factors.append(f"🚨 CRITICAL: Blood glucose {glucose} mg/dL - Emergency consultation required")
    elif glucose >= 200:
        risk_score += 75
        severity_level = "severe"
        risk_factors.append(f"⚠️ SEVERE: Blood glucose {glucose} mg/dL - Diabetic range, immediate medical attention")
    elif glucose >= 180:
        risk_score += 60
        severity_level = "high"
        risk_factors.append(f"⚠️ HIGH: Blood glucose {glucose} mg/dL - Exceeds 1-hour OGTT threshold")
    elif glucose >= 153:
        risk_score += 50
        severity_level = "high"
        risk_factors.append(f"⚠️ HIGH: Blood glucose {glucose} mg/dL - Exceeds 2-hour OGTT threshold")
    elif glucose >= 140:
        risk_score += 40
        severity_level = "moderate"
        risk_factors.append(f"⚠️ ELEVATED: Blood glucose {glucose} mg/dL - Prediabetic range")
    elif glucose >= 126:
        risk_score += 30
        severity_level = "moderate"
        risk_factors.append(f"⚠️ Elevated fasting glucose: {glucose} mg/dL")
    elif glucose >= 100:
        risk_score += 15
        risk_factors.append(f"Borderline glucose: {glucose} mg/dL - Monitor closely")
    elif glucose >= 92:
        risk_score += 10
        risk_factors.append(f"Fasting glucose at GDM threshold: {glucose} mg/dL")
    
    # === MATERNAL AGE ===
    age = input_data.age
    if age >= 40:
        risk_score += 20
        risk_factors.append(f"Advanced maternal age: {age} years (significantly increased risk)")
    elif age >= 35:
        risk_score += 15
        risk_factors.append(f"Maternal age ≥35: {age} years (increased risk)")
    elif age >= 30:
        risk_score += 8
        risk_factors.append(f"Maternal age: {age} years (moderate risk factor)")
    elif age < 20:
        risk_score += 5
        risk_factors.append(f"Young maternal age: {age} years")
    
    # === BLOOD PRESSURE (HYPERTENSION CORRELATION) ===
    systolic = input_data.blood_pressure_systolic
    diastolic = input_data.blood_pressure_diastolic
    
    # Hypertensive Crisis
    if systolic >= 180 or diastolic >= 120:
        risk_score += 25
        severity_level = "critical"
        risk_factors.append(f"🚨 Hypertensive crisis: {systolic}/{diastolic} mmHg - Emergency!")
    # Stage 2 Hypertension
    elif systolic >= 140 or diastolic >= 90:
        risk_score += 18
        risk_factors.append(f"Stage 2 hypertension: {systolic}/{diastolic} mmHg")
    # Stage 1 Hypertension
    elif systolic >= 130 or diastolic >= 85:
        risk_score += 12
        risk_factors.append(f"Stage 1 hypertension: {systolic}/{diastolic} mmHg")
    # Elevated BP
    elif systolic >= 120 or diastolic >= 80:
        risk_score += 6
        risk_factors.append(f"Elevated blood pressure: {systolic}/{diastolic} mmHg")
    
    # === COMBINED RISK FACTORS (MULTIPLICATIVE EFFECT) ===
    # High glucose + High BP = Higher risk
    if glucose >= 140 and (systolic >= 130 or diastolic >= 85):
        risk_score += 15
        risk_factors.append("Multiple risk factors: High glucose AND high blood pressure")
    
    # High glucose + Advanced age
    if glucose >= 140 and age >= 35:
        risk_score += 10
        risk_factors.append("Multiple risk factors: High glucose AND advanced maternal age")
    
    # Cap risk score at 100
    risk_score = min(risk_score, 100)
    
    # === DETERMINE RISK LEVEL ===
    if risk_score >= 70:
        risk_level = "Critical"
        is_high_risk = True
        confidence = 95
    elif risk_score >= 50:
        risk_level = "High"
        is_high_risk = True
        confidence = 85
    elif risk_score >= 30:
        risk_level = "Moderate"
        is_high_risk = True
        confidence = 70
    elif risk_score >= 15:
        risk_level = "Low-Moderate"
        is_high_risk = False
        confidence = 60
    else:
        risk_level = "Low"
        is_high_risk = False
        confidence = 55
    
    if not risk_factors:
        risk_factors.append("✅ No significant risk factors detected - All values within normal range")
    
    return {
        "risk_score": risk_score,
        "risk_level": risk_level,
        "is_high_risk": is_high_risk,
        "confidence": confidence,
        "risk_factors": risk_factors,
        "severity": severity_level
    }

# ==================== ROOT & HEALTH CHECK ====================

@app.get("/")
async def root():
    return {
        "message": "MamaSafe GDM Prediction API",
        "version": "2.0.0 (Clinical Rules Engine)",
        "endpoints": {
            "prediction": "/api/predict",
            "health": "/api/health",
            "docs": "/docs"
        },
        "note": "Using evidence-based clinical guidelines for accurate GDM risk assessment"
    }

@app.get("/api/health")
async def health_check():
    return {
        "status": "ok",
        "prediction_method": "clinical_rules_engine",
        "model_status": "loaded (secondary)" if model is not None else "not available",
        "supabase_status": "connected" if supabase is not None else "failed",
        "timestamp": datetime.now().isoformat()
    }

# ==================== PREDICTION ENDPOINTS ====================

@app.post("/api/predict")
async def create_prediction(input_data: PredictionInput):
    """Make GDM prediction using clinical rules engine"""
    
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        print(f"\n{'='*60}")
        print(f"🔍 NEW PREDICTION REQUEST")
        print(f"{'='*60}")
        print(f"Patient ID: {input_data.patient_id}")
        print(f"📊 Input Data:")
        print(f"   - Age: {input_data.age} years")
        print(f"   - Blood Pressure: {input_data.blood_pressure_systolic}/{input_data.blood_pressure_diastolic} mmHg")
        print(f"   - Blood Glucose: {input_data.blood_glucose} mg/dL")
        
        # Calculate risk using clinical rules
        risk_assessment = calculate_gdm_risk(input_data)
        
        print(f"\n📋 RISK ASSESSMENT:")
        print(f"   - Risk Score: {risk_assessment['risk_score']}/100")
        print(f"   - Risk Level: {risk_assessment['risk_level']}")
        print(f"   - High Risk: {risk_assessment['is_high_risk']}")
        print(f"   - Confidence: {risk_assessment['confidence']}%")
        print(f"   - Severity: {risk_assessment['severity']}")
        
        is_high_risk = risk_assessment['is_high_risk']
        risk_level = risk_assessment['risk_level']
        risk_percentage = risk_assessment['risk_score']
        confidence = risk_assessment['confidence']
        risk_factors_list = risk_assessment['risk_factors']
        
        # Generate recommendations based on risk level
        if risk_assessment['severity'] == "critical":
            recommendations_list = [
                "🚨 SEEK EMERGENCY MEDICAL ATTENTION IMMEDIATELY",
                "🏥 Go to the nearest hospital emergency department",
                "📞 Call emergency services if unable to travel",
                "⚠️ Do not delay - this is a medical emergency",
                "💉 Prepare for possible hospitalization and intensive monitoring"
            ]
        elif risk_assessment['severity'] == "severe" or risk_percentage >= 70:
            recommendations_list = [
                "⚠️ Schedule URGENT appointment with endocrinologist (within 24-48 hours)",
                "📊 Begin immediate blood glucose monitoring (4-6 times daily)",
                "🥗 Start strict diabetic diet immediately - consult nutritionist",
                "💊 Medication/insulin therapy likely required - DO NOT self-medicate",
                "🏥 Weekly medical check-ups mandatory",
                "📱 Keep emergency contact numbers ready",
                "⚖️ Monitor for symptoms: excessive thirst, frequent urination, fatigue"
            ]
        elif risk_percentage >= 50:
            recommendations_list = [
                "⚠️ Consult with endocrinologist within 1 week",
                "📊 Monitor blood glucose levels 3-4 times daily",
                "🥗 Follow diabetic diet plan - limit sugar and refined carbs",
                "🏃‍♀️ Light exercise (20-30 min daily walk after meals)",
                "💊 Medication may be needed - consult your doctor",
                "🏥 Bi-weekly prenatal check-ups",
                "📚 Attend GDM education sessions"
            ]
        elif risk_percentage >= 30:
            recommendations_list = [
                "📋 Discuss findings with your OB/GYN at next visit",
                "📊 Monitor blood glucose 2-3 times per week",
                "🥗 Adopt balanced diet - reduce sugar intake",
                "🏃‍♀️ Regular moderate exercise (30 min, 5 days/week)",
                "⚖️ Maintain healthy weight gain during pregnancy",
                "🏥 Regular prenatal care appointments",
                "📖 Learn about GDM warning signs"
            ]
        else:
            recommendations_list = [
                "✅ Continue regular prenatal care",
                "🥗 Maintain balanced, nutritious diet",
                "🏃‍♀️ Regular light exercise (30 min daily)",
                "📊 Routine glucose screening as scheduled",
                "💧 Stay well hydrated (8-10 glasses water daily)",
                "😴 Adequate rest and stress management",
                "📅 Attend all scheduled prenatal appointments"
            ]
        
        recommendations_text = "\n".join(recommendations_list)
        risk_factors_text = "\n".join(risk_factors_list)
        
        # Generate appropriate message
        if risk_assessment['severity'] == "critical":
            message = "🚨 CRITICAL RISK - SEEK EMERGENCY CARE IMMEDIATELY"
        elif risk_percentage >= 70:
            message = "⚠️ Very High Risk of GDM - Urgent Medical Attention Required"
        elif risk_percentage >= 50:
            message = "⚠️ High Risk of GDM Detected"
        elif risk_percentage >= 30:
            message = "⚠️ Moderate Risk of GDM - Medical Consultation Recommended"
        else:
            message = "✅ Low Risk of GDM"
        
        # Save to Supabase
        supabase_data = {
            'patient_id': input_data.patient_id,
            'risk_level': risk_level,
            'risk_percentage': round(risk_percentage, 2),
            'confidence': round(confidence, 2),
            'factors': risk_factors_text,
            'recommendations': recommendations_text
        }
        
        print(f"\n💾 Saving to Supabase...")
        response = supabase.table('predictions').insert(supabase_data).execute()
        print(f"✅ Saved successfully with ID: {response.data[0]['id'] if response.data else 'unknown'}")
        
        # Send notification for high-risk cases
        if is_high_risk:
            try:
                chw_response = supabase.table('profiles').select('region,chw_id').eq('id', input_data.patient_id).execute()
                if chw_response.data and chw_response.data[0].get('chw_id'):
                    chw_id = chw_response.data[0]['chw_id']
                    
                    urgency = "🚨 URGENT" if risk_percentage >= 70 else "⚠️ ALERT"
                    notification_data = {
                        'chw_id': chw_id,
                        'patient_id': input_data.patient_id,
                        'title': f'{urgency}: High Risk GDM Detection',
                        'message': f'Patient shows {risk_level.lower()} risk for GDM (Risk: {round(risk_percentage, 1)}%). Blood glucose: {input_data.blood_glucose} mg/dL. {" URGENT ACTION REQUIRED." if risk_percentage >= 70 else "Please follow up."}',
                        'notification_type': 'high_risk_alert',
                        'is_read': False
                    }
                    supabase.table('notifications').insert(notification_data).execute()
                    print(f"📢 Notification sent to CHW: {chw_id}")
            except Exception as notif_error:
                print(f"⚠️ Notification failed: {notif_error}")
        
        print(f"{'='*60}\n")
        
        return {
            "success": True,
            "prediction": is_high_risk,
            "probability": round(risk_percentage, 1),
            "message": message,
            "risk_level": risk_level,
            "risk_percentage": round(risk_percentage, 1),
            "confidence": round(confidence, 1),
            "recommendations": recommendations_text,
            "risk_factors": risk_factors_text,
            "prediction_id": response.data[0]['id'] if response.data else None,
            "severity": risk_assessment['severity'],
            "method": "clinical_rules_engine"
        }
        
    except Exception as e:
        print(f"❌ Prediction error: {e}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

# ==================== REMAINING ENDPOINTS (UNCHANGED) ====================

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

@app.get("/api/patients/{patient_id}")
async def get_patient(patient_id: str):
    """Get patient profile details"""
    if supabase is None:
        raise HTTPException(status_code=500, detail="Database connection failed")
    
    try:
        response = supabase.table('profiles')\
            .select('*')\
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
        data_dict = {k: v for k, v in update_data.dict().items() if v is not None}
        
        if not data_dict:
            raise HTTPException(status_code=422, detail="No data to update")
        
        if 'height' in data_dict and 'weight' in data_dict:
            height_m = data_dict['height'] / 100
            data_dict['bmi'] = round(data_dict['weight'] / (height_m ** 2), 2)
        
        response = supabase.table('profiles')\
            .update(data_dict)\
            .eq('id', patient_id)\
            .execute()
        
        return {
            "success": True,
            "message": "Patient updated successfully",
            "patient": response.data[0] if response.data else None
        }
    except HTTPException:
        raise
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
        response = supabase.table('profiles')\
            .select('*')\
            .eq('chw_id', chw_id)\
            .eq('role', 'patient')\
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
        response = supabase.table('profiles')\
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

@app.head("/api/predict")
async def predict_head():
    return {"status": "ok"}