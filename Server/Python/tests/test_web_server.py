import pytest
import pytest_asyncio
import asyncio
from unittest.mock import patch, AsyncMock, MagicMock
from aiohttp import web

from gesture_server import GestureServer
from web_server import WebServer
from core.models import ServerConfig
from core.controller import SystemController

pytestmark = pytest.mark.asyncio

@pytest_asyncio.fixture
async def api_client(aiohttp_client):
    """Fixture to create a test client for the web server."""
    config = ServerConfig(host="127.0.0.1", websocket_port=8765, performance_logging=False)

    with patch('gesture_server.SystemController') as MockController:
        mock_instance = AsyncMock(spec=SystemController)
        mock_instance.size = MagicMock(return_value=(1920, 1080))
        MockController.return_value = mock_instance

        # We don't need to start the full GestureServer, just the WebServer part
        # To do that, we can create a mock GestureServer
        mock_gesture_server = MagicMock()
        mock_gesture_server.config = config
        mock_gesture_server.executor.controller = mock_instance

        web_server = WebServer(mock_gesture_server)
        client = await aiohttp_client(web_server.app)

        # Attach the mock controller to the client so we can access it in tests
        client.mock_controller = mock_instance
        yield client

async def test_translate_api_success(api_client):
    """Test the /api/v1/translate endpoint for a successful translation."""
    # Configure the mock to return a specific translated text
    api_client.mock_controller.translate.return_value = "Bonjour le monde"

    response = await api_client.post('/api/v1/translate', json={
        "text": "Hello, world",
        "to_language": "fr"
    })

    assert response.status == 200
    data = await response.json()
    assert data == {
        "status": "ok",
        "translated_text": "Bonjour le monde"
    }

    # Verify that the controller's translate method was called correctly
    api_client.mock_controller.translate.assert_awaited_once_with("Hello, world", "fr")

async def test_translate_api_missing_text(api_client):
    """Test the translate endpoint when the 'text' field is missing."""
    response = await api_client.post('/api/v1/translate', json={
        "to_language": "fr"
    })

    assert response.status == 400
    data = await response.json()
    assert data['status'] == 'error'
    assert "'text' field is required" in data['message']

async def test_translate_api_invalid_json(api_client):
    """Test the translate endpoint with malformed JSON."""
    response = await api_client.post('/api/v1/translate', data="not json")

    assert response.status == 400
    data = await response.json()
    assert data['status'] == 'error'
    assert "Invalid JSON format" in data['message']

async def test_translate_api_controller_error(api_client):
    """Test the translate endpoint when the controller raises an exception."""
    api_client.mock_controller.translate.side_effect = Exception("Translation service failed")

    response = await api_client.post('/api/v1/translate', json={
        "text": "Hello, world",
        "to_language": "fr"
    })

    assert response.status == 500
    data = await response.json()
    assert data['status'] == 'error'
    assert "Translation failed" in data['message']
