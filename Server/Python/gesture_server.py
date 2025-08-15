#!/usr/bin/env python3
"""
High-Performance Gesture Control Server
Utilizes the latest Python technologies for minimal latency.
Supports WebSocket, UDP, and TCP with optimized threading.
"""

import asyncio
import json
import time
import logging
import signal
import sys
import socket
import ssl
from typing import Optional
from concurrent.futures import ThreadPoolExecutor
import yaml

# High-performance event loop
try:
    import uvloop
    asyncio.set_event_loop_policy(uvloop.EventLoopPolicy())
except ImportError:
    pass

import websockets
from websockets.asyncio.server import ServerConnection
from websockets.exceptions import ConnectionClosed
from aiohttp import web

# Local core modules
from core.models import ServerConfig, GestureCommand, TLSConfig
from core.performance import PerformanceMonitor
from core.controller import SystemController
from core.executor import GestureExecutor
from web_server import WebServer


# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


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
        self.tcp_clients = set()
        self.web_runner = None
        self.running = False

        # The WebServer needs a reference back to this instance to access metrics, etc.
        self.web_server = WebServer(self)

    async def start(self):
        self.running = True
        ssl_context = None

        if self.config.tls.enabled:
            try:
                ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                ssl_context.load_cert_chain(self.config.tls.cert_path, self.config.tls.key_path)
                logger.info("🔒 TLS is enabled. Servers will use wss:// and secure TCP.")
            except (FileNotFoundError, ssl.SSLError) as e:
                logger.error(f"❌ Failed to load TLS certificates: {e}. Disabling TLS.")
                ssl_context = None
        else:
            logger.warning("⚠️ TLS is disabled. Communication will be unencrypted.")

        # Setup and start the web server runner
        self.web_runner = web.AppRunner(self.web_server.app)
        await self.web_runner.setup()
        web_site = web.TCPSite(self.web_runner, self.config.host, self.config.dashboard_port)

        tasks = [
            self._start_websocket(ssl_context),
            self._start_udp(),
            self._start_tcp(ssl_context),
            web_site.start(),
            self._performance_logger()
        ]
        logger.info(f"✅ All servers started (including web server on port {self.config.dashboard_port})")
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

    async def _start_websocket(self, ssl_context: Optional[ssl.SSLContext] = None):
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
                # Set TCP_NODELAY for lower latency
                sock = websocket.transport.get_extra_info('socket')
                if sock is not None:
                    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

                async for msg in websocket:
                    await self._process_message(msg, websocket)
            except ConnectionClosed:
                logger.info(f"🔌 WebSocket disconnected from {websocket.remote_address}")
            except Exception as e:
                logger.error(f"❌ Unexpected WebSocket error: {e}", exc_info=True)

        self.websocket_server = await websockets.serve(
            handler, self.config.host, self.config.websocket_port,
            ssl=ssl_context,
            max_size=self.config.buffer_size,
            compression=None,  # Compression disabled for lower latency
            max_queue=32,      # Limit queue size to prevent backpressure
            reuse_port=True,   # Allows multiple server processes on the same port
            # Pass the token as a subprotocol for the client to use
            subprotocols=["token", self.config.secret_token] if self.config.secret_token else None
        )
        protocol = "wss" if ssl_context else "ws"
        logger.info(f"🌐 WebSocket server ({protocol}) listening on {self.config.host}:{self.config.websocket_port}")

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
            lambda: UDPProtocol(self), local_addr=(self.config.host, self.config.udp_port),
            reuse_port=True
        )
        logger.info(f"📡 UDP server listening on {self.config.host}:{self.config.udp_port}")

    async def _start_tcp(self, ssl_context: Optional[ssl.SSLContext] = None):
        async def handler(reader, writer):
            addr = writer.get_extra_info('peername')
            logger.info(f"🔗 TCP connected from {addr}")
            self.tcp_clients.add(writer)
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
                self.tcp_clients.remove(writer)
                writer.close()

        self.tcp_server = await asyncio.start_server(
            handler, self.config.host, self.config.tcp_port,
            ssl=ssl_context
        )
        protocol = "Secure TCP" if ssl_context else "TCP"
        logger.info(f"🔌 {protocol} server listening on {self.config.host}:{self.config.tcp_port}")

    async def _process_message(self, raw_data: bytes, ws: Optional[ServerConnection] = None):
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
        'general': {
            'version': '1.0.0',
        },
        'network': {
            'websocket_port': 8080, 'udp_port': 9090, 'tcp_port': 7070,
            'dashboard_port': 8000, 'host': "0.0.0.0", 'max_connections': 10,
            'buffer_size': 8192,
        },
        'performance': {
            'thread_pool_size': 4, 'enable_prediction': True, 'gesture_smoothing': 0.7,
            'performance_logging': True, 'command_timeout': 0.001, 'heartbeat_interval': 1.0,
        },
        'security': {
            'secret_token': None,
            'tls': {
                'enabled': False,
                'cert_path': 'certs/cert.pem',
                'key_path': 'certs/key.pem',
            }
        }
    }
    try:
        with open(path, 'r') as f:
            user_config = yaml.safe_load(f) or {}

        # Deep merge user config with defaults
        general_settings = {**defaults['general'], **user_config.get('general', {})}
        network_settings = {**defaults['network'], **user_config.get('network', {})}
        performance_settings = {**defaults['performance'], **user_config.get('performance', {})}

        # Special handling for nested security settings
        security_defaults = defaults['security']
        user_security = user_config.get('security', {})
        tls_defaults = security_defaults['tls']
        user_tls = user_security.get('tls', {})

        tls_config = TLSConfig(
            enabled=user_tls.get('enabled', tls_defaults['enabled']),
            cert_path=user_tls.get('cert_path', tls_defaults['cert_path']),
            key_path=user_tls.get('key_path', tls_defaults['key_path']),
        )

        security_settings = {
            'secret_token': user_security.get('secret_token', security_defaults['secret_token']),
            'tls': tls_config
        }

        logger.info(f"✅ Configuration loaded from '{path}'")
        return ServerConfig(
            **general_settings,
            **network_settings,
            **performance_settings,
            **security_settings
        )

    except FileNotFoundError:
        logger.warning(f"⚠️ Config file '{path}' not found. Using default configuration.")
    except (yaml.YAMLError, TypeError) as e:
        logger.error(f"❌ Error parsing YAML in '{path}': {e}. Using default configuration.")

    # This part is for when the file is not found or invalid
    return ServerConfig(
        **defaults['general'],
        **defaults['network'],
        **defaults['performance'],
        secret_token=defaults['security']['secret_token'],
        tls=TLSConfig(**defaults['security']['tls'])
    )


async def main():
    logger.info("Starting main function")
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
