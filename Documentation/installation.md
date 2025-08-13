
# ðŸ“¦ Installation Guide - GestureControl Pro

Guide d'installation complet pour tous les composants du systÃ¨me de contrÃ´le gestuel rÃ©volutionnaire.

## ðŸ”§ PrÃ©requis SystÃ¨me

### ðŸ’» macOS Client (Application principale)

| Composant | Minimum | RecommandÃ© |
|-----------|---------|-------------|
| **macOS** | 15.0 Sequoia | 15.2+ |
| **Xcode** | 16.0 | 16.2+ |
| **Swift** | 6.0 | 6.2+ |
| **Processeur** | Apple M1 / Intel x86_64 | Apple M4 Pro/Max |
| **RAM** | 8 GB | 32 GB |
| **Stockage** | 2 GB libres | 10 GB |
| **CamÃ©ra** | FaceTime HD | Ultra Wide |

**VÃ©rification systÃ¨me :**
```bash
# Version macOS
sw_vers -productVersion

# Version Xcode
xcode-select --version

# Architecture processeur
uname -m

# RAM disponible
system_profiler SPHardwareDataType | grep "Memory:"
```

### ðŸ¥½ visionOS (Support Vision Pro)

| Composant | Version |
|-----------|---------|
| **visionOS** | 2.6+ |
| **Hand Tracking** | ActivÃ© |
| **Spatial Computing** | SupportÃ© |
| **RAM** | 16 GB |
| **Neural Engine** | 32 cÅ“urs |

### ðŸ Python Server (PC distant)

| Composant | Minimum | RecommandÃ© |
|-----------|---------|-------------|
| **Python** | 3.11 | 3.12+ |
| **OS** | Windows 10, macOS 13, Ubuntu 20.04 | Windows 11, macOS 15, Ubuntu 24.04 |
| **RAM** | 4 GB | 16 GB |
| **RÃ©seau** | WiFi 5 | WiFi 6E / Ethernet |

**VÃ©rification Python :**
```bash
# Version Python
python3 --version

# Modules requis
python3 -c "import asyncio, websockets, pyautogui; print('âœ… Modules disponibles')"
```

## ðŸ“¥ Installation Client macOS

### 1. PrÃ©paration de l'environnement

#### Installation des outils de dÃ©veloppement
```bash
# Outils Xcode Command Line
sudo xcode-select --install

# VÃ©rification installation
xcode-select -p

# Installation Homebrew (si nÃ©cessaire)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Installation Swift Package Manager (automatique avec Xcode)
```bash
# VÃ©rification Swift
swift --version

# Test Package Manager
swift package --help
```

### 2. Clone du Repository

```bash
# Clone avec historique complet
git clone https://github.com/votre-nom/GestureControlPro.git
cd GestureControlPro

# OU clone minimal pour Ã©conomiser la bande passante
git clone --depth=1 https://github.com/votre-nom/GestureControlPro.git
cd GestureControlPro

# VÃ©rification des submodules
git submodule update --init --recursive
```

### 3. Configuration Swift Package Manager

```bash
# RÃ©solution des dÃ©pendances
swift package resolve

# VÃ©rification des dÃ©pendances
swift package show-dependencies

# Nettoyage cache si problÃ¨me
rm -rf .build
swift package clean
```

### 4. Compilation et Build

#### Build Debug (dÃ©veloppement)
```bash
# Compilation rapide
swift build

# Avec logs dÃ©taillÃ©s
swift build --verbose

# Build spÃ©cifique Ã  l'architecture
swift build --arch arm64  # Apple Silicon
swift build --arch x86_64 # Intel
```

#### Build Release (production)
```bash
# Optimisation maximale
swift build -c release --arch arm64

# Avec profilage de performance
swift build -c release --arch arm64 --enable-test-discovery

# VÃ©rification binaire gÃ©nÃ©rÃ©
file .build/release/GestureControlPro
```

### 5. Configuration Xcode (Optionnel)

```bash
# GÃ©nÃ©ration projet Xcode
swift package generate-xcodeproj

# Ouverture automatique
open GestureControlPro.xcodeproj

# OU ouverture depuis Package.swift (recommandÃ©)
open Package.swift
```

### 6. Tests et VÃ©rification

```bash
# ExÃ©cution tests unitaires
swift test

# Tests avec couverture de code
swift test --enable-code-coverage

# Tests spÃ©cifiques
swift test --filter GestureDetectionTests

# GÃ©nÃ©ration rapport de couverture
swift test --enable-code-coverage --build-path .build
```

### 7. PremiÃ¨re exÃ©cution

```bash
# Lancement application
swift run GestureControlPro

# Avec arguments de debug
swift run GestureControlPro --verbose --test-mode

# VÃ©rification permissions camÃ©ra (macOS demandera l'autorisation)
```

## ðŸ Installation Serveur Python

### 1. Configuration Python

#### Installation Python (si nÃ©cessaire)

**macOS:**
```bash
# Via Homebrew (recommandÃ©)
brew install python@3.12

# VÃ©rification installation
python3.12 --version
which python3.12
```

**Windows:**
```powershell
# Via winget
winget install Python.Python.3.12

# Via Microsoft Store
# Rechercher "Python 3.12" dans le Store

# VÃ©rification
python --version
where python
```

**Ubuntu/Debian:**
```bash
# Mise Ã  jour systÃ¨me
sudo apt update && sudo apt upgrade -y

# Installation Python 3.12
sudo apt install python3.12 python3.12-venv python3.12-pip

# Installation dÃ©pendances systÃ¨me
sudo apt install python3.12-dev python3-tk
```

### 2. Environnement Virtuel

```bash
# Navigation vers dossier serveur
cd GestureControlPro/Server/Python

# CrÃ©ation environnement virtuel
python3 -m venv gesturecontrol_env

# Activation environnement
# macOS/Linux:
source gesturecontrol_env/bin/activate

# Windows:
gesturecontrol_env\Scripts\activate

# VÃ©rification activation
which python  # doit pointer vers l'environnement virtuel
```

### 3. Installation des DÃ©pendances

```bash
# Mise Ã  jour pip
pip install --upgrade pip setuptools wheel

# Installation requirements
pip install -r requirements.txt

# OU installation manuelle des dÃ©pendances critiques
pip install \
    asyncio-mqtt==0.16.1 \
    uvloop==0.19.0 \
    websockets==12.0 \
    pyautogui==0.9.54 \
    aiohttp==3.9.1 \
    psutil==5.9.6 \
    numpy==1.25.2

# VÃ©rification installations
pip list | grep -E "(websockets|pyautogui|uvloop)"
```

### 4. Configuration Permissions SystÃ¨me

#### macOS

```bash
# Test permissions PyAutoGUI
python3 -c "
import pyautogui
print('Test dÃ©placement souris...')
try:
    pyautogui.moveTo(100, 100)
    print('âœ… Permissions OK')
except Exception as e:
    print(f'âŒ Erreur: {e}')
    print('âž¡ï¸  Allez dans PrÃ©fÃ©rences SystÃ¨me > SÃ©curitÃ© et confidentialitÃ© > AccessibilitÃ©')
"
```

Si erreur de permission :
1. **PrÃ©fÃ©rences SystÃ¨me** â†’ **SÃ©curitÃ© et confidentialitÃ©**
2. **ConfidentialitÃ©** â†’ **AccessibilitÃ©**
3. Cliquer le cadenas et saisir mot de passe
4. Ajouter **Terminal** ou **Python** Ã  la liste
5. Cocher la case pour activer

#### Windows

```powershell
# ExÃ©cuter PowerShell en tant qu'administrateur
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Test PyAutoGUI
python -c "
import pyautogui
print('Test dÃ©placement souris...')
pyautogui.moveTo(100, 100)
print('âœ… Test rÃ©ussi')
"

# Configuration pare-feu (si nÃ©cessaire)
New-NetFirewallRule -DisplayName "GestureControl WebSocket" -Direction Inbound -Port 8080 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "GestureControl UDP" -Direction Inbound -Port 9090 -Protocol UDP -Action Allow
```

#### Ubuntu/Linux

```bash
# Installation dÃ©pendances systÃ¨me X11
sudo apt install -y \
    python3-tk \
    python3-dev \
    scrot \
    python3-xlib \
    xdotool

# Test PyAutoGUI
python3 -c "
import pyautogui
import os
print(f'Display: {os.environ.get(\"DISPLAY\", \"Non dÃ©fini\")}')
pyautogui.moveTo(100, 100)
print('âœ… Test rÃ©ussi')
"

# Si erreur de display
export DISPLAY=:0
```

### 5. Test et Validation

```bash
# Test serveur basique
python gesture_server.py --test

# Test avec logs dÃ©taillÃ©s
python gesture_server.py --verbose --log-level DEBUG

# Test de connectivitÃ© rÃ©seau
python -c "
import socket
import websockets
import asyncio

async def test_websocket():
    try:
        await websockets.serve(lambda ws, path: None, 'localhost', 8080)
        print('âœ… WebSocket: OK')
    except Exception as e:
        print(f'âŒ WebSocket: {e}')

asyncio.run(test_websocket())
"
```

## ðŸŒ Configuration RÃ©seau

### 1. Configuration Firewall

#### macOS (pfctl)
```bash
# VÃ©rification Ã©tat firewall
sudo pfctl -s info

# Si firewall actif, ajouter rÃ¨gles
sudo pfctl -f /etc/pf.conf
sudo pfctl -e

# OU dÃ©sactivation temporaire pour tests
sudo pfctl -d
```

#### Windows (Windows Defender)
```powershell
# Ouverture ports entrants
New-NetFirewallRule -DisplayName "GestureControl-WS" -Direction Inbound -Port 8080 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "GestureControl-UDP" -Direction Inbound -Port 9090 -Protocol UDP -Action Allow
New-NetFirewallRule -DisplayName "GestureControl-TCP" -Direction Inbound -Port 7070 -Protocol TCP -Action Allow

# VÃ©rification rÃ¨gles
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*GestureControl*"}
```

#### Linux (ufw/firewalld)
```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 8080/tcp comment "GestureControl WebSocket"
sudo ufw allow 9090/udp comment "GestureControl UDP"
sudo ufw allow 7070/tcp comment "GestureControl TCP"
sudo ufw reload

# RedHat/CentOS (firewalld)
sudo firewall-cmd --permanent --add-port=8080/tcp --add-port=9090/udp --add-port=7070/tcp
sudo firewall-cmd --reload
```

### 2. Configuration RÃ©seau Local

#### DÃ©couverte d'adresse IP
```bash
# macOS/Linux
ifconfig | grep -A 1 "inet " | grep -v 127.0.0.1

# Windows
ipconfig | findstr "IPv4"

# Alternative multiplateforme
python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.connect(('8.8.8.8', 80))
print(f'IP locale: {s.getsockname()[0]}')
s.close()
"
```

#### Test de connectivitÃ©
```bash
# Test ping entre appareils
ping 192.168.1.100  # Remplacer par IP cible

# Test ports ouverts
nc -zv 192.168.1.100 8080  # macOS/Linux
telnet 192.168.1.100 8080  # Windows

# Scan de rÃ©seau local
nmap -sn 192.168.1.0/24    # DÃ©couverte appareils
```

## ðŸš€ Scripts de DÃ©marrage

### 1. Script de DÃ©marrage Automatique

#### macOS/Linux (`start_gesturecontrol.sh`)
```bash
#!/bin/bash

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$PROJECT_ROOT/logs/gesturecontrol.log"
PID_FILE="$PROJECT_ROOT/tmp/gesturecontrol.pid"

# Couleurs pour logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1" | tee -a "$LOG_FILE"
}

# CrÃ©ation dossiers
mkdir -p "$PROJECT_ROOT/logs" "$PROJECT_ROOT/tmp"

log "ðŸš€ DÃ©marrage GestureControl Pro..."

# VÃ©rification prÃ©requis
if ! command -v python3 &> /dev/null; then
    error "Python 3 non trouvÃ©"
    exit 1
fi

if ! command -v swift &> /dev/null; then
    error "Swift non trouvÃ©"
    exit 1
fi

# DÃ©marrage serveur Python
log "ðŸ DÃ©marrage serveur Python..."
cd "$PROJECT_ROOT/Server/Python"

if [ ! -d "gesturecontrol_env" ]; then
    error "Environnement virtuel non trouvÃ©. ExÃ©cutez d'abord l'installation."
    exit 1
fi

source gesturecontrol_env/bin/activate
nohup python3 gesture_server.py > "$LOG_FILE" 2>&1 &
SERVER_PID=$!
echo $SERVER_PID > "$PID_FILE"

log "Serveur dÃ©marrÃ© (PID: $SERVER_PID)"

# Attente dÃ©marrage serveur
sleep 5

# Test connectivitÃ© serveur
if curl -s http://localhost:8080 > /dev/null 2>&1; then
    success "Serveur accessible"
else
    error "Serveur non accessible"
    kill $SERVER_PID 2>/dev/null
    exit 1
fi

# DÃ©marrage application macOS
log "ðŸ“± DÃ©marrage application macOS..."
cd "$PROJECT_ROOT"

# Build si nÃ©cessaire
if [ ! -f ".build/release/GestureControlPro" ] || [ "Sources" -nt ".build/release/GestureControlPro" ]; then
    log "ðŸ”¨ Compilation nÃ©cessaire..."
    swift build -c release
    if [ $? -ne 0 ]; then
        error "Ã‰chec compilation"
        kill $SERVER_PID 2>/dev/null
        exit 1
    fi
fi

# Lancement application
nohup swift run -c release GestureControlPro >> "$LOG_FILE" 2>&1 &
APP_PID=$!

log "Application dÃ©marrÃ©e (PID: $APP_PID)"

success "âœ… SystÃ¨me GestureControl Pro dÃ©marrÃ©"
success "ðŸ“Š Serveur: http://localhost:8080"
success "ðŸ“± Application: PID $APP_PID"
success "ðŸ“ Logs: $LOG_FILE"

# Fonction nettoyage
cleanup() {
    log "ðŸ›‘ ArrÃªt des processus..."
    kill $SERVER_PID $APP_PID 2>/dev/null
    rm -f "$PID_FILE"
    success "ArrÃªt terminÃ©"
    exit 0
}

# Gestionnaires de signaux
trap cleanup SIGINT SIGTERM

# Attente infinie (processus reste actif)
while true; do
    # VÃ©rification processus encore actifs
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        error "Serveur Python s'est arrÃªtÃ©"
        cleanup
    fi
    
    if ! kill -0 $APP_PID 2>/dev/null; then
        error "Application macOS s'est arrÃªtÃ©e"
        cleanup
    fi
    
    sleep 10
done
```

#### Windows (`start_gesturecontrol.bat`)
```batch
@echo off
setlocal enabledelayedexpansion

echo [%date% %time%] ðŸš€ DÃ©marrage GestureControl Pro...

REM VÃ©rification Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [%date% %time%] âŒ Python non trouvÃ©
    pause
    exit /b 1
)

REM Navigation vers dossier serveur
cd /d "%~dp0\Server\Python"

REM VÃ©rification environnement virtuel
if not exist "gesturecontrol_env" (
    echo [%date% %time%] âŒ Environnement virtuel non trouvÃ©
    echo ExÃ©cutez d'abord l'installation
    pause
    exit /b 1
)

REM Activation environnement virtuel
call gesturecontrol_env\Scripts\activate

REM DÃ©marrage serveur Python en arriÃ¨re-plan
echo [%date% %time%] ðŸ DÃ©marrage serveur Python...
start /B python gesture_server.py

REM Attente dÃ©marrage serveur
timeout /t 5 /nobreak >nul

REM Test connectivitÃ©
curl -s http://localhost:8080 >nul
if errorlevel 1 (
    echo [%date% %time%] âŒ Serveur non accessible
    pause
    exit /b 1
)

echo [%date% %time%] âœ… Serveur prÃªt

REM DÃ©marrage interface web pour Windows
echo [%date% %time%] ðŸŒ Ouverture interface de monitoring...
start http://localhost:8000

echo [%date% %time%] âœ… SystÃ¨me dÃ©marrÃ©
echo.
echo ðŸ“Š Serveur Python: http://localhost:8080
echo ðŸŒ Interface Web: http://localhost:8000
echo.
echo Appuyez sur une touche pour arrÃªter le systÃ¨me...
pause >nul

REM Nettoyage Ã  la sortie
taskkill /f /im python.exe /fi "WINDOWTITLE eq gesture_server*" >nul 2>&1
echo [%date% %time%] ðŸ›‘ SystÃ¨me arrÃªtÃ©
```

### 2. Service SystÃ¨me (Production)

#### macOS LaunchDaemon

CrÃ©er `/Library/LaunchDaemons/com.gesturecontrol.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.gesturecontrol.server</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/gesturecontrol_start.sh</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>/var/log/gesturecontrol.log</string>
    
    <key>StandardErrorPath</key>
    <string>/var/log/gesturecontrol_error.log</string>
    
    <key>WorkingDirectory</key>
    <string>/opt/gesturecontrol</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
```

**Installation du service :**
```bash
# Copie du fichier service
sudo cp com.gesturecontrol.plist /Library/LaunchDaemons/

# DÃ©finition permissions
sudo chown root:wheel /Library/LaunchDaemons/com.gesturecontrol.plist
sudo chmod 644 /Library/LaunchDaemons/com.gesturecontrol.plist

# Chargement du service
sudo launchctl load /Library/LaunchDaemons/com.gesturecontrol.plist

# DÃ©marrage
sudo launchctl start com.gesturecontrol.server

# VÃ©rification statut
sudo launchctl list | grep gesturecontrol
```

## âœ… Tests et Validation

### 1. Tests de ConnectivitÃ©

```bash
# Script de test complet
cat > test_connectivity.sh << 'EOF'
#!/bin/bash

echo "ðŸ§ª Tests de connectivitÃ© GestureControl Pro"
echo "============================================="

# Test WebSocket
echo "ðŸ”— Test WebSocket..."
curl -i -N -H "Connection: Upgrade" \
     -H "Upgrade: websocket" \
     -H "Host: localhost:8080" \
     -H "Origin: http://localhost:8080" \
     http://localhost:8080/ --max-time 5

if [ $? -eq 0 ]; then
    echo "âœ… WebSocket: OK"
else
    echo "âŒ WebSocket: Ã‰chec"
fi

# Test UDP
echo "ðŸš€ Test UDP..."
echo "test_message" | nc -u -w 1 localhost 9090
if [ $? -eq 0 ]; then
    echo "âœ… UDP: OK"
else
    echo "âŒ UDP: Ã‰chec"
fi

# Test TCP  
echo "ðŸ”Œ Test TCP..."
echo "test_message" | nc -w 1 localhost 7070
if [ $? -eq 0 ]; then
    echo "âœ… TCP: OK"
else
    echo "âŒ TCP: Ã‰chec"
fi

echo "============================================="
echo "Tests terminÃ©s"
EOF

chmod +x test_connectivity.sh
./test_connectivity.sh
```

### 2. Tests de Performance

```bash
# Script de benchmark
python3 << 'EOF'
import asyncio
import time
import statistics
import websockets
import json

async def benchmark_websocket():
    print("ðŸ“Š Benchmark WebSocket...")
    
    uri = "ws://localhost:8080"
    latencies = []
    
    try:
        async with websockets.connect(uri) as websocket:
            for i in range(100):
                start_time = time.perf_counter()
                
                # Envoi message test
                message = {
                    "id": f"test-{i}",
                    "type": "heartbeat",
                    "timestamp": time.time()
                }
                
                await websocket.send(json.dumps(message))
                response = await websocket.recv()
                
                end_time = time.perf_counter()
                latency = (end_time - start_time) * 1000  # en ms
                latencies.append(latency)
                
                if i % 10 == 0:
                    print(f"Test {i}/100 - Latence: {latency:.2f}ms")
            
            # Statistiques
            avg_latency = statistics.mean(latencies)
            min_latency = min(latencies)
            max_latency = max(latencies)
            
            print(f"\nðŸ“ˆ RÃ©sultats:")
            print(f"Latence moyenne: {avg_latency:.2f}ms")
            print(f"Latence min: {min_latency:.2f}ms") 
            print(f"Latence max: {max_latency:.2f}ms")
            
            if avg_latency < 10:
                print("âœ… Performance excellente (<10ms)")
            elif avg_latency < 20:
                print("ðŸŸ¡ Performance correcte (<20ms)")
            else:
                print("âŒ Performance dÃ©gradÃ©e (>20ms)")
                
    except Exception as e:
        print(f"âŒ Erreur benchmark: {e}")

if __name__ == "__main__":
    asyncio.run(benchmark_websocket())
EOF
```

## ðŸ› DÃ©pannage

### ProblÃ¨mes Courants

#### 1. "Permission denied" sur macOS
**SymptÃ´mes :** PyAutoGUI ne peut pas contrÃ´ler la souris/clavier

**Solution :**
1. PrÃ©fÃ©rences SystÃ¨me â†’ SÃ©curitÃ© et confidentialitÃ©
2. ConfidentialitÃ© â†’ AccessibilitÃ©  
3. Ajouter Terminal, Python, ou l'application
4. RedÃ©marrer l'application

#### 2. "Camera not found" 
**SymptÃ´mes :** Erreur d'accÃ¨s Ã  la camÃ©ra

**Diagnostic :**
```bash
# VÃ©rifier camÃ©ras disponibles
system_profiler SPCameraDataType

# Test avec Python
python3 -c "
import cv2
cap = cv2.VideoCapture(0)
if cap.isOpened():
    print('âœ… CamÃ©ra accessible')
    cap.release()
else:
    print('âŒ CamÃ©ra non accessible')
"
```

**Solution :**
- VÃ©rifier permissions camÃ©ra dans PrÃ©fÃ©rences SystÃ¨me
- Fermer autres applications utilisant la camÃ©ra
- RedÃ©marrer le systÃ¨me si nÃ©cessaire

#### 3. Latence Ã©levÃ©e
**SymptÃ´mes :** Temps de rÃ©ponse > 50ms

**Diagnostic :**
```bash
# Test rÃ©seau local
ping -c 10 192.168.1.100

# Test bande passante
iperf3 -c 192.168.1.100 -t 10
```

**Solutions :**
- Utiliser connexion Ethernet au lieu de WiFi
- Fermer applications gourmandes en rÃ©seau
- Configurer QoS sur routeur
- RÃ©duire rÃ©solution de capture vidÃ©o

#### 4. Modules Python manquants
**SymptÃ´mes :** `ModuleNotFoundError`

**Solution :**
```bash
# VÃ©rifier environnement virtuel actif
which python

# RÃ©installer dÃ©pendances
pip install -r requirements.txt --force-reinstall

# OU installation individuelle
pip install websockets==12.0 pyautogui==0.9.54
```

### Logs et Debug

#### Activation logs dÃ©taillÃ©s
```bash
# Variables d'environnement debug
export GESTURE_LOG_LEVEL=DEBUG
export GESTURE_PERFORMANCE_LOG=1
export GESTURE_NETWORK_DEBUG=1

# DÃ©marrage avec logs
python3 gesture_server.py --verbose 2>&1 | tee debug.log

# Swift avec debug
swift run GestureControlPro --log-level debug
```

#### Analyse des logs
```bash
# Erreurs critiques
grep -i "error\|exception\|fatal" debug.log

# MÃ©triques performance  
grep -i "fps\|latency\|performance" debug.log | tail -20

# Ã‰vÃ©nements rÃ©seau
grep -i "connect\|disconnect\|timeout" debug.log

# Statistiques gestuelles
grep -i "gesture\|detection\|confidence" debug.log | tail -50
```

---

**âœ… Installation terminÃ©e ! Votre systÃ¨me GestureControl Pro est maintenant opÃ©rationnel.**

**Prochaines Ã©tapes :**
1. Consultez le [Guide d'Utilisation](Usage.md)
2. Explorez la [RÃ©fÃ©rence API](API_Reference.md) 
3. Rejoignez la [CommunautÃ©](https://discord.gg/gesturecontrol)
