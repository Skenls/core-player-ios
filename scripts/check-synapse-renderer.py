#!/usr/bin/env python3
"""Check real Synapse geometry; on macOS also compile/render its Metal shaders.

Run: python3 scripts/check-synapse-renderer.py
No Xcode or project dependencies required. UIKit lifecycle still needs iOS testing.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "CorePlayer/Features/Synapse/SynapseVisualizer.swift"
source = SOURCE.read_text()
geometry = source.split("// Portable geometry\n", 1)[1]

GEOMETRY_CHECK = r'''
private let geometry = SynapseGeometry(lowMemory: false)
precondition(geometry.points.count == 2000)
precondition(geometry.filaments.count == 48 * 8 * 2)
precondition(geometry.rays.count == 480 * 2)
for p in geometry.points {
    precondition(p.x * p.x + p.y * p.y + p.z * p.z <= 1.00001)
}
for i in stride(from: 0, to: geometry.rays.count, by: 2) {
    let head = geometry.rays[i], tail = geometry.rays[i + 1]
    precondition(head.x == tail.x && head.y == tail.y && head.z == -tail.z)
    precondition(abs(head.x * head.x + head.y * head.y - 1) < 0.00001)
}
private let small = SynapseGeometry(lowMemory: true)
precondition(small.points.count == 800 && small.filaments.count == 16 * 8 * 2 && small.rays.count == 360)
precondition(SynapseGeometry.boundedBPM(.nan) == 110)
precondition(SynapseGeometry.boundedBPM(.infinity) == 110)
precondition(SynapseGeometry.boundedBPM(0) == 60)
precondition(SynapseGeometry.boundedBPM(200) == 180)
print("Synapse geometry and BPM checks passed")
'''

GPU_CHECK = r'''
if let device = MTLCreateSystemDefaultDevice() {
    _ = try SynapseRenderer(device: device, pixelFormat: .bgra8Unorm)
    let library = try device.makeLibrary(source: SynapseRenderer.shader, options: nil)
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "synapseVertex")
    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    descriptor.colorAttachments[0].isBlendingEnabled = true
    descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
    descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
    descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    for name in ["synapseLine", "synapsePoint"] {
        descriptor.fragmentFunction = library.makeFunction(name: name)
        _ = try device.makeRenderPipelineState(descriptor: descriptor)
    }
    precondition(MemoryLayout<SynapseRenderer.Uniforms>.stride == 32)
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .bgra8Unorm, width: 32, height: 32, mipmapped: false)
    textureDescriptor.storageMode = .shared
    textureDescriptor.usage = [.renderTarget]
    let texture = device.makeTexture(descriptor: textureDescriptor)!
    let queue = device.makeCommandQueue()!
    let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    var position = SIMD4<Float>(1, 0, 0.5, 0)
    let vertexBuffer = device.makeBuffer(bytes: &position,
        length: MemoryLayout<SIMD4<Float>>.stride, options: .storageModeShared)!
    for white: Float in [0, 1] {
        var uniforms = SynapseRenderer.Uniforms(time: 0, aspect: 1, density: 1,
                                               tempo: 1, burst: 1, point: 1, white: white)
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let command = queue.makeCommandBuffer()!
        let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: 32, index: 1)
        encoder.setFragmentBytes(&uniforms, length: 32, index: 1)
        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 1)
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        precondition(command.status == .completed)
        var pixel = [UInt8](repeating: 0, count: 4)
        texture.getBytes(&pixel, bytesPerRow: 4,
                         from: MTLRegionMake2D(16, 16, 1, 1), mipmapLevel: 0)
        precondition(pixel[3] > 0)
        precondition(pixel[0] <= pixel[3] && pixel[1] <= pixel[3] && pixel[2] <= pixel[3])
        if white == 1 { precondition(pixel[0] == pixel[1] && pixel[1] == pixel[2]) }
        else { precondition(pixel[0] > pixel[2] && pixel[2] > pixel[1]) }
    }
    print("Synapse Swift renderer, Metal pipelines, GPU palettes and alpha checks passed")
} else {
    print("SKIP: Metal device unavailable; UIKit/device validation remains required")
}
'''


def run_swift(contents):
    with tempfile.NamedTemporaryFile(mode="w", suffix=".swift") as file:
        file.write(contents)
        file.flush()
        subprocess.run(["swift", "-swift-version", "5", file.name], check=True, cwd=ROOT)


subprocess.run(["swiftc", "-frontend", "-parse", str(SOURCE)], check=True, cwd=ROOT)
run_swift("import Foundation\n" + geometry + GEOMETRY_CHECK)
if sys.platform == "darwin":
    renderer = "private final class SynapseRenderer:" + source.split(
        "private final class SynapseRenderer:", 1)[1]
    # Only adapt UIKit's lifecycle/invalidating APIs for the macOS test host.
    # GPU buffers, uniforms, pipelines and embedded shaders are production source.
    renderer = renderer.replace("UIApplication.shared.applicationState == .active", "true")
    renderer = renderer.replace("view.setNeedsDisplay()", "view.needsDisplay = true")
    renderer = renderer.replace("private static let shader", "static let shader")
    renderer = renderer.replace("private struct Uniforms", "struct Uniforms")
    run_swift("import MetalKit\n" + renderer + GPU_CHECK)
else:
    print("SKIP: Metal GPU validation requires macOS")
