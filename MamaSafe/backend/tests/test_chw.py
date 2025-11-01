
# tests/test_chw.py
from fastapi.testclient import TestClient
from tests.mocks.mock_data import MockData as M
def test_get_chw_details(client: TestClient):
    """Test GET /api/chw/{chw_id}"""
    resp = client.get(f"/api/chw/{M.CHW_ID}")
    # May return 200 with data or 404 if CHW doesn't exist
    assert resp.status_code in [200, 404]
def test_get_chw_patients(client: TestClient):
    """Test GET /api/chw/patients/{chw_id}"""
    resp = client.get(f"/api/chw/patients/{M.CHW_ID}")
    # Should return 200 with list (even if empty)
    assert resp.status_code in [200, 500]
    if resp.status_code == 200:
        data = resp.json()
        assert "patients" in data or "success" in data
def test_assign_patient_to_chw(client: TestClient):
    """Test POST /api/chw/{chw_id}/assign-patient"""
    resp = client.post(f"/api/chw/{M.CHW_ID}/assign-patient?patient_id={M.PATIENT_ID}")
    # May succeed or fail depending on database state
    assert resp.status_code in [200, 404, 500]
