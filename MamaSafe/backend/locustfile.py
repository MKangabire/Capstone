from locust import HttpUser, task, between
import random

class MamaSafeUser(HttpUser):
    host = "https://capstone-kubh.onrender.com"
    wait_time = between(1, 3)  # Wait 1-3 seconds between requests
    
    def on_start(self):
        """Called when a user starts"""
        print("🚀 Starting load test user")
    
    @task(5)  # Run this 5x more often than other tasks
    def predict_gdm(self):
        """Test GDM prediction endpoint"""
        payload = {
            "age": random.randint(20, 45),
            "blood_pressure_systolic": random.randint(110, 140),
            "blood_pressure_diastolic": random.randint(70, 90),
            "blood_glucose": random.randint(80, 120),
            "patient_id": f"test-patient-{random.randint(1, 100)}"
        }
        
        with self.client.post("/api/predict", json=payload, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Failed with status {response.status_code}")
    
    @task(2)
    def get_predictions(self):
        """Test getting predictions"""
        patient_id = f"test-patient-{random.randint(1, 100)}"
        self.client.get(f"/api/predictions/{patient_id}")
    
    @task(1)
    def health_check(self):
        """Test health endpoint"""
        self.client.get("/api/health")
    
    @task(1)
    def get_patient(self):
        """Test getting patient data"""
        patient_id = f"test-patient-{random.randint(1, 100)}"
        self.client.get(f"/api/patients/{patient_id}")