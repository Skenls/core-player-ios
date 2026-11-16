import SwiftUI
import MetalKit
import UIKit

/// Static GPU geometry; only time and appearance uniforms change between frames.
public struct SynapseVisualizer: View {
    public var playing: Bool
    public var visible: Bool
    public var burst: Bool
    public var white: Bool
    public var bpm: Float

    public init(playing: Bool, visible: Bool, burst: Bool = true, white: Bool = true, bpm: Float = 110) {
        self.playing = playing
        self.visible = visible
        self.burst = burst
        self.white = white
        self.bpm = bpm
    }

    public var body: some View {
        SynapseMetalSurface(playing: playing, visible: visible, burst: burst, white: white, bpm: bpm)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct SynapseMetalSurface: UIViewRepresentable {
    let playing: Bool
    let visible: Bool
    let burst: Bool
    let white: Bool
    let bpm: Float

    func makeUIView(context: Context) -> SynapseMetalView {
        SynapseMetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
    }

    func updateUIView(_ view: SynapseMetalView, context: Context) {
        let tempo = SynapseGeometry.boundedBPM(bpm)
        guard view.playing != playing || view.visible != visible || view.renderer?.burst != burst ||
                view.renderer?.white != white || view.renderer?.bpm != tempo else { return }
        view.playing = playing
        view.visible = visible
        view.renderer?.burst = burst
        view.renderer?.white = white
        view.renderer?.bpm = tempo
        view.updateRendering()
    }

    static func dismantleUIView(_ view: SynapseMetalView, coordinator: ()) {
        view.visible = false
        view.updateRendering()
    }
}

private final class SynapseMetalView: MTKView {
    var playing = false
    var visible = false
    var renderer: SynapseRenderer?
    private var observers: [NSObjectProtocol] = []
    private var foreground = UIApplication.shared.applicationState == .active

    override var isHidden: Bool { didSet { updateRendering() } }
    override var alpha: CGFloat { didSet { updateRendering() } }

    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device)
        isOpaque = false
        backgroundColor = .clear
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        colorPixelFormat = .bgra8Unorm
        preferredFramesPerSecond = 30
        isPaused = true
        enableSetNeedsDisplay = true
        isAccessibilityElement = false
        if let device = device {
            do {
                renderer = try SynapseRenderer(device: device, pixelFormat: colorPixelFormat)
                delegate = renderer
            } catch {
                NSLog("Synapse renderer unavailable: %@", String(describing: error))
            }
        }
        let names: [Notification.Name] = [
            UIApplication.didBecomeActiveNotification,
            UIApplication.willResignActiveNotification,
            UIApplication.didEnterBackgroundNotification,
            .NSProcessInfoPowerStateDidChange,
            UIAccessibility.reduceMotionStatusDidChangeNotification
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                guard let self = self else { return }
                if notification.name == UIApplication.didBecomeActiveNotification {
                    self.foreground = true
                } else if notification.name == UIApplication.willResignActiveNotification ||
                            notification.name == UIApplication.didEnterBackgroundNotification {
                    self.foreground = false
                }
                self.updateRendering()
            }
        }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateRendering()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateRendering()
    }

    func updateRendering() {
        let shown = foreground && visible && window != nil && !isHidden && alpha > 0 &&
            !bounds.isEmpty && UIApplication.shared.applicationState == .active
        let animate = shown && playing && !UIAccessibility.isReduceMotionEnabled &&
            !ProcessInfo.processInfo.isLowPowerModeEnabled && renderer != nil
        renderer?.visible = shown
        renderer?.animating = animate
        if isPaused == animate { renderer?.previousTime = nil }
        isPaused = !animate
        enableSetNeedsDisplay = !animate
        if shown && !animate { setNeedsDisplay() }
    }
}

private final class SynapseRenderer: NSObject, MTKViewDelegate {
    var burst = true
    var white = true
    var bpm: Float = 110
    var visible = false
    var animating = false
    var previousTime: CFTimeInterval?
    private var seconds: Float = 0
    private let queue: MTLCommandQueue
    private let linePipeline: MTLRenderPipelineState
    private let pointPipeline: MTLRenderPipelineState
    private let points: MTLBuffer
    private let filaments: MTLBuffer
    private let rays: MTLBuffer
    private let pointCount: Int
    private let filamentCount: Int
    private let rayCount: Int

    // Eight floats, 32 bytes: the exact field order and size of Metal's Uniforms.
    private struct Uniforms {
        var time: Float
        var aspect: Float
        var density: Float
        var tempo: Float
        var burst: Float
        var point: Float
        var white: Float
        var padding: Float = 0
    }

    private enum SetupError: Error { case unavailable }

    init(device: MTLDevice, pixelFormat: MTLPixelFormat) throws {
        guard let queue = device.makeCommandQueue() else { throw SetupError.unavailable }
        self.queue = queue
        let library = try device.makeLibrary(source: Self.shader, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "synapseVertex")
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = pixelFormat
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .one
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.fragmentFunction = library.makeFunction(name: "synapseLine")
        linePipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.fragmentFunction = library.makeFunction(name: "synapsePoint")
        pointPipeline = try device.makeRenderPipelineState(descriptor: descriptor)

        let geometry = SynapseGeometry(lowMemory: ProcessInfo.processInfo.physicalMemory <= 2_147_483_648)
        func buffer(_ vertices: [SIMD4<Float>]) throws -> MTLBuffer {
            try vertices.withUnsafeBytes { bytes in
                guard let base = bytes.baseAddress,
                      let buffer = device.makeBuffer(bytes: base, length: bytes.count, options: .storageModeShared)
                else { throw SetupError.unavailable }
                return buffer
            }
        }
        points = try buffer(geometry.points)
        filaments = try buffer(geometry.filaments)
        rays = try buffer(geometry.rays)
        pointCount = geometry.points.count
        filamentCount = geometry.filaments.count
        rayCount = geometry.rays.count / 2
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if visible && view.isPaused { view.setNeedsDisplay() }
    }

    func draw(in view: MTKView) {
        guard visible, view.window != nil, UIApplication.shared.applicationState == .active,
              view.drawableSize.width > 0, view.drawableSize.height > 0 else { return }
        let now = CACurrentMediaTime()
        if animating, let previousTime = previousTime {
            seconds += Float(min(now - previousTime, 0.1))
        }
        previousTime = animating ? now : nil
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer(), let encoder = command.makeRenderCommandEncoder(descriptor: pass)
        else { return }
        var uniforms = Uniforms(
            time: seconds,
            aspect: Float(view.drawableSize.width / view.drawableSize.height),
            density: min(3, max(1, Float(min(view.drawableSize.width, view.drawableSize.height)) / 300)),
            tempo: bpm / 110, burst: burst ? 1 : 0, point: 0, white: white ? 1 : 0
        )
        func draw(_ buffer: MTLBuffer, type: MTLPrimitiveType, count: Int, point: Bool) {
            uniforms.point = point ? 1 : 0
            encoder.setRenderPipelineState(point ? pointPipeline : linePipeline)
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.drawPrimitives(type: type, vertexStart: 0, vertexCount: count)
        }
        if burst {
            let fraction = 0.35 + 0.65 * (bpm - 60) / 120
            draw(rays, type: .line, count: Int(Float(rayCount) * fraction) * 2, point: false)
            draw(rays, type: .point, count: 1, point: true)
        } else {
            draw(filaments, type: .line, count: filamentCount, point: false)
            draw(points, type: .point, count: pointCount, point: true)
        }
        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }

    private static let shader = """
    #include <metal_stdlib>
    using namespace metal;
    struct Uniforms {
        float time, aspect, density, tempo, burst, point, white, padding;
    };
    struct Vertex {
        float4 position [[position]];
        float size [[point_size]];
        float depth;
        float alpha;
    };
    vertex Vertex synapseVertex(uint id [[vertex_id]],
        constant float4 *positions [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
        float3 p = positions[id].xyz;
        float2 aspect = float2(min(1.0f, 1.0f / u.aspect), min(1.0f, u.aspect));
        Vertex out;
        out.alpha = 1.0;
        if (u.burst > 0.5) {
            float phase = fract(abs(p.z) - 0.1 + u.time * 0.26 * u.tempo);
            float head = 0.018 + phase * phase * length(1.0 / aspect);
            float tail = max(0.008f, head - (0.012 + phase * 0.16));
            float endpoint = step(0.0f, p.z);
            float2 xy = p.xy * mix(tail, head, endpoint);
            out.depth = phase;
            out.alpha = smoothstep(0.0f, 0.12f, phase) * (1.0 - smoothstep(0.78f, 1.0f, phase));
            out.alpha *= mix(0.08f, 1.0f, endpoint);
            if (u.point > 0.5) { xy = 0; out.depth = 1; out.alpha = 1; }
            out.position = float4(xy * aspect, 0, 1);
            out.size = 8.0 * u.density;
            return out;
        }
        float t = u.time * 0.22;
        p -= 0.065 * cos(p.zxy * 3.0 + t);
        float a = t + p.y * 0.12 * sin(t * 0.7);
        // Match the column-major GLSL mat2 used by the Android sphere.
        p.xz = float2(cos(a) * p.x + sin(a) * p.z, -sin(a) * p.x + cos(a) * p.z);
        p *= 1.0 + 0.025 * sin(u.time * 0.8);
        float perspective = 2.8 / (3.2 - p.z * 0.5);
        out.position = float4(p.xy * perspective * 0.81 * aspect, 0, 1);
        out.size = (1.6 + 1.8 * (p.z + 1.0) * 0.5) * u.density;
        out.depth = clamp((p.z + 1.2) / 2.4, 0.0f, 1.0f);
        return out;
    }
    float4 synapseColor(Vertex in, constant Uniforms &u, float pointAlpha) {
        float alpha = (0.16 + in.depth * 0.48) * in.alpha * pointAlpha;
        float3 color = mix(float3(0.34, 0.15, 0.85), float3(0.84, 0.62, 1.0), in.depth);
        color = mix(color, float3(1.0), u.white);
        return float4(color * alpha, alpha);
    }
    fragment float4 synapseLine(Vertex in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
        return synapseColor(in, u, mix(0.5f, 1.0f, u.burst));
    }
    fragment float4 synapsePoint(Vertex in [[stage_in]], float2 coord [[point_coord]],
        constant Uniforms &u [[buffer(1)]]) {
        return synapseColor(in, u, 1.0 - smoothstep(0.12f, 1.0f, length(coord - 0.5) * 2.0));
    }
    """
}

// Portable geometry
private struct SynapseGeometry {
    var points: [SIMD4<Float>] = []
    var filaments: [SIMD4<Float>] = []
    var rays: [SIMD4<Float>] = []

    static func boundedBPM(_ bpm: Float) -> Float {
        bpm.isFinite ? min(180, max(60, bpm)) : 110
    }

    init(lowMemory: Bool) {
        var seed: UInt64 = 7391
        func random() -> Float {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Float(seed >> 40) / Float(1 << 24)
        }
        for _ in 0..<(lowMemory ? 800 : 2000) {
            let z = random() * 2 - 1
            let angle = random() * 2 * .pi
            let radius = pow(random(), 1 / Float(3))
            let ring = sqrt(1 - z * z) * radius
            points.append(SIMD4(cos(angle) * ring, sin(angle) * ring, z * radius, 0))
        }
        for _ in 0..<(lowMemory ? 16 : 48) {
            let azimuth = random() * 2 * .pi
            let elevation = random() * 2.4 - 1.2
            let radius = 0.3 + random() * 0.68
            for segment in 0..<8 {
                for endpoint in 0..<2 {
                    let angle = azimuth + Float(segment + endpoint) * 0.045
                    let latitude = elevation + 0.12 * sin(angle * 3)
                    filaments.append(SIMD4(radius * cos(latitude) * cos(angle), radius * sin(latitude),
                                           radius * cos(latitude) * sin(angle), 0))
                }
            }
        }
        for _ in 0..<(lowMemory ? 180 : 480) {
            let angle = random() * 2 * .pi
            let phase = random() + 0.1
            rays.append(SIMD4(cos(angle), sin(angle), phase, 0))
            rays.append(SIMD4(cos(angle), sin(angle), -phase, 0))
        }
    }
}
