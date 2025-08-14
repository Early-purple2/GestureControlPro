import Foundation
import CoreGraphics
import Accelerate

// MARK: - KalmanFilter

/// A Kalman filter implementation for smoothing 2D point data (CGPoint).
///
/// This filter is designed to reduce jitter in real-time tracking applications.
/// It models the state of a point as its position and velocity, and uses a
/// constant velocity model for prediction.
class KalmanFilter {

    // MARK: - State Vectors and Matrices

    /// State vector [x, y, vx, vy] - position and velocity.
    private var x: [Double]

    /// Covariance matrix P - uncertainty of the state.
    private var P: [Double]

    /// State transition matrix A.
    private let A: [Double]

    /// Measurement matrix H.
    private let H: [Double]

    /// Process noise covariance Q.
    private let Q: [Double]

    /// Measurement noise covariance R.
    private let R: [Double]

    /// Identity matrix.
    private let I: [Double]

    private let stateSize: Int = 4
    private let measurementSize: Int = 2

    /// The last timestamp of a measurement. Used to calculate delta time `dt`.
    private var lastTimestamp: TimeInterval?

    /// The filtered point after the latest update.
    var currentEstimate: CGPoint {
        return CGPoint(x: x[0], y: x[1])
    }

    // MARK: - Initialization

    /// Initializes the Kalman filter with an initial point.
    /// - Parameters:
    ///   - initialPoint: The first measured point.
    ///   - processNoise: How much uncertainty is in the process model.
    ///   - measurementNoise: How much uncertainty is in the sensor measurement.
    init(initialPoint: CGPoint, processNoise: Double = 1e-4, measurementNoise: Double = 1e-2) {

        // Initial state: [x, y, 0, 0]
        self.x = [initialPoint.x, initialPoint.y, 0, 0]

        // Initial covariance: High uncertainty
        self.P = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1000, 0,
            0, 0, 0, 1000
        ]

        // State transition matrix A (constant velocity model)
        // Filled dynamically in predict() based on dt
        self.A = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ]

        // Measurement matrix H (we only measure position)
        self.H = [
            1, 0, 0, 0,
            0, 1, 0, 0
        ]

        // Process noise covariance Q
        self.Q = [
            processNoise, 0, 0, 0,
            0, processNoise, 0, 0,
            0, 0, processNoise, 0,
            0, 0, 0, processNoise
        ]

        // Measurement noise covariance R
        self.R = [
            measurementNoise, 0,
            0, measurementNoise
        ]

        // Identity matrix
        self.I = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        ]
    }

    // MARK: - Filter Steps

    /// Predicts the next state.
    private func predict(dt: Double) {
        var a = self.A
        a[2] = dt // A[0,2]
        a[7] = dt // A[1,3]

        // x_pred = A * x
        x = multiply(matrix: a, vector: x)

        // P_pred = A * P * A_T + Q
        let a_t = transpose(matrix: a, rows: stateSize, cols: stateSize)
        let ap = multiply(matrixA: a, matrixB: P, m: stateSize, n: stateSize, p: stateSize)
        let apa_t = multiply(matrixA: ap, matrixB: a_t, m: stateSize, n: stateSize, p: stateSize)
        P = add(matrixA: apa_t, matrixB: Q)
    }

    /// Updates the state with a new measurement.
    /// - Parameter measurement: The new measured point.
    /// - Returns: The corrected (smoothed) point.
    func update(measurement: CGPoint) -> CGPoint {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = lastTimestamp.map { now - $0 } ?? 0.0
        lastTimestamp = now

        // Prediction step
        predict(dt: dt)

        let z = [measurement.x, measurement.y]

        // y = z - H * x
        let hx = multiply(matrix: H, vector: x)
        let y = subtract(vectorA: z, vectorB: hx)

        // S = H * P * H_T + R
        let h_t = transpose(matrix: H, rows: measurementSize, cols: stateSize)
        let hph_t = multiply(matrixA: multiply(matrixA: H, matrixB: P, m: measurementSize, n: stateSize, p: stateSize),
                             matrixB: h_t, m: measurementSize, n: stateSize, p: measurementSize)
        let S = add(matrixA: hph_t, matrixB: R)

        // K = P * H_T * S^-1 (Kalman Gain)
        let s_inv = invert(matrix: S)
        let ph_t = multiply(matrixA: P, matrixB: h_t, m: stateSize, n: stateSize, p: measurementSize)
        let K = multiply(matrixA: ph_t, matrixB: s_inv, m: stateSize, n: measurementSize, p: measurementSize)

        // x_new = x + K * y
        let ky = multiply(matrix: K, vector: y)
        x = add(vectorA: x, vectorB: ky)

        // P_new = (I - K * H) * P
        let kh = multiply(matrixA: K, matrixB: H, m: stateSize, n: measurementSize, p: stateSize)
        let ikh = subtract(matrixA: I, matrixB: kh)
        P = multiply(matrixA: ikh, matrixB: P, m: stateSize, n: stateSize, p: stateSize)

        return self.currentEstimate
    }

    // MARK: - Linear Algebra Helpers (using Accelerate)

    private func multiply(matrix: [Double], vector: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: vector.count)
        vDSP_mmulD(matrix, 1, vector, 1, &result, 1, vDSP_Length(vector.count), vDSP_Length(1), vDSP_Length(vector.count))
        return result
    }

    private func multiply(matrixA: [Double], matrixB: [Double], m: Int, n: Int, p: Int) -> [Double] {
        var result = [Double](repeating: 0, count: m * p)
        vDSP_mmulD(matrixA, 1, matrixB, 1, &result, 1, vDSP_Length(m), vDSP_Length(p), vDSP_Length(n))
        return result
    }

    private func add(matrixA: [Double], matrixB: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: matrixA.count)
        vDSP_vaddD(matrixA, 1, matrixB, 1, &result, 1, vDSP_Length(matrixA.count))
        return result
    }

    private func add(vectorA: [Double], vectorB: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: vectorA.count)
        vDSP_vaddD(vectorA, 1, vectorB, 1, &result, 1, vDSP_Length(vectorA.count))
        return result
    }

    private func subtract(matrixA: [Double], matrixB: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: matrixA.count)
        vDSP_vsubD(matrixB, 1, matrixA, 1, &result, 1, vDSP_Length(matrixA.count))
        return result
    }

    private func subtract(vectorA: [Double], vectorB: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: vectorA.count)
        vDSP_vsubD(vectorB, 1, vectorA, 1, &result, 1, vDSP_Length(vectorA.count))
        return result
    }

    private func transpose(matrix: [Double], rows: Int, cols: Int) -> [Double] {
        var result = [Double](repeating: 0, count: rows * cols)
        vDSP_mtransD(matrix, 1, &result, 1, vDSP_Length(cols), vDSP_Length(rows))
        return result
    }

    private func invert(matrix: [Double]) -> [Double] {
        var inMatrix = matrix
        var N = __CLPK_integer(sqrt(Double(matrix.count)))
        var pivots = [__CLPK_integer](repeating: 0, count: Int(N))
        var workspace = [Double](repeating: 0, count: Int(N))
        var error: __CLPK_integer = 0

        dgetrf_(&N, &N, &inMatrix, &N, &pivots, &error)
        dgetri_(&N, &inMatrix, &N, &pivots, &workspace, &N, &error)

        return inMatrix
    }
}
