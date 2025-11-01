# tests/test_health.py
from fastapi.testclient import TestClient
def test_root_endpoint(client: TestClient):
    # """Test GET / returns API information"""
    resp = client.get("/")
    assert resp.status_code == 200
    data = resp.json()
    assert data["message"] == "MamaSafe GDM Prediction API"
    assert data["version"] == "1.0.0"
def test_health_check(client: TestClient):
    #""Test GET /api/health returns healthy status"""
    resp = client.get("/api/health")  # ✅ Fixed: added /api prefix
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert "model_status" in data
    assert "supabase_status" in data
def test_health_check_model_loaded(client: TestClient):
    #"""Test health check shows model status"""
    resp = client.get("/api/health")
    data = resp.json()
    assert data["model_status"] in ["loaded", "not loaded"]
def test_health_check_supabase_connected(client: TestClient):
    #"""Test health check shows Supabase status"""
    resp = client.get("/api/health")
    data = resp.json()
    assert data["supabase_status"] in ["connected", "failed"]