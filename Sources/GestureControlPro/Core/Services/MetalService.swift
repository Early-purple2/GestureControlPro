import Metal
import MetalPerformanceShaders

class MetalService {
    static let shared = MetalService()
    private init() {}
    func configure(with device: MTLDevice) { /*...*/ }
    func setupHandTrackingPipeline() { /*...*/ }
}

