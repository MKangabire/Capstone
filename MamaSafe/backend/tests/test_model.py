# tests/test_model.py
import pytest
import numpy as np
@pytest.mark.model
def test_model_loaded(mock_model):
    """Test that model can be loaded"""
    assert mock_model is not None
    assert hasattr(mock_model, 'predict')
    assert hasattr(mock_model, 'predict_proba')
@pytest.mark.model
def test_model_predict(mock_model):
    """Test model prediction"""
    features = np.array([[28, 120, 80, 95]])
    result = mock_model.predict(features)
    assert isinstance(result, np.ndarray)
    assert len(result) == 1
@pytest.mark.model
def test_model_predict_proba(mock_model):
    """Test model probability prediction"""
    features = np.array([[28, 120, 80, 95]])
    result = mock_model.predict_proba(features)
    assert isinstance(result, np.ndarray)
    assert result.shape[1] == 2  # Binary classification
