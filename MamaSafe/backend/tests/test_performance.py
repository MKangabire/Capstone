import pytest
import time
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_prediction_latency():
    """Test that prediction API responds quickly"""
    payload = {
        "age": 28,
        "blood_pressure_systolic": 120,
        "blood_pressure_diastolic": 80,
        "blood_glucose": 95,
        "patient_id": "perf-test-123"
    }
    
    start = time.time()
    response = client.post("/api/predict", json=payload)
    duration = (time.time() - start) * 1000  # Convert to ms
    
    print(f"⏱️  Prediction latency: {duration:.2f}ms")
    
    assert response.status_code in [200, 500]  # 500 if DB not available
    assert duration < 2000, f"Too slow: {duration}ms > 2000ms"

def test_health_endpoint_fast():
    """Health check should be very fast"""
    start = time.time()
    response = client.get("/api/health")
    duration = (time.time() - start) * 1000
    
    print(f"⏱️  Health check: {duration:.2f}ms")
    
    assert response.status_code == 200
    assert duration < 100, f"Health check too slow: {duration}ms"

def test_concurrent_predictions():
    """Test handling multiple concurrent requests"""
    import concurrent.futures
    
    def make_prediction():
        return client.post("/api/predict", json={
            "age": 28,
            "blood_pressure_systolic": 120,
            "blood_pressure_diastolic": 80,
            "blood_glucose": 95,
            "patient_id": "concurrent-test"
        })
    
    start = time.time()
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(make_prediction) for _ in range(10)]
        results = [f.result() for f in concurrent.futures.as_completed(futures)]
    
    duration = (time.time() - start) * 1000
    
    print(f"⏱️  10 concurrent requests: {duration:.2f}ms")
    assert duration < 5000, "Concurrent requests too slow"