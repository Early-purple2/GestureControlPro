import asyncio
import time
from typing import Dict


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
