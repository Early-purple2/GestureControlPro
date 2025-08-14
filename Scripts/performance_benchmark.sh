#!/bin/bash
# performance_benchmark.sh

echo "🚀 GestureControl Pro - Performance Benchmark Suite"
echo "=================================================="

# Configuration
DURATION=${1:-60}  # Durée test en secondes
RESULTS_DIR="benchmark_results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "🗓️ Durée du benchmark: ${DURATION}s"
echo "📁 Résultats dans: $RESULTS_DIR"

# 1. Test latence réseau
echo "📡 Test latence réseau..."
python3 << EOF > "$RESULTS_DIR/network_latency.json"
import asyncio
import websockets
import json
import time
import statistics

async def benchmark_network_latency():
    uri = "ws://localhost:8080"
    latencies = []

    try:
        async with websockets.connect(uri, timeout=5) as websocket:
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

        print(json.dumps(results, indent=2))

    except Exception as e:
        print(json.dumps({"error": str(e)}))

asyncio.run(benchmark_network_latency())
EOF

# 2. Test throughput commandes
echo "⚡ Test throughput commandes..."
python3 << EOF > "$RESULTS_DIR/command_throughput.json"
import asyncio
import websockets
import json
import time

async def benchmark_command_throughput():
    uri = "ws://localhost:8080"
    commands_sent = 0
    start_time = time.perf_counter()

    try:
        async with websockets.connect(uri) as websocket:

            # Envoi commandes en parallèle
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

            # Test parallèle sur durée définie
            tasks = []
            end_time = start_time + $DURATION

            i = 0
            while time.perf_counter() < end_time:
                tasks.append(asyncio.create_task(send_command(i)))
                i += 1

                # Limite concurrent tasks
                if len(tasks) >= 50:
                    await asyncio.gather(*tasks[:25])
                    tasks = tasks[25:]

                await asyncio.sleep(0.001)  # 1ms entre commandes

            # Attendre tasks restantes
            if tasks:
                await asyncio.gather(*tasks)

            duration = time.perf_counter() - start_time
            throughput = commands_sent / duration

            results = {
                "test": "command_throughput",
                "duration_seconds": duration,
                "commands_sent": commands_sent,
                "commands_per_second": throughput,
                "avg_interval_ms": 1000 / throughput if throughput > 0 else 0
            }

            print(json.dumps(results, indent=2))

    except Exception as e:
        print(json.dumps({"error": str(e)}))

asyncio.run(benchmark_command_throughput())
EOF

# 3. Test utilisation ressources
echo "💻 Test utilisation ressources..."
python3 << EOF > "$RESULTS_DIR/resource_usage.json"
import psutil
import time
import json
import statistics

def benchmark_resource_usage():
    cpu_samples = []
    memory_samples = []

    start_time = time.perf_counter()

    while time.perf_counter() - start_time < $DURATION:
        cpu_percent = psutil.cpu_percent(interval=0.1)
        memory_info = psutil.virtual_memory()

        cpu_samples.append(cpu_percent)
        memory_samples.append(memory_info.used / 1024 / 1024)  # MB

        time.sleep(0.5)

    results = {
        "test": "resource_usage",
        "duration_seconds": time.perf_counter() - start_time,
        "cpu": {
            "avg_percent": statistics.mean(cpu_samples),
            "max_percent": max(cpu_samples),
            "min_percent": min(cpu_samples)
        },
        "memory": {
            "avg_mb": statistics.mean(memory_samples),
            "max_mb": max(memory_samples),
            "min_mb": min(memory_samples)
        },
        "samples": len(cpu_samples)
    }

    print(json.dumps(results, indent=2))

benchmark_resource_usage()
EOF

# 4. Génération rapport final
echo "📄 Génération rapport final..."
cat << EOF > "$RESULTS_DIR/benchmark_report.md"
# GestureControl Pro - Rapport de Performance

**Date:** $(date)
**Durée:** ${DURATION} secondes
**Système:** $(uname -a)

## Résultats

### Latence Réseau
\`\`\`json
$(cat "$RESULTS_DIR/network_latency.json")
\`\`\`

### Throughput Commandes
\`\`\`json
$(cat "$RESULTS_DIR/command_throughput.json")
\`\`\`

### Utilisation Ressources
\`\`\`json
$(cat "$RESULTS_DIR/resource_usage.json")
\`\`\`

## Recommandations

$(python3 << 'PYEOF'
import json

# Chargement résultats
try:
    with open("$RESULTS_DIR/network_latency.json") as f:
        network = json.load(f)
    with open("$RESULTS_DIR/command_throughput.json") as f:
        throughput = json.load(f)
    with open("$RESULTS_DIR/resource_usage.json") as f:
        resources = json.load(f)

    recommendations = []

    # Analyse latence
    if network.get("avg_latency_ms", 0) > 10:
        recommendations.append("🔴 Latence réseau élevée (>10ms) - Vérifier connexion réseau")
    elif network.get("avg_latency_ms", 0) > 5:
        recommendations.append("🟠 Latence réseau acceptable mais optimisable")
    else:
        recommendations.append("🟢 Latence réseau excellente")

    # Analyse throughput
    if throughput.get("commands_per_second", 0) < 100:
        recommendations.append("🔴 Throughput faible (<100 cmd/s) - Optimiser traitement")
    elif throughput.get("commands_per_second", 0) < 500:
        recommendations.append("🟠 Throughput correct mais améliorable")
    else:
        recommendations.append("🟢 Throughput excellent")

    # Analyse ressources
    if resources.get("cpu", {}).get("avg_percent", 0) > 50:
        recommendations.append("🔴 Utilisation CPU élevée - Considérer optimisations")
    elif resources.get("cpu", {}).get("avg_percent", 0) > 25:
        recommendations.append("🟠 Utilisation CPU modérée")
    else:
        recommendations.append("🟢 Utilisation CPU optimale")

    for rec in recommendations:
        print(f"- {rec}")

except Exception as e:
    print(f"- ❌ Erreur analyse: {e}")
PYEOF
)
EOF

echo "✅ Benchmark terminé!"
echo "📄 Rapport disponible: $RESULTS_DIR/benchmark_report.md"
echo ""
echo "🏆 Résumé rapide:"
grep -E "avg_latency_ms|commands_per_second|avg_percent" "$RESULTS_DIR"/*.json | head -3
