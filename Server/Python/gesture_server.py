#!/usr/bin/env python3
"""
High-Performance Gesture Control Server
Utilizes the latest Python technologies for minimal latency.
Supports WebSocket, UDP, and TCP with optimized threading.
"""

import asyncio
import json
import time
import threading
import logging
from dataclasses import dataclass
from typing import Dict, List, Any, Optional
from enum import Enum
import signal
import sys
from concurrent.futures import ThreadPoolExecutor
import yaml

# High-performance event loop
try:
    import uvloop
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
except ImportError:
    pass

# System control imports
import websockets
from websockets.server import WebSocketServerProtocol
from websockets.exceptions import ConnectionClosed

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class ServerConfig:
    """Server configuration with optimizations."""
    websocket_port: int = 8080
    udp_port: int = 9090
    tcp_port: int = 7070
    host: str = "0.0.0.0"
    max_connections: int = 10
    heartbeat_interval: float = 1.0
    command_timeout: float = 0.001  # 1ms max per command
    buffer_size: int = 8192
    thread_pool_size: int = 4
    enable_prediction: bool = True
    gesture_smoothing: float = 0.7
    performance_logging: bool = True
    secret_token: Optional[str] = None


class GestureAction(Enum):
    """Supported gesture actions."""
    CLICK = "click"
    DOUBLE_CLICK = "double_click"
    DRAG = "drag"
    SCROLL = "scroll"
    ZOOM = "zoom"
    MOVE = "move"
    KEY_PRESS = "key_press"
    KEY_COMBO = "key_combo"


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
            logger.error(f"Failed to parse GestureCommand: {e}")
            return None


class PerformanceMonitor:
    """Real-time performance monitor."""
    def __init__(self):
        self.commands_processed = 0
        self.total_latency = 0.0
        self.max_latency = 0.0
        self.min_latency = float('inf')
        self.start_time = time.time()
        self.lock = asyncio.Lock()

    async def record_command(self, latency: float):
        async with self.lock:
            self.commands_processed += 1
            self.total_latency += latency
            self.max_latency = max(self.max_latency, latency)
            self.min_latency = min(self.min_latency, latency)

    async def get_stats(self) -> Dict[str, float]:
        async with self.lock:
            if self.commands_processed == 0:
                return {
                    'commands_per_second': 0.0,
                    'avg_latency_ms': 0.0,
                    'max_latency_ms': 0.0,
                    'min_latency_ms': 0.0
                }
            elapsed = time.time() - self.start_time
            return {
                'commands_per_second': self.commands_processed / elapsed,
                'avg_latency_ms': (self.total_latency / self.commands_processed) * 1000,
                'max_latency_ms': self.max_latency * 1000,
                'min_latency_ms': (self.min_latency if self.min_latency != float('inf') else 0.0) * 1000
            }


class SystemController:
    """Abstracts system control actions to allow for testability."""
    def __init__(self, thread_pool: ThreadPoolExecutor):
        self.thread_pool = thread_pool
        self.loop = asyncio.get_running_loop()
        # Import and configure pyautogui here to avoid import errors in test environments
        import pyautogui
        self.pyautogui = pyautogui
        self.pyautogui.FAILSAFE = False
        self.pyautogui.PAUSE = 0.001

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

    async def move_to(self, x, y, duration):
        await self.execute(self.pyautogui.moveTo, x, y, duration=duration)

    async def press(self, key):
        await self.execute(self.pyautogui.press, key)

    async def hotkey(self, *keys):
        await self.execute(self.pyautogui.hotkey, *keys)

    def size(self):
        return self.pyautogui.size()


class GestureExecutor:
    """Fast gesture executor with prediction and command queuing."""
    def __init__(self, config: ServerConfig, performance_monitor: PerformanceMonitor, controller: SystemController):
        self.config = config
        self.performance_monitor = performance_monitor
        self.controller = controller

        self.screen_width, self.screen_height = self.controller.size()
        self.last_position = [0, 0]
        self.position_history = []
        self.command_queue = asyncio.Queue(maxsize=100)
        self.worker_task = asyncio.create_task(self._command_worker())

        logger.info(f"🖥️ Screen resolution: {self.screen_width}x{self.screen_height}")

    async def submit_command(self, command: GestureCommand):
        """Submits a command to the execution queue."""
        try:
            self.command_queue.put_nowait(command)
        except asyncio.QueueFull:
            logger.warning("Command queue is full, dropping command.")

    async def _command_worker(self):
        """Processes commands from the queue one by one."""
        logger.info("Gesture executor worker started.")
        while True:
            command = await self.command_queue.get()
            start_time = time.time()
            try:
                await self._execute_command_internal(command)
            except Exception as e:
                logger.error(f"❌ Error executing command {command.id}: {e}", exc_info=True)
            finally:
                latency = time.time() - start_time
                if self.config.performance_logging:
                    logger.debug(f"⚡ Command {command.id} processed in {latency*1000:.2f}ms")
                await self.performance_monitor.record_command(latency)
                self.command_queue.task_done()

    async def _execute_command_internal(self, command: GestureCommand):
        # Protocol definition: client MUST send normalized coordinates (0.0 to 1.0).
        # This is more robust than assuming a fixed client resolution.
        abs_x = int(command.position[0] * self.screen_width)
        abs_y = int(command.position[1] * self.screen_height)

        # Clamp values to be safe
        abs_x = max(0, min(self.screen_width, abs_x))
        abs_y = max(0, min(self.screen_height, abs_y))

        if self.config.gesture_smoothing > 0:
            abs_x, abs_y = self._smooth_position(abs_x, abs_y)

        await self._execute_action(command.action, abs_x, abs_y, command.metadata)

        self._update_position_history(abs_x, abs_y)

    async def _execute_action(self, action: str, x: int, y: int, metadata: Dict):
        if action == GestureAction.CLICK.value:
            await self.controller.click(x, y, metadata.get('button', 'left'))
        elif action == GestureAction.DOUBLE_CLICK.value:
            await self.controller.double_click(x, y, metadata.get('button', 'left'))
        elif action == GestureAction.DRAG.value:
            end = metadata.get('to', [x, y])
            await self.controller.drag_to(end[0], end[1], 0.001)
        elif action == GestureAction.SCROLL.value:
            direction = metadata.get('direction', 'up')
            amount = metadata.get('amount', 3)
            if direction in ('up', 'down'):
                await self.controller.scroll(amount if direction == 'up' else -amount, x, y)
            else:
                await self.controller.hscroll(amount if direction == 'right' else -amount, x, y)
        elif action == GestureAction.ZOOM.value:
            factor = metadata.get('factor', 1.0)
            scroll_amt = int((factor - 1.0) * 5)
            await self.controller.key_down('ctrl')
            await self.controller.scroll(scroll_amt, x, y)
            await self.controller.key_up('ctrl')
        elif action == GestureAction.MOVE.value:
            if self.config.enable_prediction:
                px, py = self._predict_next_position(x, y)
                await self.controller.move_to(px, py, 0.001)
            else:
                await self.controller.move_to(x, y, 0.001)
        elif action == GestureAction.KEY_PRESS.value:
            await self.controller.press(metadata.get('key', 'space'))
        elif action == GestureAction.KEY_COMBO.value:
            await self.controller.hotkey(*metadata.get('keys', []))

    def _smooth_position(self, x: int, y: int):
        alpha = 1.0 - self.config.gesture_smoothing
        sx = int(alpha * x + (1 - alpha) * self.last_position[0])
        sy = int(alpha * y + (1 - alpha) * self.last_position[1])
        self.last_position = [sx, sy]
        return sx, sy

    def _update_position_history(self, x: int, y: int):
        self.position_history.append((x, y, time.time()))
        if len(self.position_history) > 10:
            self.position_history.pop(0)

    def _predict_next_position(self, x: int, y: int):
        if len(self.position_history) < 2:
            return x, y

        p0 = self.position_history[-2]
        p1 = self.position_history[-1]

        dt = p1[2] - p0[2]
        if dt <= 1e-6:  # Avoid division by zero
            return x, y

        vx = (p1[0] - p0[0]) / dt
        vy = (p1[1] - p0[1]) / dt

        prediction_time = 0.05  # Simple extrapolation 50ms into the future
        px = int(x + vx * prediction_time)
        py = int(y + vy * prediction_time)

        px = max(0, min(self.screen_width, px))
        py = max(0, min(self.screen_height, py))
        return px, py


from web_server import WebServer
from aiohttp import web


class GestureServer:
    """Main multi-protocol server."""

    def __init__(self, config: ServerConfig = None):
        self.config = config or load_config()
        self.thread_pool = ThreadPoolExecutor(max_workers=self.config.thread_pool_size)
        self.performance_monitor = PerformanceMonitor()
        controller = SystemController(self.thread_pool)
        self.executor = GestureExecutor(self.config, self.performance_monitor, controller)

        self.websocket_server = None
        self.udp_transport = None
        self.tcp_server = None
        self.web_runner = None
        self.running = False

        # The WebServer needs a reference back to this instance to access metrics, etc.
        self.web_server = WebServer(self)

    async def start(self):
        self.running = True

        # Setup and start the web server runner
        self.web_runner = web.AppRunner(self.web_server.app)
        await self.web_runner.setup()
        web_site = web.TCPSite(self.web_runner, self.config.host, 8000) # Hardcode port 8000 for dashboard

        tasks = [
            self._start_websocket(),
            self._start_udp(),
            self._start_tcp(),
            web_site.start(),
            self._performance_logger()
        ]
        logger.info("✅ All servers started (including web server on port 8000)")
        await asyncio.gather(*tasks)

    async def stop(self):
        self.running = False
        logger.info("🛑 Stopping servers...")

        # Stop application servers
        if self.websocket_server:
            self.websocket_server.close()
            await self.websocket_server.wait_closed()
        if self.udp_transport:
            self.udp_transport.close()
        if self.tcp_server:
            self.tcp_server.close()
            await self.tcp_server.wait_closed()

        # Stop web server
        if self.web_runner:
            await self.web_runner.cleanup()

        self.executor.worker_task.cancel()
        self.thread_pool.shutdown(wait=False)
        logger.info("✅ Servers stopped.")

    async def _start_websocket(self):
        async def handler(websocket):
            """Handles an incoming WebSocket connection, including authentication."""
            # --- Authentication Check ---
            if self.config.secret_token:
                try:
                    # Token is expected as a query parameter, e.g., ws://.../?token=SECRET
                    token = websocket.request_headers.get('Sec-WebSocket-Protocol')
                    if token != self.config.secret_token:
                        logger.warning(f"🔒 WebSocket connection denied from {websocket.remote_address}: Invalid token.")
                        # Closing the connection gracefully
                        await websocket.close(code=1008, reason="Invalid token")
                        return
                except Exception:
                    logger.warning(f"🔒 WebSocket connection denied from {websocket.remote_address}: Token check failed.")
                    await websocket.close(code=1008, reason="Invalid token")
                    return

            logger.info(f"🔗 WebSocket connected from {websocket.remote_address}")
            try:
                async for msg in websocket:
                    await self._process_message(msg, websocket)
            except ConnectionClosed:
                logger.info(f"🔌 WebSocket disconnected from {websocket.remote_address}")
            except Exception as e:
                logger.error(f"❌ Unexpected WebSocket error: {e}", exc_info=True)

        self.websocket_server = await websockets.serve(
            handler, self.config.host, self.config.websocket_port,
            max_size=self.config.buffer_size, compression=None,
            # Pass the token as a subprotocol for the client to use
            subprotocols=["token," + self.config.secret_token] if self.config.secret_token else None
        )
        logger.info(f"🌐 WebSocket server listening on {self.config.host}:{self.config.websocket_port}")

    async def _start_udp(self):
        class UDPProtocol(asyncio.DatagramProtocol):
            def __init__(self, server_instance):
                self.server = server_instance
            def connection_made(self, transport):
                self.server.udp_transport = transport
            def datagram_received(self, data, addr):
                asyncio.create_task(self.server._process_message(data))
            def error_received(self, exc):
                logger.error(f"📡 UDP error: {exc}")

        loop = asyncio.get_running_loop()
        await loop.create_datagram_endpoint(
            lambda: UDPProtocol(self), local_addr=(self.config.host, self.config.udp_port)
        )
        logger.info(f"📡 UDP server listening on {self.config.host}:{self.config.udp_port}")

    async def _start_tcp(self):
        async def handler(reader, writer):
            addr = writer.get_extra_info('peername')
            logger.info(f"🔗 TCP connected from {addr}")
            try:
                while True:
                    data = await reader.read(self.config.buffer_size)
                    if not data:
                        break
                    await self._process_message(data)
            except ConnectionResetError:
                logger.warning(f"🔌 TCP connection reset by {addr}.")
            except Exception as e:
                logger.error(f"❌ TCP Error from {addr}: {e}")
            finally:
                logger.info(f"🔌 TCP disconnected from {addr}")
                writer.close()

        self.tcp_server = await asyncio.start_server(
            handler, self.config.host, self.config.tcp_port
        )
        logger.info(f"🔌 TCP server listening on {self.config.host}:{self.config.tcp_port}")

    async def _process_message(self, raw_data: bytes, ws: Optional[WebSocketServerProtocol] = None):
        try:
            data = json.loads(raw_data)
            if data.get('type') == 'gesture_command':
                command = GestureCommand.from_json(data)
                if command:
                    await self.executor.submit_command(command)
                elif ws:
                    await ws.send(json.dumps({"error": "Invalid command format", "id": data.get("id")}))
            # Other message types (heartbeat, status...) can be handled here
        except json.JSONDecodeError:
            logger.error("❌ JSON decoding error")
            if ws:
                await ws.send(json.dumps({"error": "Invalid JSON format"}))
        except Exception as e:
            logger.error(f"❌ Error processing message: {e}", exc_info=True)
            if ws:
                await ws.send(json.dumps({"error": "Internal server error"}))

    async def _performance_logger(self):
        while self.running:
            await asyncio.sleep(5.0)
            if not self.running: break
            stats = await self.performance_monitor.get_stats()
            logger.info(
                f"📊 Stats: {stats['commands_per_second']:.1f} cmd/s, "
                f"Avg Latency: {stats['avg_latency_ms']:.2f}ms, "
                f"Max: {stats['max_latency_ms']:.2f}ms"
            )


def load_config(path: str = 'config.yaml') -> ServerConfig:
    """Loads configuration from a YAML file, with fallback to defaults."""
    defaults = {
        'network': {
            'websocket_port': 8080, 'udp_port': 9090, 'tcp_port': 7070,
            'host': "0.0.0.0", 'max_connections': 10, 'buffer_size': 8192,
        },
        'performance': {
            'thread_pool_size': 4, 'enable_prediction': True, 'gesture_smoothing': 0.7,
            'performance_logging': True, 'command_timeout': 0.001, 'heartbeat_interval': 1.0,
        },
        'security': {
            'secret_token': None,
        }
    }
    try:
        with open(path, 'r') as f:
            user_config = yaml.safe_load(f) or {}

        # Deep merge user config with defaults
        network_settings = {**defaults['network'], **user_config.get('network', {})}
        performance_settings = {**defaults['performance'], **user_config.get('performance', {})}
        security_settings = {**defaults['security'], **user_config.get('security', {})}

        logger.info(f"✅ Configuration loaded from '{path}'")
        return ServerConfig(**network_settings, **performance_settings, **security_settings)

    except FileNotFoundError:
        logger.warning(f"⚠️ Config file '{path}' not found. Using default configuration.")
    except (yaml.YAMLError, TypeError) as e:
        logger.error(f"❌ Error parsing YAML in '{path}': {e}. Using default configuration.")

    # Combine all default dictionaries for the final fallback
    return ServerConfig(**defaults['network'], **defaults['performance'], **defaults['security'])


async def main():
    server = GestureServer()

    def signal_handler():
        logger.info("🛑 Signal received, shutting down...")
        asyncio.create_task(server.stop())

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(sig, signal_handler)

    try:
        logger.info(f"🚀 Starting GestureControl Pro Server with {server.config.thread_pool_size} threads.")
        await server.start()
    except asyncio.CancelledError:
        pass
    finally:
        if server.running:
            await server.stop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        logger.info("👋 Server shut down.")

