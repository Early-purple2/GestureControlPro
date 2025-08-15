import pytest
import pytest_asyncio
import asyncio
import json
import websockets
from unittest.mock import patch, AsyncMock, MagicMock

from gesture_server import GestureServer
from core.models import ServerConfig
from core.controller import SystemController

pytestmark = pytest.mark.asyncio

@pytest_asyncio.fixture
async def test_server():
    """Fixture to start and stop a GestureServer instance for testing."""
    config = ServerConfig(host="127.0.0.1", websocket_port=8765, performance_logging=False, gesture_smoothing=0.0)

    # We patch the SystemController to avoid real mouse movements
    # and to be able to check if its methods are called.
    with patch('gesture_server.SystemController') as MockController:
        # We need a mock that has both async and sync methods.
        # AsyncMock is the base, but we override 'size' to be a sync MagicMock.
        mock_instance = AsyncMock(spec=SystemController)
        mock_instance.size = MagicMock(return_value=(1920, 1080))
        MockController.return_value = mock_instance

        server = GestureServer(config=config)
        server_task = asyncio.create_task(server.start())

        # Give the server a moment to start up
        await asyncio.sleep(0.05)

        # Yield the server and the mock controller instance to the test
        yield server, mock_instance

        # Teardown
        await server.stop()
        server_task.cancel()
        try:
            await server_task
        except asyncio.CancelledError:
            pass

async def test_websocket_connection(test_server):
    """Test that a client can connect to the WebSocket server."""
    server, _ = test_server
    uri = f"ws://{server.config.host}:{server.config.websocket_port}"
    try:
        async with websockets.connect(uri) as websocket:
            # The successful connection within the 'async with' block is the test.
            pass
    except ConnectionRefusedError:
        pytest.fail("The server did not accept the connection.")

async def test_websocket_move_command(test_server):
    """Test sending a move command over WebSocket."""
    server, mock_controller = test_server
    uri = f"ws://{server.config.host}:{server.config.websocket_port}"

    command = {
        "id": "ws-test-move-1",
        "type": "gesture_command",
        "payload": {
            "action": "move",
            "position": [0.5, 0.5],  # Normalized coordinates for center of 1920x1080
            "timestamp": 12345,
            "metadata": {}
        }
    }

    async with websockets.connect(uri) as websocket:
        await websocket.send(json.dumps(command))

    # The command is processed asynchronously. We wait for the executor's queue.
    await server.executor.command_queue.join()

    mock_controller.move_to.assert_awaited_once_with(960, 540, 0.001)

async def test_websocket_click_command(test_server):
    """Test sending a click command over WebSocket."""
    server, mock_controller = test_server
    uri = f"ws://{server.config.host}:{server.config.websocket_port}"

    command = {
        "id": "ws-test-click-1",
        "type": "gesture_command",
        "payload": {
            "action": "click",
            "position": [100 / 1920, 200 / 1080], # Normalized coordinates
            "timestamp": 12345,
            "metadata": {"button": "right"}
        }
    }

    async with websockets.connect(uri) as websocket:
        await websocket.send(json.dumps(command))

    await server.executor.command_queue.join()

    mock_controller.click.assert_awaited_once_with(100, 200, "right")

async def test_websocket_invalid_json(test_server):
    """Test that the server handles invalid JSON gracefully."""
    server, _ = test_server
    uri = f"ws://{server.config.host}:{server.config.websocket_port}"

    async with websockets.connect(uri) as websocket:
        await websocket.send("this is not json")
        response = await websocket.recv()
        data = json.loads(response)
        assert data['error'] == "Invalid JSON format"

async def test_websocket_invalid_command(test_server):
    """Test that the server handles a structurally invalid command."""
    server, _ = test_server
    uri = f"ws://{server.config.host}:{server.config.websocket_port}"

    # Command is missing the 'payload' field
    command = {
        "id": "ws-invalid-1",
        "type": "gesture_command"
    }

    async with websockets.connect(uri) as websocket:
        await websocket.send(json.dumps(command))
        response = await websocket.recv()
        data = json.loads(response)
        assert data['error'] == "Invalid command format"
        assert data['id'] == "ws-invalid-1"
