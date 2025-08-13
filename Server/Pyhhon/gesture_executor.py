#!/usr/bin/env python3
"""
Exécuteur de commandes gestuelles pour GestureControl Pro Node.js bridge
Reçoit un payload JSON et exécute l'action via PyAutoGUI.
"""

import sys
import json
import time
import pyautogui
import logging

# Configure minimal latency
pyautogui.FAILSAFE = False
pyautogui.PAUSE = 0.001

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger("gesture_executor")


def execute_command(payload: dict) -> bool:
    action = payload.get('action', '')
    pos = payload.get('position', [0, 0])
    x, y = int(pos[0]), int(pos[1])
    metadata = payload.get('metadata', {})

    try:
        if action == 'click':
            btn = metadata.get('button', 'left')
            pyautogui.click(x, y, button=btn)
        elif action == 'double_click':
            btn = metadata.get('button', 'left')
            pyautogui.doubleClick(x, y, button=btn)
        elif action == 'drag':
            frm = metadata.get('from', [x, y])
            to = metadata.get('to', [x, y])
            pyautogui.dragTo(to[0], to[1], duration=0.001, button='left')
        elif action == 'scroll':
            dir = metadata.get('direction', 'up')
            amt = metadata.get('amount', 3)
            if dir in ('up', 'down'):
                pyautogui.scroll(amt if dir=='up' else -amt, x=x, y=y)
            else:
                pyautogui.hscroll(amt if dir=='right' else -amt, x=x, y=y)
        elif action == 'zoom':
            factor = metadata.get('factor', 1.0)
            pyautogui.keyDown('ctrl')
            scroll_amt = int((factor - 1.0)*5)
            pyautogui.scroll(scroll_amt, x=x, y=y)
            pyautogui.keyUp('ctrl')
        elif action == 'move':
            pyautogui.moveTo(x, y, duration=0.001)
        else:
            logger.warning(f"Action inconnue : {action}")
            return False
        logger.info(f"✅ Executed {action} at ({x},{y})")
        return True

    except Exception as e:
        logger.error(f"❌ Execution failed: {e}")
        return False


if __name__ == "__main__":
    try:
        raw = sys.argv[1]
        payload = json.loads(raw)
        success = execute_command(payload)
        sys.exit(0 if success else 1)
    except Exception as e:
        logger.error(f"💥 Fatal executor error: {e}")
        sys.exit(1)
