# main.py - Fixed for 4 features model
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import numpy as np
from typing import Optional
import uvicorn

app = FastAPI(title="MamaSafe GDM Prediction API")

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load your trained model
try:
    model = joblib.load("gdm_model.pkl")
    print("✅ Model loaded successfully!")
    print(f"📊 Model type: {type(model)}")
except Exception as e:
    print(f"⚠️  Warning: Could not load model - {e}")
    model = None

class PredictionInput(BaseModel):
    """Input data for GDM prediction - 4 features only"""
    age: int
    blood_pressure_systolic: float
    blood_pressure_diastolic: float
    blood_glucose: float

class PredictionOutput(BaseModel):
    """Output data for GDM prediction"""
    risk_level: str
    risk_percentage: float
    confidence: float
    recommendations: list[str]
    factors: list[dict]

@app.get("/")
def read_root():
    """Health check endpoint"""
    model_status = "loaded" if model is not None else "not loaded"
    return {
        "status": "healthy",
        "message": "MamaSafe GDM API is running",
        "version": "1.0.0",
        "model_status": model_status
    }

@app.post("/api/predict", response_model=PredictionOutput)
async def predict_gdm_risk(input_data: PredictionInput):
    """
    Predict GDM risk based on patient health data
    Uses 4 features: Age, BP Systolic, BP Diastolic, Blood Glucose
    """
    try:
        # Extract and validate features
        age = input_data.age
        systolic = input_data.blood_pressure_systolic
        diastolic = input_data.blood_pressure_diastolic
        glucose = input_data.blood_glucose
        
        # Validate input ranges
        if not (18 <= age <= 50):
            raise HTTPException(status_code=400, detail="Age must be between 18-50 years")
        if not (80 <= systolic <= 200):
            raise HTTPException(status_code=400, detail="Systolic BP must be between 80-200 mmHg")
        if not (40 <= diastolic <= 130):
            raise HTTPException(status_code=400, detail="Diastolic BP must be between 40-130 mmHg")
        if not (50 <= glucose <= 400):
            raise HTTPException(status_code=400, detail="Blood glucose must be between 50-400 mg/dL")
        
        # Prepare features in correct order for model
        # Order: Age, BP Systolic, BP Diastolic, Blood Glucose
        features = np.array([[age, systolic, diastolic, glucose]])
        
        print(f"📊 Input features shape: {features.shape}")
        print(f"📊 Input features: {features}")
        
        # Make prediction with loaded model
        if model is not None:
            try:
                prediction = model.predict(features)[0]
                probabilities = model.predict_proba(features)[0]
                
                print(f"🎯 Model prediction: {prediction}")
                print(f"📈 Probabilities: {probabilities}")
                
                # Get risk percentage (probability of positive class)
                risk_percentage = float(probabilities[1] * 100)
                
                # Determine risk level based on probability
                if risk_percentage >= 60:
                    risk_level = "High"
                    confidence = 85.0
                elif risk_percentage >= 30:
                    risk_level = "Medium"
                    confidence = 78.0
                else:
                    risk_level = "Low"
                    confidence = 92.0
                
            except Exception as e:
                print(f"❌ Model prediction error: {e}")
                raise HTTPException(status_code=500, detail=f"ML prediction error: {str(e)}")
        else:
            # Fallback to rule-based prediction if model not loaded
            print("⚠️  Using rule-based prediction (model not loaded)")
            risk_percentage, risk_level, confidence = calculate_rule_based_risk(
                age, systolic, diastolic, glucose
            )
        
        # Analyze factors
        factors = []
        
        # Analyze Age
        if age > 35:
            age_impact = "warning"
            age_status = f"{age} years (Advanced maternal age)"
        else:
            age_impact = "positive"
            age_status = f"{age} years"
        
        factors.append({
            "name": "Age",
            "value": age_status,
            "impact": age_impact,
            "icon": "cake"
        })
        
        # Analyze Blood Glucose
        if glucose >= 126:
            glucose_impact = "negative"
            glucose_status = f"Elevated ({glucose} mg/dL)"
        elif glucose >= 100:
            glucose_impact = "warning"
            glucose_status = f"Borderline ({glucose} mg/dL)"
        else:
            glucose_impact = "positive"
            glucose_status = f"Normal ({glucose} mg/dL)"
        
        factors.append({
            "name": "Blood Glucose",
            "value": glucose_status,
            "impact": glucose_impact,
            "icon": "bloodtype"
        })
        
        # Analyze Blood Pressure
        if systolic >= 140 or diastolic >= 90:
            bp_impact = "negative"
            bp_status = f"Elevated ({systolic}/{diastolic} mmHg)"
        elif systolic >= 130 or diastolic >= 85:
            bp_impact = "warning"
            bp_status = f"Borderline ({systolic}/{diastolic} mmHg)"
        else:
            bp_impact = "positive"
            bp_status = f"Normal ({systolic}/{diastolic} mmHg)"
        
        factors.append({
            "name": "Blood Pressure",
            "value": bp_status,
            "impact": bp_impact,
            "icon": "favorite"
        })
        
        # Generate recommendations
        recommendations = generate_recommendations(risk_level, glucose, systolic, diastolic, age)
        
        return PredictionOutput(
            risk_level=risk_level,
            risk_percentage=float(risk_percentage),
            confidence=confidence,
            recommendations=recommendations,
            factors=factors
        )
        
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")

def calculate_rule_based_risk(age, systolic, diastolic, glucose):
    """Fallback rule-based risk calculation"""
    risk_score = 0
    
    # Age factor
    if age > 35:
        risk_score += 15
    
    # Glucose factor
    if glucose >= 126:
        risk_score += 40
    elif glucose >= 100:
        risk_score += 20
    
    # Blood pressure factor
    if systolic >= 140 or diastolic >= 90:
        risk_score += 25
    elif systolic >= 130 or diastolic >= 85:
        risk_score += 15
    
    # Determine risk level
    if risk_score >= 60:
        risk_level = "High"
        confidence = 85.0
    elif risk_score >= 30:
        risk_level = "Medium"
        confidence = 78.0
    else:
        risk_level = "Low"
        confidence = 92.0
    
    return float(risk_score), risk_level, confidence

def generate_recommendations(risk_level, glucose, systolic, diastolic, age):
    """Generate personalized recommendations"""
    recommendations = []
    
    if risk_level == "High":
        recommendations.append("⚠️ Schedule an immediate appointment with your healthcare provider")
    
    # Glucose-based recommendations
    if glucose >= 126:
        recommendations.append("Monitor blood glucose 4 times daily (fasting and after meals)")
        recommendations.append("Follow a strict carbohydrate-controlled diet")
    elif glucose >= 100:
        recommendations.append("Monitor blood glucose levels regularly")
        recommendations.append("Reduce intake of sugary foods and refined carbohydrates")
    else:
        recommendations.append("Continue current blood glucose monitoring schedule")
    
    # Blood pressure recommendations
    if systolic >= 140 or diastolic >= 90:
        recommendations.append("Consult your doctor about blood pressure management")
        recommendations.append("Monitor blood pressure daily")
        recommendations.append("Reduce salt intake and manage stress")
    elif systolic >= 130 or diastolic >= 85:
        recommendations.append("Keep track of blood pressure readings weekly")
    
    # Age-based recommendations
    if age > 35:
        recommendations.append("Attend all scheduled prenatal checkups")
        recommendations.append("Discuss additional monitoring with your healthcare provider")
    
    # General recommendations
    recommendations.append("Stay physically active with doctor-approved exercises (30 min/day)")
    recommendations.append("Maintain a balanced diet rich in vegetables and whole grains")
    recommendations.append("Get adequate sleep (7-9 hours per night)")
    
    return recommendations

@app.get("/api/health")
def health_check():
    """API health check"""
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "endpoints": {
            "predict": "/api/predict",
            "docs": "/docs"
        }
    }

@app.get("/api/model-info")
def model_info():
    """Get information about the loaded model"""
    if model is None:
        return {
            "model_loaded": False,
            "message": "No model loaded. Using rule-based prediction."
        }
    
    return {
        "model_loaded": True,
        "model_type": str(type(model).__name__),
        "expected_features": 4,
        "feature_names": ["Age", "Blood Pressure Systolic", "Blood Pressure Diastolic", "Blood Glucose"]
    }

if __name__ == "__main__":
    print("=" * 60)
    print("🏥 MamaSafe GDM Prediction API")
    print("=" * 60)
    print(f"📊 Model Status: {'Loaded ✅' if model else 'Not Loaded ⚠️'}")
    print(f"🔧 Expected Features: 4")
    print(f"📝 Features: Age, BP Systolic, BP Diastolic, Blood Glucose")
    print("=" * 60)
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)