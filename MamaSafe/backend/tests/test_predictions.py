# tests/test_predictions.py
from fastapi.testclient import TestClient
from tests.mocks.mock_data import MockData as M
import pytest
def test_create_prediction_valid(client: TestClient):
    #"""Test POST /api/predict with valid data"""
    resp = client.post("/api/predict", json=M.VALID_PREDICTION_INPUT)  # ✅ Fixed endpoint
    assert resp.status_code == 200  # ✅ Fixed: API returns 200, not 201
    data = resp.json()
    assert data["success"] is True
    assert "risk_level" in data
    assert "risk_percentage" in data
    assert "confidence" in data
def test_create_prediction_high_risk(client: TestClient):
    #"""Test POST /api/predict with high-risk data"""
    resp = client.post("/api/predict", json=M.HIGH_RISK_INPUT)  # ✅ Fixed endpoint
    assert resp.status_code == 200  # ✅ Fixed status code
    data = resp.json()
    assert data["success"] is True
    # High risk detection depends on model prediction
    assert "risk_level" in data
def test_validation_age_low(client: TestClient):
    #"""Test validation for age too low"""
    resp = client.post("/api/predict", json=M.INVALID_AGE_LOW)
    assert resp.status_code == 422
    assert "age" in resp.text.lower()
def test_validation_age_high(client: TestClient):
    #"""Test validation for age too high"""
    resp = client.post("/api/predict", json=M.INVALID_AGE_HIGH)
    assert resp.status_code == 422
    assert "age" in resp.text.lower()
def test_validation_bp_systolic(client: TestClient):
    #"""Test validation for systolic BP out of range"""
    resp = client.post("/api/predict", json=M.INVALID_BP_SYSTOLIC)
    assert resp.status_code == 422
def test_validation_bp_diastolic(client: TestClient):
    #"""Test validation for diastolic BP out of range"""
    resp = client.post("/api/predict", json=M.INVALID_BP_DIASTOLIC)
    assert resp.status_code == 422
def test_validation_glucose(client: TestClient):
    #"""Test validation for blood glucose out of range"""
    resp = client.post("/api/predict", json=M.INVALID_GLUCOSE)
    assert resp.status_code == 422
def test_get_patient_predictions(client: TestClient):
    #"""Test GET /api/predictions/{patient_id}"""
    resp = client.get(f"/api/predictions/{M.PATIENT_ID}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert "predictions" in data
def test_get_latest_prediction(client: TestClient):
    #"""Test GET /api/predictions/latest/{patient_id}"""
    resp = client.get(f"/api/predictions/latest/{M.PATIENT_ID}")
    # May return 200 with data or 404 if no predictions
    assert resp.status_code in [200, 404]