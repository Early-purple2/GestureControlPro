import asyncio
import sys
from concurrent.futures import ThreadPoolExecutor
from .platform_controllers import get_platform_controller


class SystemController:
    """Abstracts system control actions to allow for testability."""
    def __init__(self, thread_pool: ThreadPoolExecutor):
        self.thread_pool = thread_pool
        self.loop = asyncio.get_running_loop()

        # Check if we are in a headless environment
        import os
        if 'DISPLAY' in os.environ:
            import pyautogui
            self.pyautogui = pyautogui
            self.pyautogui.FAILSAFE = False
            self.pyautogui.PAUSE = 0.001
            try:
                import pyperclip
                self.pyperclip = pyperclip
            except ImportError:
                from unittest.mock import MagicMock
                self.pyperclip = MagicMock()
            try:
                import translators as ts
                self.translators = ts
            except ImportError:
                from unittest.mock import MagicMock
                self.translators = MagicMock()
        else:
            # Use a mock pyautogui if no display is available
            from unittest.mock import MagicMock
            self.pyautogui = MagicMock()
            self.pyautogui.size.return_value = (1920, 1080)
            self.pyperclip = MagicMock()
            self.translators = MagicMock()

        self.platform_controller = get_platform_controller(self.pyautogui)

    async def execute(self, func, *args):
        return await self.loop.run_in_executor(self.thread_pool, func, *args)

    async def click(self, x, y, button):
        await self.execute(self.pyautogui.click, x, y, button=button)

    async def double_click(self, x, y, button):
        await self.execute(self.pyautogui.doubleClick, x, y, button=button)

    async def drag_to(self, x, y, duration):
        await self.execute(self.pyautogui.dragTo, x, y, duration)

    async def scroll(self, amount, x, y):
        await self.execute(self.pyautogui.scroll, amount, x, y)

    async def hscroll(self, amount, x, y):
        await self.execute(self.pyautogui.hscroll, amount, x, y)

    async def key_down(self, key):
        await self.execute(self.pyautogui.keyDown, key)

    async def key_up(self, key):
        await self.execute(self.pyautogui.keyUp, key)

    async def mouse_down(self, x: int, y: int, button: str):
        await self.execute(self.pyautogui.mouseDown, x, y, button=button)

    async def mouse_up(self, x: int, y: int, button: str):
        await self.execute(self.pyautogui.mouseUp, x, y, button=button)

    async def move_to(self, x, y, duration):
        await self.execute(self.pyautogui.moveTo, x, y, duration=duration)

    async def move_relative(self, dx: int, dy: int):
        await self.execute(self.pyautogui.move, dx, dy)

    async def press(self, key):
        await self.execute(self.pyautogui.press, key)

    async def hotkey(self, *keys):
        await self.execute(self.pyautogui.hotkey, *keys)

    async def type_string(self, text: str):
        await self.execute(self.pyautogui.typewrite, text)

    def size(self):
        return self.pyautogui.size()

    async def copy_to_clipboard(self, text: str):
        await self.execute(self.pyperclip.copy, text)

    async def paste_from_clipboard(self):
        await self.execute(self.platform_controller.paste)

    async def copy_selection_to_clipboard(self):
        await self.execute(self.platform_controller.copy)

    async def read_clipboard(self):
        return await self.execute(self.pyperclip.paste)

    async def translate(self, text: str, to_language='en'):
        return await self.execute(self.translators.translate_text, text, to_language=to_language)

    async def volume_up(self):
        await self.execute(self.pyautogui.press, 'volumeup')

    async def volume_down(self):
        await self.execute(self.pyautogui.press, 'volumedown')
