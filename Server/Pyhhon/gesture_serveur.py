#!/usr/bin/env python3
"""
Serveur de Contrôle Gestuel Ultra-Performant
Utilise les dernières technologies Python pour une latence minimale
Support WebSocket, UDP, TCP avec threading optimisé
"""

import asyncio
import json
import time
import threading
import logging
from dataclasses import dataclass, asdict
from typing import Dict, List, Any
from enum import Enum
import signal
import sys
from concurrent.futures import ThreadPoolExecutor

# Performant event loop
import uvloop  # Pour performance async optimisée
asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())

# Imports pour contrôle système
import pyautogui
import websockets
import socket
import struct

# Configuration PyAutoGUI pour performance maximale
pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0.001  # Latence minimale entre commandes

# Configuration logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('gesture_server.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


@dataclass
class ServerConfig:
    """Configuration du serveur avec optimisations"""
    websocket_port: int = 8080
    udp_port: int = 9090
    tcp_port: int = 7070
    host: str = "0.0.0.0"
    max_connections: int = 10
    heartbeat_interval: float = 1.0
    command_timeout: float = 0.001  # 1ms max par commande
    buffer_size: int = 8192
    thread_pool_size: int = 4
    enable_prediction: bool = True
    gesture_smoothing: float = 0.7
    performance_logging: bool = True


class GestureAction(Enum):
    """Actions de geste supportées"""
    CLICK = "click"
    DOUBLE_CLICK = "double_click"
    DRAG = "drag"
    SCROLL = "scroll"
    ZOOM = "zoom"
    MOVE = "move"
    KEY_PRESS = "key_press"
    KEY_COMBO = "key_combo"


class GestureCommand:
    """Commande de geste avec métadonnées performance"""
    def __init__(self, id: str, action: str, position: List[float], timestamp: float, meta Dict[str, Any]=None):
        self.id = id
        self.action = action
        self.position = position
        self.timestamp = timestamp
        self.metadata = metadata or {}

    @classmethod
    def from_json(cls,  Dict) -> 'GestureCommand':
        payload = data.get('payload', {})
        return cls(
            id=data.get('id', ''),
            action=payload.get('action', ''),
            position=payload.get('position', [0, 0]),
            timestamp=payload.get('timestamp', time.time()),
            metadata=payload.get('metadata', {})
        )


class PerformanceMonitor:
    """Moniteur de performance en temps réel"""
    def __init__(self):
        self.commands_processed = 0
        self.total_latency = 0.0
        self.max_latency = 0.0
        self.min_latency = float('inf')
        self.start_time = time.time()
        self.lock = threading.Lock()

    def record_command(self, latency: float):
        with self.lock:
            self.commands_processed += 1
            self.total_latency += latency
            self.max_latency = max(self.max_latency, latency)
            self.min_latency = min(self.min_latency, latency)

    def get_stats(self) -> Dict[str, float]:
        with self.lock:
            if self.commands_processed == 0:
                return {
                    'commands_per_second': 0.0,
                    'avg_latency': 0.0,
                    'max_latency': 0.0,
                    'min_latency': 0.0
                }
            elapsed = time.time() - self.start_time
            return {
                'commands_per_second': self.commands_processed / elapsed,
                'avg_latency': self.total_latency / self.commands_processed,
                'max_latency': self.max_latency,
                'min_latency': self.min_latency if self.min_latency != float('inf') else 0.0
            }


class GestureExecutor:
    """Exécuteur de gestes ultra-rapide avec prédiction"""
    def __init__(self, config: ServerConfig):
        self.config = config
        self.screen_width, self.screen_height = pyautogui.size()
        self.last_position = [0, 0]
        self.position_history = []
        self.prediction_enabled = config.enable_prediction
        self.performance_monitor = PerformanceMonitor()
        logger.info(f"🖥️ Résolution écran: {self.screen_width}x{self.screen_height}")

    async def execute_command(self, command: GestureCommand) -> bool:
        start = time.time()
        try:
            # Conversion position relative -> absolue
            abs_x = int(command.position[0] * self.screen_width / 1920)
            abs_y = int(command.position[1] * self.screen_height / 1080)

            # Lissage
            if self.config.gesture_smoothing > 0:
                abs_x, abs_y = self._smooth_position(abs_x, abs_y)

            # Exécution
            await self._execute_action(command.action, abs_x, abs_y, command.metadata)

            # Historique & monitoring
            self._update_position_history(abs_x, abs_y)
            latency = time.time() - start
            if self.config.performance_logging:
                logger.debug(f"⚡ Commande {command.id} exécutée en {latency*1000:.2f}ms")
            self.performance_monitor.record_command(latency)
            return True

        except Exception as e:
            logger.error(f"❌ Erreur exécution commande {command.id}: {e}")
            return False

    async def _execute_action(self, action: str, x: int, y: int, meta Dict) -> None:
        if action == GestureAction.CLICK.value:
            pyautogui.click(x, y, button=metadata.get('button', 'left'))
        elif action == GestureAction.DOUBLE_CLICK.value:
            pyautogui.doubleClick(x, y, button=metadata.get('button', 'left'))
        elif action == GestureAction.DRAG.value:
            start = metadata.get('from', [x, y])
            end = metadata.get('to', [x, y])
            pyautogui.dragTo(end[0], end[1], duration=0.001, button='left')
        elif action == GestureAction.SCROLL.value:
            dir = metadata.get('direction', 'up')
            amount = metadata.get('amount', 3)
            if dir in ('up', 'down'):
                pyautogui.scroll(amount if dir == 'up' else -amount, x=x, y=y)
            else:
                pyautogui.hscroll(amount if dir == 'right' else -amount, x=x, y=y)
        elif action == GestureAction.ZOOM.value:
            factor = metadata.get('factor', 1.0)
            pyautogui.keyDown('ctrl')
            scroll_amt = int((factor - 1.0) * 5)
            pyautogui.scroll(scroll_amt, x=x, y=y)
            pyautogui.keyUp('ctrl')
        elif action == GestureAction.MOVE.value:
            if self.prediction_enabled:
                px, py = self._predict_next_position(x, y)
                pyautogui.moveTo(px, py, duration=0.001)
            else:
                pyautogui.moveTo(x, y, duration=0.001)
        elif action == GestureAction.KEY_PRESS.value:
            pyautogui.press(metadata.get('key', 'space'))
        elif action == GestureAction.KEY_COMBO.value:
            pyautogui.hotkey(*metadata.get('keys', []))

    def _smooth_position(self, x: int, y: int):
        alpha = 1.0 - self.config.gesture_smoothing
        sx = int(alpha * x + (1-alpha) * self.last_position[0])
        sy = int(alpha * y + (1-alpha) * self.last_position[1])
        self.last_position = [sx, sy]
        return sx, sy

    def _update_position_history(self, x: int, y: int):
        self.position_history.append((x, y, time.time()))
        if len(self.position_history) > 10:
            self.position_history.pop(0)

    def _predict_next_position(self, x: int, y: int):
        if len(self.position_history) < 2:
            return x, y
        recent = self.position_history[-2:]
        dt = recent[1][2] - recent[2]
        if dt <= 0:
            return x, y
        vx = (recent[1] - recent) / dt
        vy = (recent[1][1] - recent[1]) / dt
        t = 0.05
        px = max(0, min(self.screen_width, int(x + vx*t)))
        py = max(0, min(self.screen_height, int(y + vy*t)))
        return px, py


class GestureServer:
    """Serveur principal multi-protocole"""

    def __init__(self, config: ServerConfig = None):
        self.config = config or ServerConfig()
        self.executor = GestureExecutor(self.config)
        self.performance_monitor = PerformanceMonitor()
        self.thread_pool = ThreadPoolExecutor(max_workers=self.config.thread_pool_size)
        self.websocket_server = None
        self.udp_transport = None
        self.tcp_server = None

    async def start(self):
        tasks = [
            self._start_websocket(),
            self._start_udp(),
            self._start_tcp(),
            self._performance_logger()
        ]
        logger.info("✅ Tous les serveurs démarrés")
        await asyncio.gather(*tasks)

    async def _start_websocket(self):
        async def handler(ws, path):
            logger.info("🔗 WebSocket connecté")
            try:
                async for msg in ws:
                    await self._process_message(msg)
            except:
                pass
            logger.info("🔌 WebSocket déconnecté")

        self.websocket_server = await websockets.serve(
            handler, self.config.host, self.config.websocket_port,
            max_size=self.config.buffer_size, compression=None
        )
        logger.info(f"🌐 WS sur {self.config.websocket_port}")

    async def _start_udp(self):
        loop = asyncio.get_running_loop()
        self.udp_transport, _ = await loop.create_datagram_endpoint(
            lambda: self, local_addr=(self.config.host, self.config.udp_port)
        )
        logger.info(f"📡 UDP sur {self.config.udp_port}")

    def connection_made(self, transport):
        pass

    def datagram_received(self, data, addr):
        asyncio.create_task(self._process_message(data))

    async def _start_tcp(self):
        async def handler(r, w):
            logger.info("🔗 TCP connecté")
            while True:
                data = await r.read(self.config.buffer_size)
                if not 
                    break
                await self._process_message(data)
            logger.info("🔌 TCP déconnecté")
        self.tcp_server = await asyncio.start_server(
            handler, self.config.host, self.config.tcp_port
        )
        logger.info(f"🔌 TCP sur {self.config.tcp_port}")

    async def _process_message(self, raw):
        start = time.time()
        try:
            msg = raw.decode() if isinstance(raw, (bytes, bytearray)) else raw
            data = json.loads(msg)
            if data.get('type') == 'gesture_command':
                cmd = GestureCommand.from_json(data)
                await self.executor.execute_command(cmd)
            # autres types (heartbeat, status...) ignorés ici
        except Exception as e:
            logger.error(f"❌ Traitement message: {e}")
        finally:
            latency = time.time() - start
            self.performance_monitor.record_command(latency)

    async def _performance_logger(self):
        while True:
            await asyncio.sleep(5.0)
            stats = self.performance_monitor.get_stats()
            logger.info(
                f"📊 {stats['commands_per_second']:.1f} cmd/s, "
                f"lat moy {stats['avg_latency']*1000:.2f}ms"
            )


def setup_signal_handlers(server: GestureServer):
    def handler(sig, frame):
        logger.info("🛑 Signal reçu, arrêt serveur...")
        sys.exit(0)
    signal.signal(signal.SIGINT, handler)
    signal.signal(signal.SIGTERM, handler)


async def main():
    config = ServerConfig()
    server = GestureServer(config)
    setup_signal_handlers(server)
    logger.info("🚀 Démarrage GestureControl Pro Serveur")
    await server.start()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("👋 Serveur arrêté")

