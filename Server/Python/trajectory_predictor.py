import numpy as np
import collections
import time

class TrajectoryPredictor:
    def __init__(self, screen_width: int, screen_height: int, sequence_length: int = 5):
        self.sequence_length = sequence_length
        self.position_buffer = collections.deque(maxlen=sequence_length)
        self.velocity_buffer = collections.deque(maxlen=sequence_length - 1)

        self.screen_width = screen_width
        self.screen_height = screen_height

    def predict_next_position(
        self,
        current_position: tuple[float, float],
        timestamp: float
    ) -> tuple[float, float]:
        """Predicts the next position to compensate for latency."""

        self.position_buffer.append((*current_position, timestamp))

        if len(self.position_buffer) < 2:
            return current_position

        # Calculate instantaneous velocity
        prev_pos = self.position_buffer[-2]
        curr_pos = self.position_buffer[-1]

        dt = curr_pos[2] - prev_pos[2]
        if dt <= 0:
            return current_position

        velocity_x = (curr_pos[0] - prev_pos[0]) / dt
        velocity_y = (curr_pos[1] - prev_pos[1]) / dt

        self.velocity_buffer.append((velocity_x, velocity_y))

        # Predict next position using a weighted average of recent velocities
        if len(self.velocity_buffer) >= 1:
            # Simple weighted average (more weight to recent velocities)
            weights = np.arange(1, len(self.velocity_buffer) + 1)
            weights = weights / weights.sum()

            avg_velocity_x = np.sum([v[0] * w for v, w in zip(self.velocity_buffer, weights)])
            avg_velocity_y = np.sum([v[1] * w for v, w in zip(self.velocity_buffer, weights)])
        else:
            avg_velocity_x, avg_velocity_y = 0, 0

        # Predict 20ms into the future to compensate for typical latency
        prediction_time = 0.020

        predicted_x = current_position[0] + avg_velocity_x * prediction_time
        predicted_y = current_position[1] + avg_velocity_y * prediction_time

        # Clamp the predicted position to the screen boundaries
        predicted_x = max(0, min(self.screen_width, predicted_x))
        predicted_y = max(0, min(self.screen_height, predicted_y))

        return (predicted_x, predicted_y)
