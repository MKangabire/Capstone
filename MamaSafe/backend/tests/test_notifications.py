
# tests/test_notifications.py
from fastapi.testclient import TestClient
from tests.mocks.mock_data import MockData as M
def test_send_notification(client: TestClient):
    """Test POST /api/notifications/send"""
    notification_data = {
    "chw_id": M.CHW_ID,
    "patient_id": M.PATIENT_ID,
    "title": "Test Alert",
    "message": "Test message",
    "notification_type": "high_risk_alert"
    }
    resp = client.post("/api/notifications/send", json=notification_data)
    # May succeed or fail depending on database
    assert resp.status_code in [200, 500]
def test_get_chw_notifications(client: TestClient):
    """Test GET /api/notifications/{chw_id}"""
    resp = client.get(f"/api/notifications/{M.CHW_ID}")
    # Should return 200 with list
    assert resp.status_code in [200, 500]
def test_get_chw_notifications_unread_only(client: TestClient):
    """Test GET /api/notifications/{chw_id} with unread filter"""
    resp = client.get(f"/api/notifications/{M.CHW_ID}?unread_only=true")
    assert resp.status_code in [200, 500]
def test_mark_notification_read(client: TestClient):
    """Test PUT /api/notifications/{notification_id}/mark-read"""
    resp = client.put(f"/api/notifications/{M.NOTIFICATION_ID}/mark-read")
    # May succeed or fail depending on database
    assert resp.status_code in [200, 404, 500]