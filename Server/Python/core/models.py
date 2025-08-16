from dataclasses import dataclass, field
from typing import Dict, List, Any, Optional
from enum import Enum
import time


@dataclass
class TLSConfig:
    """TLS configuration settings."""
    enabled: bool = False
    cert_path: str = "certs/cert.pem"
    key_path: str = "certs/key.pem"


@dataclass
class ServerConfig:
    """Server configuration with optimizations."""
    # General
    version: str = "1.0.0"

    # Network
    websocket_port: int = 8081
    udp_port: int = 9090
    tcp_port: int = 7070
    dashboard_port: int = 8000
    host: str = "0.0.0.0"
    max_connections: int = 10
    heartbeat_interval: float = 1.0
    buffer_size: int = 8192

    # Performance
    command_timeout: float = 0.001  # 1ms max per command
    thread_pool_size: int = 4
    enable_prediction: bool = True
    gesture_smoothing: float = 0.7
    performance_logging: bool = True

    # Security
    secret_token: Optional[str] = None
    tls: TLSConfig = field(default_factory=TLSConfig)


class GestureAction(Enum):
    """Supported gesture actions."""
    CLICK = "click"
    DOUBLE_CLICK = "double_click"
    DRAG_START = "drag_start"
    DRAG_END = "drag_end"
    SCROLL = "scroll"
    ZOOM = "zoom"
    MOVE = "move"
    KEY_PRESS = "key_press"
    KEY_COMBO = "key_combo"
    TYPE_TEXT = "type_text"
    MOVE_RELATIVE = "move_relative"
    WAVE = "wave"
    COPY = "copy"
    PASTE = "paste"
    TRANSLATE = "translate"
    VOLUME_CONTROL = "volume_control"


@dataclass
class GestureCommand:
    """Gesture command with performance metadata."""
    id: str
    action: str
    position: List[float]
    timestamp: float
    metadata: Dict[str, Any]

    @classmethod
    def from_json(cls, data: Dict) -> Optional['GestureCommand']:
        try:
            payload = data['payload']
            return cls(
                id=data['id'],
                action=payload['action'],
                position=payload.get('position', [0, 0]),
                timestamp=data.get('timestamp', time.time()),
                metadata=payload.get('metadata', {})
            )
        except (KeyError, TypeError) as e:
            # Consider moving logger here or passing it
            print(f"Failed to parse GestureCommand: {e}")
            return None


@dataclass
class TranslateCommand:
    """Command to translate a text."""
    text: str
    to_language: str = 'en'

    @classmethod
    def from_json(cls, data: Dict) -> Optional['TranslateCommand']:
        try:
            payload = data['payload']
            return cls(
                text=payload['text'],
                to_language=payload.get('to_language', 'en')
            )
        except (KeyError, TypeError) as e:
            # Consider moving logger here or passing it
            print(f"Failed to parse TranslateCommand: {e}")
            return None
