import asyncio
import dataclasses
import time
from typing import TYPE_CHECKING

from aiohttp import web

# Use TYPE_CHECKING to avoid circular import issues at runtime
# The main gesture_server module will import this web_server,
# and this web_server needs type hints from gesture_server.
if TYPE_CHECKING:
    from .gesture_server import GestureServer, ServerConfig


@web.middleware
async def auth_middleware(request: web.Request, handler):
    """AIOHTTP middleware to check for token authentication on API routes."""
    # Let non-API routes (like the main page) pass through
    if not request.path.startswith('/api/v1/'):
        return await handler(request)

    # Allow access if no token is configured on the server
    server: "GestureServer" = request.app['gesture_server']
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
        self.app['gesture_server'] = self.gesture_server
        self._setup_routes()

    def _setup_routes(self):
        self.app.router.add_get("/", self.index)
        self.app.router.add_get("/api/v1/status", self.get_status)
        self.app.router.add_get("/api/v1/config", self.get_config)
        self.app.router.add_put("/api/v1/config", self.put_config)
        self.app.router.add_get("/api/v1/metrics", self.get_metrics)

    async def index(self, request: web.Request):
        """Serves the main dashboard HTML file."""
        # The path is relative to where the server is run, which is Server/Python
        return web.FileResponse('./index.html')

    async def get_status(self, request: web.Request):
        """Provides the current high-level status of the server."""
        stats = await self.gesture_server.performance_monitor.get_stats()
        status_data = {
            "status": "running" if self.gesture_server.running else "stopped",
            "version": "1.0.0",  # Hardcoded for now, could be dynamic
            "uptime": time.time() - self.start_time,
            "performance": {
                "commands_per_second": stats.get('commands_per_second'),
                "avg_latency_ms": stats.get('avg_latency_ms'),
            },
            "connected_clients": {
                 # This is a placeholder, real implementation would need tracking
                "websocket": len(self.gesture_server.websocket_server.clients) if self.gesture_server.websocket_server else 0,
                "tcp": 0, # Placeholder
                "udp": "N/A"
            }
        }
        return web.json_response(status_data)

    async def get_config(self, request: web.Request):
        """Returns the current server configuration."""
        # Use dataclasses.asdict to convert the config object to a JSON-serializable dict
        return web.json_response(dataclasses.asdict(self.gesture_server.config))

    async def put_config(self, request: web.Request):
        """
        Updates server configuration in memory.
        Note: This does not persist the changes to config.yaml yet.
        """
        try:
            data = await request.json()
            for key, value in data.items():
                if hasattr(self.gesture_server.config, key):
                    # Basic type checking/casting could be added here
                    setattr(self.gesture_server.config, key, value)

            # Log the change
            # logger.info(f"Configuration updated via API: {data}")

            return web.json_response({"status": "ok", "message": "Config updated in memory."})
        except json.JSONDecodeError:
            return web.json_response({"status": "error", "message": "Invalid JSON format."}, status=400)
        except Exception as e:
            return web.json_response({"status": "error", "message": str(e)}, status=500)

    async def get_metrics(self, request: web.Request):
        """Returns detailed performance metrics."""
        # For now, this is the same as the performance part of the status endpoint
        stats = await self.gesture_server.performance_monitor.get_stats()
        return web.json_response(stats)
