import asyncio
import sys
from unittest.mock import MagicMock, AsyncMock
import pytest
import pytest_asyncio
from concurrent.futures import ThreadPoolExecutor

# Mock heavy dependencies before import
sys.modules['pyautogui'] = MagicMock()
sys.modules['pyperclip'] = MagicMock()
sys.modules['translators'] = MagicMock()

from core.controller import SystemController

@pytest.fixture
def thread_pool():
    pool = ThreadPoolExecutor(max_workers=1)
    yield pool
    pool.shutdown(wait=True)

@pytest_asyncio.fixture
async def controller(thread_pool):
    # Ensure the mocks are used
    controller = SystemController(thread_pool)
    controller.pyautogui = MagicMock()
    controller.pyperclip = MagicMock()
    # Mock the async execute method
    controller.execute = AsyncMock()
    return controller

from core.platform_controllers import get_platform_controller


@pytest.mark.asyncio
async def test_copy_selection_to_clipboard_mac(controller):
    """Tests that the correct platform controller method is called for copying on macOS."""
    original_platform = sys.platform
    sys.platform = 'darwin'
    controller.platform_controller = get_platform_controller(controller.pyautogui)
    try:
        await controller.copy_selection_to_clipboard()
        controller.execute.assert_called_once_with(controller.platform_controller.copy)
    finally:
        sys.platform = original_platform

@pytest.mark.asyncio
async def test_copy_selection_to_clipboard_other(controller):
    """Tests that the correct platform controller method is called for copying on non-macOS platforms."""
    original_platform = sys.platform
    sys.platform = 'linux'
    controller.platform_controller = get_platform_controller(controller.pyautogui)
    try:
        await controller.copy_selection_to_clipboard()
        controller.execute.assert_called_once_with(controller.platform_controller.copy)
    finally:
        sys.platform = original_platform

@pytest.mark.asyncio
async def test_paste_from_clipboard_mac(controller):
    """Tests that the correct platform controller method is called for pasting on macOS."""
    original_platform = sys.platform
    sys.platform = 'darwin'
    controller.platform_controller = get_platform_controller(controller.pyautogui)
    try:
        await controller.paste_from_clipboard()
        controller.execute.assert_called_once_with(controller.platform_controller.paste)
    finally:
        sys.platform = original_platform

@pytest.mark.asyncio
async def test_paste_from_clipboard_other(controller):
    """Tests that the correct platform controller method is called for pasting on non-macOS platforms."""
    original_platform = sys.platform
    sys.platform = 'win32'
    controller.platform_controller = get_platform_controller(controller.pyautogui)
    try:
        await controller.paste_from_clipboard()
        controller.execute.assert_called_once_with(controller.platform_controller.paste)
    finally:
        sys.platform = original_platform
