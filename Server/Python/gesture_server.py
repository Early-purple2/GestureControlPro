# creation par early
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
import yaml

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
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
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
    def __init__(self, id: str, action: str, position: List[float], timestamp: float, metadata: Dict[str, Any] = None):
        self.id = id
        self.action = action
        self.position = position
        self.timestamp = timestamp
        self.metadata = metadata or {}

    @classmethod
    def from_json(cls, data: Dict) -> 'GestureCommand':
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
    def __init__(self, config: ServerConfig, performance_monitor: PerformanceMonitor, thread_pool: ThreadPoolExecutor):
        self.config = config
        self.screen_width, self.screen_height = pyautogui.size()
        self.last_position = [0, 0]
        self.position_history = []
        self.prediction_enabled = config.enable_prediction
        self.performance_monitor = performance_monitor
        self.thread_pool = thread_pool
        self.lock = asyncio.Lock()  # Pour protéger l'accès à last_position et position_history
        logger.info(f"🖥️ Résolution écran: {self.screen_width}x{self.screen_height}")

    async def execute_command(self, command: GestureCommand) -> bool:
        start_time = time.time()
        try:
            # Conversion position relative -> absolue
            # NOTE: Assumes client sends coordinates based on a 1920x1080 resolution.
            abs_x = int(command.position[0] * self.screen_width / 1920)
            abs_y = int(command.position[1] * self.screen_height / 1080)

            # Le lissage et la mise à jour de l'historique modifient un état partagé
            async with self.lock:
                if self.config.gesture_smoothing > 0:
                    abs_x, abs_y = self._smooth_position(abs_x, abs_y)

                # Exécution de l'action de manière non-bloquante
                await self._execute_action(command.action, abs_x, abs_y, command.metadata)

                # L'historique est utilisé pour la prédiction, doit être protégé
                self._update_position_history(abs_x, abs_y)

            return True

        except Exception as e:
            logger.error(f"❌ Erreur exécution commande {command.id}: {e}")
            return False
        finally:
            # Monitoring de la performance pour l'ensemble du traitement
            latency = time.time() - start_time
            if self.config.performance_logging:
                logger.debug(f"⚡ Commande {command.id} traitée en {latency*1000:.2f}ms")
            self.performance_monitor.record_command(latency)


    async def _execute_action(self, action: str, x: int, y: int, metadata: Dict) -> None:
        loop = asyncio.get_running_loop()

        # Toutes les actions pyautogui sont bloquantes et doivent être exécutées dans un thread pool
        if action == GestureAction.CLICK.value:
            await loop.run_in_executor(self.thread_pool, pyautogui.click, x, y, metadata.get('button', 'left'))
        elif action == GestureAction.DOUBLE_CLICK.value:
            await loop.run_in_executor(self.thread_pool, pyautogui.doubleClick, x, y, metadata.get('button', 'left'))
        elif action == GestureAction.DRAG.value:
            start = metadata.get('from', [x, y])
            end = metadata.get('to', [x, y])
            await loop.run_in_executor(self.thread_pool, pyautogui.dragTo, end[0], end[1], 0.001, 'left')
        elif action == GestureAction.SCROLL.value:
            direction = metadata.get('direction', 'up')
            amount = metadata.get('amount', 3)
            if direction in ('up', 'down'):
                scroll_func = pyautogui.scroll
                scroll_amount = amount if direction == 'up' else -amount
            else:
                scroll_func = pyautogui.hscroll
                scroll_amount = amount if direction == 'right' else -amount
            await loop.run_in_executor(self.thread_pool, scroll_func, scroll_amount, x, y)
        elif action == GestureAction.ZOOM.value:
            factor = metadata.get('factor', 1.0)
            scroll_amt = int((factor - 1.0) * 5)
            await loop.run_in_executor(self.thread_pool, pyautogui.keyDown, 'ctrl')
            await loop.run_in_executor(self.thread_pool, pyautogui.scroll, scroll_amt, x, y)
            await loop.run_in_executor(self.thread_pool, pyautogui.keyUp, 'ctrl')
        elif action == GestureAction.MOVE.value:
            if self.prediction_enabled:
                px, py = self._predict_next_position(x, y)
                await loop.run_in_executor(self.thread_pool, pyautogui.moveTo, px, py, 0.001)
            else:
                await loop.run_in_executor(self.thread_pool, pyautogui.moveTo, x, y, 0.001)
        elif action == GestureAction.KEY_PRESS.value:
            await loop.run_in_executor(self.thread_pool, pyautogui.press, metadata.get('key', 'space'))
        elif action == GestureAction.KEY_COMBO.value:
            await loop.run_in_executor(self.thread_pool, pyautogui.hotkey, *metadata.get('keys', []))

    def _smooth_position(self, x: int, y: int):
        # Cette méthode est maintenant appelée à l'intérieur d'un verrou
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

        p0 = self.position_history[-2]
        p1 = self.position_history[-1]

        dt = p1[2] - p0[2]
        if dt <= 1e-6:  # Éviter la division par zéro
            return x, y

        # Calcul de la vitesse
        vx = (p1[0] - p0[0]) / dt
        vy = (p1[1] - p0[1]) / dt

        # Extrapolation simple sur un court intervalle de temps (ex: 50ms)
        prediction_time = 0.05

        px = int(x + vx * prediction_time)
        py = int(y + vy * prediction_time)

        # S'assurer que les coordonnées prédites restent dans les limites de l'écran
        px = max(0, min(self.screen_width, px))
        py = max(0, min(self.screen_height, py))

        return px, py


class GestureServer:
    """Serveur principal multi-protocole"""

    def __init__(self, config: ServerConfig = None):
        self.config = config or ServerConfig()
        self.thread_pool = ThreadPoolExecutor(max_workers=self.config.thread_pool_size)
        # Le moniteur de performance est partagé entre le serveur et l'exécuteur
        self.performance_monitor = PerformanceMonitor()
        self.executor = GestureExecutor(self.config, self.performance_monitor, self.thread_pool)
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
            except Exception as e:
                logger.error(f"❌ Erreur inattendue dans le handler WebSocket: {e}", exc_info=True)
            finally:
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
            try:
                while True:
                    data = await r.read(self.config.buffer_size)
                    if not data:
                        break
                    await self._process_message(data)
            except ConnectionResetError:
                logger.warning("🔌 Connexion TCP réinitialisée par le client.")
            except Exception as e:
                logger.error(f"❌ Erreur TCP: {e}")
            finally:
                logger.info("🔌 TCP déconnecté")
        self.tcp_server = await asyncio.start_server(
            handler, self.config.host, self.config.tcp_port
        )
        logger.info(f"🔌 TCP sur {self.config.tcp_port}")

    async def _process_message(self, raw_data: bytes):
        try:
            message_str = raw_data.decode('utf-8')
            data = json.loads(message_str)

            if data.get('type') == 'gesture_command':
                command = GestureCommand.from_json(data)
                # L'exécution de la commande inclut déjà le monitoring de performance
                await self.executor.execute_command(command)
            # autres types (heartbeat, status...) peuvent être gérés ici
        except json.JSONDecodeError:
            logger.error("❌ Erreur de décodage JSON")
        except Exception as e:
            logger.error(f"❌ Erreur lors du traitement du message: {e}")

    async def _performance_logger(self):
        while True:
            await asyncio.sleep(5.0)
            # Utilise le moniteur de performance de l'exécuteur qui contient les vraies données
            stats = self.executor.performance_monitor.get_stats()
            logger.info(
                f"📊 Stats: {stats['commands_per_second']:.1f} cmd/s, "
                f"Latence Moy: {stats['avg_latency']*1000:.2f}ms, "
                f"Max: {stats['max_latency']*1000:.2f}ms"
            )


def setup_signal_handlers(server: GestureServer):
    def handler(sig, frame):
        logger.info("🛑 Signal reçu, arrêt serveur...")
        sys.exit(0)
    signal.signal(signal.SIGINT, handler)
    signal.signal(signal.SIGTERM, handler)


def load_config(path: str = 'config.yaml') -> ServerConfig:
    """Charge la configuration depuis un fichier YAML, avec des valeurs par défaut."""
    # Valeurs par défaut codées en dur
    defaults = {
        'network': {
            'websocket_port': 8080,
            'udp_port': 9090,
            'tcp_port': 7070,
            'host': "0.0.0.0",
            'max_connections': 10,
            'buffer_size': 8192,
        },
        'performance': {
            'thread_pool_size': 4,
            'enable_prediction': True,
            'gesture_smoothing': 0.7,
            'performance_logging': True,
            'command_timeout': 0.001,
            'heartbeat_interval': 1.0,
        }
    }

    try:
        with open(path, 'r') as f:
            user_config = yaml.safe_load(f)
            if user_config:
                # Fusionne les configurations utilisateur avec les défauts
                network_settings = {**defaults['network'], **user_config.get('network', {})}
                performance_settings = {**defaults['performance'], **user_config.get('performance', {})}

                logger.info(f"✅ Configuration chargée depuis '{path}'")
                return ServerConfig(
                    websocket_port=network_settings['websocket_port'],
                    udp_port=network_settings['udp_port'],
                    tcp_port=network_settings['tcp_port'],
                    host=network_settings['host'],
                    max_connections=network_settings['max_connections'],
                    buffer_size=network_settings['buffer_size'],
                    thread_pool_size=performance_settings['thread_pool_size'],
                    enable_prediction=performance_settings['enable_prediction'],
                    gesture_smoothing=performance_settings['gesture_smoothing'],
                    performance_logging=performance_settings['performance_logging'],
                    command_timeout=performance_settings['command_timeout'],
                    heartbeat_interval=performance_settings['heartbeat_interval'],
                )
    except FileNotFoundError:
        logger.warning(f"⚠️ Fichier de configuration '{path}' non trouvé. Utilisation de la configuration par défaut.")
    except yaml.YAMLError as e:
        logger.error(f"❌ Erreur de parsing YAML dans '{path}': {e}. Utilisation de la configuration par défaut.")
    except Exception as e:
        logger.error(f"❌ Erreur inattendue lors du chargement de la configuration: {e}. Utilisation de la configuration par défaut.")

    # Retourne la configuration par défaut en cas d'erreur ou de fichier non trouvé
    return ServerConfig()


async def main():
    config = load_config()
    server = GestureServer(config)
    setup_signal_handlers(server)
    logger.info(f"🚀 Démarrage GestureControl Pro Serveur avec {config.thread_pool_size} threads.")
    await server.start()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("👋 Serveur arrêté")

