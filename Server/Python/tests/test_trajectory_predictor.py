import unittest
import time

from trajectory_predictor import TrajectoryPredictor

class TestTrajectoryPredictor(unittest.TestCase):

    def setUp(self):
        self.predictor = TrajectoryPredictor(screen_width=1920, screen_height=1080)

    def test_prediction(self):

        # Provide a history of positions
        positions = [
            (100, 100),
            (110, 110),
            (120, 120),
            (130, 130),
            (140, 140),
        ]

        # Simulate timestamps
        timestamps = [time.time() + i * 0.01 for i in range(len(positions))]

        # The predictor updates its history internally when calling predict_next_position
        predicted_pos = (0,0)
        for i in range(len(positions)):
            predicted_pos = self.predictor.predict_next_position(
                current_position=positions[i],
                timestamp=timestamps[i]
            )

        # The predicted position should be ahead of the last position
        self.assertGreater(predicted_pos[0], positions[-1][0])
        self.assertGreater(predicted_pos[1], positions[-1][1])

    def test_clamping(self):
        # The screen size is mocked in setUp
        self.predictor.screen_width, self.predictor.screen_height = 1920, 1080

        # Provide a history of positions moving towards the edge
        positions = [
            (1900, 1060),
            (1910, 1070),
            (1920, 1080),
            (1930, 1090), # This is outside the screen
        ]
        timestamps = [time.time() + i * 0.01 for i in range(len(positions))]

        predicted_pos = (0,0)
        for i in range(len(positions)):
            predicted_pos = self.predictor.predict_next_position(
                current_position=positions[i],
                timestamp=timestamps[i]
            )

        # The predicted position should be clamped to the screen boundaries
        self.assertLessEqual(predicted_pos[0], 1920)
        self.assertLessEqual(predicted_pos[1], 1080)

if __name__ == '__main__':
    unittest.main()
