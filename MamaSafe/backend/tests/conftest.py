# tests/conftest.py

import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch
import sys
import os
import numpy as np

# Add parent directory to path so pytest can find "main.py"
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from main import app  # import your FastAPI app


# ------------------------------
# MOCKS
# ------------------------------

@pytest.fixture(scope="session")
def mock_model():
    """Create a mock ML model"""
    model = MagicMock()
    model.predict.return_value = np.array([0])  # Low risk prediction
    model.predict_proba.return_value = np.array([[0.7, 0.3]])  # 30% probability
    model.classes_ = np.array([0, 1])
    return model


@pytest.fixture(scope="session")
def mock_supabase():
    """Create a mock Supabase client"""
    mock_client = MagicMock()

    # Mock table operations
    mock_table = MagicMock()
    mock_client.table.return_value = mock_table

    # Mock insert
    mock_insert = MagicMock()
    mock_insert.execute.return_value = MagicMock(
        data=[{
            'id': 'pred-123',
            'patient_id': 'patient-123',
            'risk_level': 'Low',
            'risk_percentage': 30.0,
            'confidence': 30.0
        }]
    )
    mock_table.insert.return_value = mock_insert

    # Mock select
    mock_select = MagicMock()
    mock_select.eq.return_value = mock_select
    mock_select.order.return_value = mock_select
    mock_select.limit.return_value = mock_select
    mock_select.single.return_value = mock_select
    mock_select.execute.return_value = MagicMock(
        data=[{
            'id': 'pred-123',
            'patient_id': 'patient-123',
            'risk_level': 'Low',
            'risk_percentage': 30.0,
            'confidence': 30.0,
            'created_at': '2025-10-30T10:00:00'
        }]
    )
    mock_table.select.return_value = mock_select

    # Mock update
    mock_update = MagicMock()
    mock_update.eq.return_value = mock_update
    mock_update.execute.return_value = MagicMock(
        data=[{'id': 'patient-123', 'full_name': 'Updated Name'}]
    )
    mock_table.update.return_value = mock_update

    return mock_client


# ------------------------------
# CLIENT FIXTURE
# ------------------------------

@pytest.fixture(scope="module")
def client(mock_model, mock_supabase):
    """Create a test client with mocked dependencies"""
    with patch('main.model', mock_model), patch('main.supabase', mock_supabase):
        with TestClient(app) as test_client:
            yield test_client


# ------------------------------
# SAMPLE DATA FIXTURES
# ------------------------------

@pytest.fixture
def sample_prediction_input():
    """Sample valid prediction input data"""
    return {
        "age": 28,
        "blood_pressure_systolic": 120,
        "blood_pressure_diastolic": 80,
        "blood_glucose": 95,
        "patient_id": "patient-123"
    }


@pytest.fixture
def sample_high_risk_input():
    """Sample high-risk prediction input"""
    return {
        "age": 38,
        "blood_pressure_systolic": 150,
        "blood_pressure_diastolic": 95,
        "blood_glucose": 180,
        "patient_id": "patient-456"
    }


@pytest.fixture
def sample_patient_data():
    """Sample patient profile data"""
    return {
        "id": "patient-123",
        "full_name": "Test Patient",
        "email": "patient@test.com",
        "age": 28,
        "height": 165.0,
        "weight": 68.0,
        "bmi": 25.0,
        "phone": "+250788123456",
        "chw_id": "chw-123"
    }


@pytest.fixture
def sample_chw_data():
    """Sample CHW data"""
    return {
        "id": "chw-123",
        "full_name": "Test CHW",
        "email": "chw@test.com",
        "phone": "+250788654321",
        "region": "Test Region"
    }


@pytest.fixture
def sample_notification():
    """Sample notification data"""
    return {
        "chw_id": "chw-123",
        "patient_id": "patient-123",
        "title": "Test Alert",
        "message": "Test notification message",
        "notification_type": "high_risk_alert"
    }


# ------------------------------
# AUTO RESET MOCKS
# ------------------------------

@pytest.fixture(autouse=True)
def reset_mocks(mock_model, mock_supabase):
    """Reset mocks after each test"""
    yield
    mock_model.reset_mock()
    mock_supabase.reset_mock()
