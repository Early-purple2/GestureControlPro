import asyncio
import dataclasses
import json
import logging
import time
from typing import TYPE_CHECKING
import yaml

from aiohttp import web

# Use TYPE_CHECKING to avoid circular import issues at runtime
# The main gesture_server module will import this web_server,
# and this web_server needs type hints from gesture_server.
if TYPE_CHECKING:
    from .gesture_server import GestureServer

logger = logging.getLogger(__name__)

GESTURE_SERVER_KEY = web.AppKey('gesture_server', "GestureServer")


@web.middleware
async def auth_middleware(request: web.Request, handler):
    """AIOHTTP middleware to check for token authentication on API routes."""
    # Let non-API routes (like the main page) pass through
    if not request.path.startswith('/api/v1/'):
        return await handler(request)

    # Allow access if no token is configured on the server
    server: "GestureServer" = request.app[GESTURE_SERVER_KEY]
    if not server.config.secret_token:
        return await handler(request)

    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return web.json_response(
            {"status": "error", "message": "Authorization header missing or invalid"},
            status=401
        )

    token = auth_header.split(' ')[1]
    if token != server.config.secret_token:
        return web.json_response(
            {"status": "error", "message": "Invalid token"},
            status=403
        )

    # Token is valid, proceed with the request
    return await handler(request)


class WebServer:
    """
    Handles serving the web dashboard and the REST API for monitoring and configuration.
    """
    def __init__(self, gesture_server: "GestureServer"):
        self.gesture_server = gesture_server
        self.start_time = time.time()
        # Pass the middleware to the application
        self.app = web.Application(middlewares=[auth_middleware])
        # Store a reference to the gesture_server instance in the app's context
        # so the middleware can access it.
        self.app[GESTURE_SERVER_KEY] = self.gesture_server
        self._setup_routes()

    def _setup_routes(self):
        self.app.router.add_get("/", self.index)
        self.app.router.add_get("/gesture", self.gesture_control)
        self.app.router.add_get("/api/v1/status", self.get_status)
        self.app.router.add_get("/api/v1/config", self.get_config)
        self.app.router.add_put("/api/v1/config", self.put_config)
        self.app.router.add_get("/api/v1/metrics", self.get_metrics)

    async def index(self, request: web.Request):
        """Serves the main dashboard HTML file."""
        # The path is relative to where the server is run, which is Server/Python
        return web.FileResponse('./index.html')

    async def gesture_control(self, request: web.Request):
        """Serves the gesture control prototype HTML file."""
        return web.FileResponse('./gesture_control.html')

    async def get_status(self, request: web.Request):
        """Provides the current high-level status of the server."""
        stats = await self.gesture_server.performance_monitor.get_stats()
        status_data = {
            "status": "running" if self.gesture_server.running else "stopped",
            "version": self.gesture_server.config.version,
            "uptime": time.time() - self.start_time,
            "performance": {
                "commands_per_second": stats.get('commands_per_second'),
                "avg_latency_ms": stats.get('avg_latency_ms'),
            },
            "connected_clients": {
                "websocket": len(self.gesture_server.websocket_server.clients) if self.gesture_server.websocket_server else 0,
                "tcp": len(self.gesture_server.tcp_clients),
                "udp": "N/A" # UDP is connectionless, so client count is not applicable
            }
        }
        return web.json_response(status_data)

    async def get_config(self, request: web.Request):
        """Returns the current server configuration."""
        # Use dataclasses.asdict to convert the config object to a JSON-serializable dict
        return web.json_response(dataclasses.asdict(self.gesture_server.config))

    async def put_config(self, request: web.Request):
        """
        Updates server configuration in memory and persists it to config.yaml.
        """
        try:
            data = await request.json()
            current_config = self.gesture_server.config

            # Update the config object in memory
            for key, value in data.items():
                if hasattr(current_config, key):
                    setattr(current_config, key, value)

            # Now, persist the entire current configuration back to the file
            # Reconstruct the nested dictionary structure for the YAML file
            config_to_save = {
                'general': {
                    'version': current_config.version
                },
                'network': {
                    'websocket_port': current_config.websocket_port,
                    'udp_port': current_config.udp_port,
                    'tcp_port': current_config.tcp_port,
                    'dashboard_port': current_config.dashboard_port,
                    'host': current_config.host,
                    'max_connections': current_config.max_connections,
                    'buffer_size': current_config.buffer_size,
                },
                'performance': {
                    'thread_pool_size': current_config.thread_pool_size,
                    'enable_prediction': current_config.enable_prediction,
                    'gesture_smoothing': current_config.gesture_smoothing,
                    'performance_logging': current_config.performance_logging,
                    'command_timeout': current_config.command_timeout,
                    'heartbeat_interval': current_config.heartbeat_interval,
                },
                'security': {
                    'secret_token': current_config.secret_token,
                }
            }

            with open('config.yaml', 'w') as f:
                yaml.dump(config_to_save, f, default_flow_style=False, sort_keys=False)

            logger.info(f"Configuration updated and saved via API: {data}")

            return web.json_response({"status": "ok", "message": "Config updated and saved."})
        except json.JSONDecodeError:
            return web.json_response({"status": "error", "message": "Invalid JSON format."}, status=400)
        except Exception as e:
            logger.error(f"Failed to update configuration: {e}", exc_info=True)
            return web.json_response({"status": "error", "message": f"Failed to update config: {e}"}, status=500)

    async def get_metrics(self, request: web.Request):
        """Returns detailed performance metrics."""
        # For now, this is the same as the performance part of the status endpoint
        stats = await self.gesture_server.performance_monitor.get_stats()
        return web.json_response(stats)
