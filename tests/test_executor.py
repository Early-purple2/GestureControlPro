import pytest
import pytest_asyncio
import asyncio
from unittest.mock import AsyncMock, patch

from gesture_server import GestureExecutor, GestureCommand, ServerConfig, PerformanceMonitor, SystemController

# Pytest needs to know this is an async test file
pytestmark = pytest.mark.asyncio

@pytest.fixture
def config():
    """Provides a default ServerConfig for tests, disabling features that add complexity."""
    return ServerConfig(gesture_smoothing=0.0, enable_prediction=False)

@pytest.fixture
def performance_monitor():
    """Provides a mock PerformanceMonitor."""
    return AsyncMock(spec=PerformanceMonitor)

@pytest.fixture
def mock_controller():
    """Provides a mock SystemController."""
    controller = AsyncMock(spec=SystemController)
    controller.size.return_value = (1920, 1080)  # Mock screen size
    return controller

@pytest_asyncio.fixture
async def executor(config, performance_monitor, mock_controller):
    """Provides a GestureExecutor instance with mocked dependencies and handles cleanup."""
    exec_instance = GestureExecutor(config, performance_monitor, mock_controller)
    yield exec_instance
    # Cleanup: cancel the worker task to avoid it running forever
    exec_instance.worker_task.cancel()
    try:
        await exec_instance.worker_task
    except asyncio.CancelledError:
        pass

async def test_move_command(executor, mock_controller):
    """Tests that a 'move' command calls the controller's move_to method."""
    command = GestureCommand(
        id="test-move-1", action="move", position=[0.5, 0.5], timestamp=0, metadata={}
    )

    await executor.submit_command(command)
    await executor.command_queue.join()

    # 0.5 * 1920 = 960, 0.5 * 1080 = 540
    mock_controller.move_to.assert_awaited_once_with(960, 540, 0.001)

async def test_click_command(executor, mock_controller):
    """Tests that a 'click' command calls the controller's click method."""
    command = GestureCommand(
        id="test-click-1", action="click", position=[100/1920, 200/1080], timestamp=0, metadata={"button": "left"}
    )

    await executor.submit_command(command)
    await executor.command_queue.join()

    mock_controller.click.assert_awaited_once_with(100, 200, "left")

async def test_double_click_command(executor, mock_controller):
    """Tests double click command."""
    command = GestureCommand(
        id="test-dclick-1", action="double_click", position=[100/1920, 200/1080], timestamp=0, metadata={"button": "right"}
    )
    await executor.submit_command(command)
    await executor.command_queue.join()
    mock_controller.double_click.assert_awaited_once_with(100, 200, "right")

async def test_scroll_command(executor, mock_controller):
    """Tests scroll command."""
    command = GestureCommand(
        id="test-scroll-1", action="scroll", position=[300/1920, 400/1080], timestamp=0,
        metadata={"direction": "down", "amount": 5}
    )
    await executor.submit_command(command)
    await executor.command_queue.join()
    mock_controller.scroll.assert_awaited_once_with(-5, 300, 400)

async def test_hscroll_command(executor, mock_controller):
    """Tests horizontal scroll command."""
    command = GestureCommand(
        id="test-hscroll-1", action="scroll", position=[300/1920, 400/1080], timestamp=0,
        metadata={"direction": "left", "amount": 10}
    )
    await executor.submit_command(command)
    await executor.command_queue.join()
    mock_controller.hscroll.assert_awaited_once_with(-10, 300, 400)

async def test_key_press_command(executor, mock_controller):
    """Tests key press command."""
    command = GestureCommand(
        id="test-key-1", action="key_press", position=[0, 0], timestamp=0, metadata={"key": "enter"}
    )
    await executor.submit_command(command)
    await executor.command_queue.join()
    mock_controller.press.assert_awaited_once_with("enter")

async def test_hotkey_command(executor, mock_controller):
    """Tests hotkey (key combination) command."""
    command = GestureCommand(
        id="test-hotkey-1", action="key_combo", position=[0, 0], timestamp=0, metadata={"keys": ["ctrl", "c"]}
    )
    await executor.submit_command(command)
    await executor.command_queue.join()
    mock_controller.hotkey.assert_awaited_once_with("ctrl", "c")

async def test_smoothing_logic(executor, mock_controller):
    """Tests the position smoothing logic."""
    executor.config.gesture_smoothing = 0.5  # 50% smoothing
    executor.last_position = [0, 0]

    # Send normalized coordinates
    command1 = GestureCommand(id="c1", action="move", position=[100/1920, 100/1080], timestamp=0, metadata={})
    await executor.submit_command(command1)
    await executor.command_queue.join()
    # Expected absolute position: (100, 100)
    # Expected smoothed position: 0.5 * 100 + 0.5 * 0 = 50
    mock_controller.move_to.assert_awaited_with(50, 50, 0.001)
    assert executor.last_position == [50, 50]

    command2 = GestureCommand(id="c2", action="move", position=[100/1920, 100/1080], timestamp=0, metadata={})
    await executor.submit_command(command2)
    await executor.command_queue.join()
    # Expected absolute position: (100, 100)
    # Expected smoothed position: 0.5 * 100 + 0.5 * 50 = 75
    mock_controller.move_to.assert_awaited_with(75, 75, 0.001)
    assert executor.last_position == [75, 75]

@patch('gesture_server.TrajectoryPredictor')
async def test_prediction_logic(mock_predictor_class, executor, mock_controller):
    """Tests that the executor uses the predictor's output."""
    executor.config.enable_prediction = True

    # Configure the mock instance that will be created inside GestureExecutor
    mock_predictor_instance = mock_predictor_class.return_value
    mock_predictor_instance.predict.return_value = (150, 160)

    # The executor is already initialized, so we need to replace its predictor instance
    # with our configured mock instance.
    executor.predictor = mock_predictor_instance

    command = GestureCommand(id="p-test", action="move", position=[0.1, 0.1], timestamp=0, metadata={})

    await executor.submit_command(command)
    await executor.command_queue.join()

    # Assert that the mocked predictor was called
    mock_predictor_instance.predict.assert_called_once_with(executor.position_history)

    # Assert that move_to was called with the value from our mock predictor
    mock_controller.move_to.assert_awaited_once_with(150, 160, 0.001)
