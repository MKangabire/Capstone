# tests/mocks/mock_data.py
"""Mock data for testing"""
class MockData:
    """Centralized mock data for tests"""

    # IDs
    PATIENT_ID = "test-patient-123"
    PATIENT_ID_2 = "test-patient-456"
    CHW_ID = "test-chw-123"
    NOTIFICATION_ID = "test-notif-123"
    PREDICTION_ID = "test-pred-123"

    # Valid prediction input
    VALID_PREDICTION_INPUT = {
        "age": 28,
        "blood_pressure_systolic": 120,
        "blood_pressure_diastolic": 80,
        "blood_glucose": 95,
        "patient_id": PATIENT_ID
    }

    # High-risk input
    HIGH_RISK_INPUT = {
        "age": 38,
        "blood_pressure_systolic": 155,
        "blood_pressure_diastolic": 98,
        "blood_glucose": 180,
        "patient_id": PATIENT_ID_2
    }

    # Invalid inputs
    INVALID_AGE_LOW = {"age": 15, "blood_pressure_systolic": 120,
                       "blood_pressure_diastolic": 80, "blood_glucose": 95,
                       "patient_id": PATIENT_ID}
    INVALID_AGE_HIGH = {"age": 60, "blood_pressure_systolic": 120,
                        "blood_pressure_diastolic": 80, "blood_glucose": 95,
                        "patient_id": PATIENT_ID}
    INVALID_BP_SYSTOLIC = {"age": 28, "blood_pressure_systolic": 250,
                           "blood_pressure_diastolic": 80, "blood_glucose": 95,
                           "patient_id": PATIENT_ID}
    INVALID_BP_DIASTOLIC = {"age": 28, "blood_pressure_systolic": 120,
                            "blood_pressure_diastolic": 150, "blood_glucose": 95,
                            "patient_id": PATIENT_ID}
    INVALID_GLUCOSE = {"age": 28, "blood_pressure_systolic": 120,
                       "blood_pressure_diastolic": 80, "blood_glucose": 500,
                       "patient_id": PATIENT_ID}

    # Patient profile
    PATIENT_PROFILE = {
        "id": PATIENT_ID,
        "full_name": "Test Patient",
        "email": "patient@test.com",
        "age": 28,
        "height": 165.0,
        "weight": 68.0,
        "bmi": 25.0,
        "phone": "+250788123456",
        "chw_id": CHW_ID
    }

    # CHW profile
    CHW_PROFILE = {
        "id": CHW_ID,
        "full_name": "Test CHW",
        "email": "chw@test.com",
        "phone": "+250788654321",
        "region": "Test Village, Test Cell, Test Sector"
    }

    # Expected prediction response
    PREDICTION_RESPONSE = {
        "id": PREDICTION_ID,
        "patient_id": PATIENT_ID,
        "risk_level": "Low",
        "risk_percentage": 30.0,
        "confidence": 85.0,
        "factors": "No significant risk factors detected",
        "recommendations": "Continue regular prenatal care",
        "created_at": "2025-10-30T10:00:00"
    }

    # Notification
    NOTIFICATION = {
        "id": NOTIFICATION_ID,
        "chw_id": CHW_ID,
        "patient_id": PATIENT_ID,
        "title": "Test Alert",
        "message": "Test notification message",
        "notification_type": "high_risk_alert",
        "is_read": False,
        "created_at": "2025-10-30T10:00:00"
    }