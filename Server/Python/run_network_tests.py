import asyncio
import websockets
import json
import time
import statistics

async def benchmark_network_latency():
    uri = "ws://localhost:8080"
    latencies = []

    try:
        async with asyncio.timeout(5):
            async with websockets.connect(uri) as websocket:
                for i in range(100):
                    start = time.perf_counter()

                    message = {"id": f"bench-{i}", "type": "heartbeat", "timestamp": time.time()}
                    await websocket.send(json.dumps(message))
                    response = await websocket.recv()

                    latency = (time.perf_counter() - start) * 1000
                    latencies.append(latency)

        results = {
            "test": "network_latency",
            "samples": len(latencies),
            "avg_latency_ms": statistics.mean(latencies),
            "min_latency_ms": min(latencies),
            "max_latency_ms": max(latencies),
            "p95_latency_ms": statistics.quantiles(latencies, n=20)[18],
            "std_dev_ms": statistics.stdev(latencies)
        }
        return results

    except Exception as e:
        return {"test": "network_latency", "error": str(e)}

async def benchmark_command_throughput(duration=10): # Shorter duration for testing
    uri = "ws://localhost:8080"
    commands_sent = 0
    start_time = time.perf_counter()

    try:
        await asyncio.sleep(3)
        async with websockets.connect(uri) as websocket:
            async def send_command(i):
                nonlocal commands_sent
                command = {
                    "id": f"cmd-{i}",
                    "type": "gesture_command",
                    "payload": {
                        "action": "move",
                        "position": [100 + i % 500, 100 + i % 300],
                        "timestamp": time.time()
                    }
                }
                await websocket.send(json.dumps(command))
                commands_sent += 1

            tasks = []
            end_time = start_time + duration
            i = 0
            while time.perf_counter() < end_time:
                tasks.append(asyncio.create_task(send_command(i)))
                i += 1
                if len(tasks) >= 50:
                    await asyncio.gather(*tasks[:25])
                    tasks = tasks[25:]
                await asyncio.sleep(0.001)

            if tasks:
                await asyncio.gather(*tasks)

            duration = time.perf_counter() - start_time
            throughput = commands_sent / duration

            results = {
                "test": "command_throughput",
                "duration_seconds": duration,
                "commands_sent": commands_sent,
                "commands_per_second": throughput,
            }
            return results

    except Exception as e:
        return {"test": "command_throughput", "error": str(e)}

async def main():
    print("--- Running Network Tests ---")
    latency_results = await benchmark_network_latency()
    print(json.dumps(latency_results, indent=2))
    throughput_results = await benchmark_command_throughput()
    print(json.dumps(throughput_results, indent=2))
    print("--- Network Tests Finished ---")

if __name__ == "__main__":
    asyncio.run(main())
