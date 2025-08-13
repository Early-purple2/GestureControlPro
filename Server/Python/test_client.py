import asyncio
import websockets
import json
import time

async def send_test_gesture():
    """
    Connecte au serveur WebSocket et envoie une commande de geste de test.
    """
    uri = "ws://localhost:8080"
    try:
        async with websockets.connect(uri) as websocket:
            print(f"✅ Connecté à {uri}")

            # Prépare une commande de geste de type 'MOVE'
            test_command = {
                "type": "gesture_command",
                "id": "test-client-123",
                "payload": {
                    "action": "MOVE",
                    "position": [960, 540],  # Position au centre (supposant 1920x1080)
                    "timestamp": time.time(),
                    "metadata": {}
                }
            }

            message = json.dumps(test_command)
            await websocket.send(message)
            print(f"▶️ Envoyé la commande: {message}")

            # Attend une réponse (même si le serveur n'en envoie pas, cela garde la co ouverte)
            try:
                response = await asyncio.wait_for(websocket.recv(), timeout=1.0)
                print(f"◀️ Reçu une réponse inattendue: {response}")
            except asyncio.TimeoutError:
                print("✅ Aucune réponse reçue dans le temps imparti, comme attendu.")

    except ConnectionRefusedError:
        print(f"❌ Connexion refusée. Le serveur est-il en cours d'exécution sur {uri}?")
    except Exception as e:
        print(f"❌ Une erreur est survenue: {e}")

if __name__ == "__main__":
    print("🚀 Démarrage du client de test...")
    asyncio.run(send_test_gesture())
    print("🏁 Client de test terminé.")
