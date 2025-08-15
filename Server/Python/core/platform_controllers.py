import sys
from abc import ABC, abstractmethod

class PlatformController(ABC):
    """Abstract base class for platform-specific controllers."""
    def __init__(self, pyautogui_module):
        self.pyautogui = pyautogui_module

    @abstractmethod
    def copy(self):
        pass

    @abstractmethod
    def paste(self):
        pass

class MacOSPlatformController(PlatformController):
    """Platform-specific controller for macOS."""
    def copy(self):
        self.pyautogui.hotkey('cmd', 'c')

    def paste(self):
        self.pyautogui.hotkey('cmd', 'v')

class DefaultPlatformController(PlatformController):
    """Default platform controller for Windows, Linux, etc."""
    def copy(self):
        self.pyautogui.hotkey('ctrl', 'c')

    def paste(self):
        self.pyautogui.hotkey('ctrl', 'v')

def get_platform_controller(pyautogui_module):
    """Factory function to get the correct platform controller."""
    if sys.platform == 'darwin':
        return MacOSPlatformController(pyautogui_module)
    return DefaultPlatformController(pyautogui_module)
