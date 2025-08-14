# GestureControl Pro - Rapport de Performance

**Date:** Thu Aug 14 11:52:12 UTC 2025
**Durée:** 60 secondes
**Système:** Linux devbox 6.8.0 #1 SMP PREEMPT_DYNAMIC Thu Aug  7 22:13:44 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux

## Résultats

### Latence Réseau
```json
{"error": "Multiple exceptions: [Errno 111] Connect call failed ('127.0.0.1', 8080), [Errno 97] Address family not supported by protocol"}
```

### Throughput Commandes
```json
{"error": "Multiple exceptions: [Errno 111] Connect call failed ('127.0.0.1', 8080), [Errno 97] Address family not supported by protocol"}
```

### Utilisation Ressources
```json
{
  "test": "resource_usage",
  "duration_seconds": 60.105698101000144,
  "cpu": {
    "avg_percent": 0.073,
    "max_percent": 2.5,
    "min_percent": 0.0
  },
  "memory": {
    "avg_mb": 166.089140625,
    "max_mb": 176.46484375,
    "min_mb": 165.3125
  },
  "samples": 100
}
```

## Recommandations

- ❌ Erreur analyse: [Errno 2] No such file or directory: '$RESULTS_DIR/network_latency.json'
