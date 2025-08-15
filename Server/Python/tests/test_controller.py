import asyncio
import sys
from unittest.mock import MagicMock, AsyncMock
import pytest
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

@pytest.fixture
def controller(thread_pool):
    # Ensure the mocks are used
    controller = SystemController(thread_pool)
    controller.pyautogui = MagicMock()
    controller.pyperclip = MagicMock()
    # Mock the async execute method
    controller.execute = AsyncMock()
    return controller

@pytest.mark.asyncio
async def test_copy_selection_to_clipboard_mac(controller):
    """Tests that the correct hotkey is used for copying on macOS."""
    original_platform = sys.platform
    sys.platform = 'darwin'
    try:
        await controller.copy_selection_to_clipboard()
        controller.execute.assert_called_once_with(controller.pyautogui.hotkey, 'cmd', 'c')
    finally:
        sys.platform = original_platform

@pytest.mark.asyncio
async def test_copy_selection_to_clipboard_other(controller):
    """Tests that the correct hotkey is used for copying on non-macOS platforms."""
    original_platform = sys.platform
    sys.platform = 'linux'
    try:
        await controller.copy_selection_to_clipboard()
        controller.execute.assert_called_once_with(controller.pyautogui.hotkey, 'ctrl', 'c')
    finally:
        sys.platform = original_platform

@pytest.mark.asyncio
async def test_paste_from_clipboard_mac(controller):
    """Tests that the correct hotkey is used for pasting on macOS."""
    original_platform = sys.platform
    sys.platform = 'darwin'
    try:
        await controller.paste_from_clipboard()
        controller.execute.assert_called_once_with(controller.pyautogui.hotkey, 'cmd', 'v')
    finally:
        sys.platform = original_platform

@pytest.mark.asyncio
async def test_paste_from_clipboard_other(controller):
    """Tests that the correct hotkey is used for pasting on non-macOS platforms."""
    original_platform = sys.platform
    sys.platform = 'win32'
    try:
        await controller.paste_from_clipboard()
        controller.execute.assert_called_once_with(controller.pyautogui.hotkey, 'ctrl', 'v')
    finally:
        sys.platform = original_platform
