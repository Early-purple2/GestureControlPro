import asyncio
import logging
import time

from .predictor import TrajectoryPredictor
from .performance import PerformanceMonitor
from .controller import SystemController
from .models import ServerConfig, GestureCommand, GestureAction

logger = logging.getLogger(__name__)


class GestureExecutor:
    """Fast gesture executor with prediction and command queuing."""
    def __init__(self, config: ServerConfig, performance_monitor: PerformanceMonitor, controller: SystemController):
        self.config = config
        self.performance_monitor = performance_monitor
        self.controller = controller

        self.screen_width, self.screen_height = self.controller.size()
        self.predictor = TrajectoryPredictor(self.screen_width, self.screen_height)

        self.last_position = [0, 0]
        self.is_dragging = False
        self.command_queue = asyncio.Queue(maxsize=100)
        self.worker_task = asyncio.create_task(self._command_worker())

        logger.info(f"🖥️ Screen resolution: {self.screen_width}x{self.screen_height}")
        if self.config.enable_prediction:
            logger.info("🤖 Trajectory prediction enabled.")

    async def submit_command(self, command: GestureCommand):
        """Submits a command to the execution queue."""
        try:
            self.command_queue.put_nowait(command)
        except asyncio.QueueFull:
            logger.warning("Command queue is full, dropping command.")

    async def _command_worker(self):
        """Processes commands from the queue one by one."""
        logger.info("Gesture executor worker started.")
        while True:
            command = await self.command_queue.get()
            start_time = time.time()
            try:
                await self._execute_command_internal(command)
            except Exception as e:
                logger.error(f"❌ Error executing command {command.id}: {e}", exc_info=True)
            finally:
                latency = time.time() - start_time
                if self.config.performance_logging:
                    logger.debug(f"⚡ Command {command.id} processed in {latency*1000:.2f}ms")
                await self.performance_monitor.record_command(latency)
                self.command_queue.task_done()

    async def _execute_command_internal(self, command: GestureCommand):
        # This method now only does the coordinate conversion and clamping.
        # Smoothing and prediction are handled in _execute_action.
        abs_x = int(command.position[0] * self.screen_width)
        abs_y = int(command.position[1] * self.screen_height)

        abs_x = max(0, min(self.screen_width, abs_x))
        abs_y = max(0, min(self.screen_height, abs_y))

        await self._execute_action(command, abs_x, abs_y)


    async def _execute_action(self, command: GestureCommand, x: int, y: int):
        action = command.action
        metadata = command.metadata

        if action == GestureAction.MOVE_RELATIVE.value:
            dx = int(metadata.get('dx', 0))
            dy = int(metadata.get('dy', 0))
            await self.controller.move_relative(dx, dy)
            return

        if action == GestureAction.MOVE.value:
            if self.config.enable_prediction:
                x, y = self._predict_next_position(command)

            if self.config.gesture_smoothing > 0:
                x, y = self._smooth_position(x, y)

            await self.controller.move_to(x, y, 0.001)
        else:
            # Apply smoothing for all other actions
            if self.config.gesture_smoothing > 0:
                x, y = self._smooth_position(x, y)

            if action == GestureAction.CLICK.value:
                await self.controller.click(x, y, metadata.get('button', 'left'))
            elif action == GestureAction.DOUBLE_CLICK.value:
                await self.controller.double_click(x, y, metadata.get('button', 'left'))
            elif action == GestureAction.DRAG_START.value:
                if not self.is_dragging:
                    logger.info(f"Drag Start at ({x}, {y})")
                    self.is_dragging = True
                    # Use a default button if not specified
                    button = metadata.get('button', 'left')
                    await self.controller.mouse_down(x, y, button)
            elif action == GestureAction.DRAG_END.value:
                if self.is_dragging:
                    logger.info(f"Drag End at ({x}, {y})")
                    self.is_dragging = False
                    # Use a default button if not specified
                    button = metadata.get('button', 'left')
                    await self.controller.mouse_up(x, y, button)
            elif action == GestureAction.SCROLL.value:
                direction = metadata.get('direction', 'up')
                amount = metadata.get('amount', 3)
                if direction in ('up', 'down'):
                    await self.controller.scroll(amount if direction == 'up' else -amount, x, y)
                else:
                    await self.controller.hscroll(amount if direction == 'right' else -amount, x, y)
            elif action == GestureAction.ZOOM.value:
                factor = metadata.get('factor', 1.0)
                scroll_amt = int((factor - 1.0) * 5)
                await self.controller.key_down('ctrl')
                await self.controller.scroll(scroll_amt, x, y)
                await self.controller.key_up('ctrl')
            elif action == GestureAction.KEY_PRESS.value:
                await self.controller.press(metadata.get('key', 'space'))
            elif action == GestureAction.KEY_COMBO.value:
                await self.controller.hotkey(*metadata.get('keys', []))
            elif action == GestureAction.TYPE_TEXT.value:
                await self.controller.type_string(metadata.get('text', ''))
            elif action == GestureAction.WAVE.value:
                await self.controller.hotkey('alt', 'tab')
            elif action == GestureAction.COPY.value:
                await self.controller.copy_selection_to_clipboard()
            elif action == GestureAction.PASTE.value:
                text_to_paste = metadata.get('text', '')
                if text_to_paste:
                    await self.controller.copy_to_clipboard(text_to_paste)
                    await self.controller.paste_from_clipboard()
            elif action == GestureAction.TRANSLATE.value:
                await self.controller.copy_selection_to_clipboard()
                await asyncio.sleep(0.1) # Give time for clipboard to update
                text_to_translate = await self.controller.read_clipboard()
                if text_to_translate:
                    translated_text = await self.controller.translate(text_to_translate)
                    await self.controller.copy_to_clipboard(translated_text)
                    await self.controller.paste_from_clipboard()
            elif action == GestureAction.VOLUME_CONTROL.value:
                direction = metadata.get('direction', 'up')
                if direction == 'up':
                    await self.controller.volume_up()
                else:
                    await self.controller.volume_down()

    def _smooth_position(self, x: int, y: int):
        alpha = 1.0 - self.config.gesture_smoothing
        sx = int(alpha * x + (1 - alpha) * self.last_position[0])
        sy = int(alpha * y + (1 - alpha) * self.last_position[1])
        self.last_position = [sx, sy]
        return sx, sy

    def _predict_next_position(self, command: GestureCommand) -> tuple[int, int]:
        """Predicts the next cursor position using the new predictor."""
        predicted_pos = self.predictor.predict_next_position(
            current_position=(command.position[0] * self.screen_width, command.position[1] * self.screen_height),
            timestamp=command.timestamp
        )
        if predicted_pos:
            px, py = predicted_pos
            # Clamp prediction to screen bounds for safety
            px = max(0, min(self.screen_width, int(px)))
            py = max(0, min(self.screen_height, int(py)))
            return px, py

        # Fallback to current position if prediction is not available
        return int(command.position[0] * self.screen_width), int(command.position[1] * self.screen_height)
