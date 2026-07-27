import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    let onBarcodeScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = BarcodeScannerModel()
    @State private var manualBarcode = ""

    var body: some View {
        NavigationView {
            ZStack {
                CameraPreview(session: scanner.session)
                    .ignoresSafeArea()

                Color.black.opacity(scanner.isRunning ? 0.2 : 0.55)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("Scan the Evidence")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(scanner.statusMessage)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.78))
                            .padding(.horizontal)
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(scanner.isRunning ? Color.green : Color.orange, lineWidth: 4)
                            .frame(width: 250, height: 160)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.08))
                            .frame(width: 250, height: 160)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        TextField("Enter barcode manually", text: $manualBarcode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .padding(12)
                            .background(Color.white.opacity(0.94))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button {
                            let barcode = manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !barcode.isEmpty else { return }
                            onBarcodeScanned(barcode)
                            dismiss()
                        } label: {
                            Label("Use Barcode", systemImage: "barcode")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding()
                    .background(Color.black.opacity(0.42))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.bottom)
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                scanner.start { barcode in
                    onBarcodeScanned(barcode)
                    dismiss()
                }
            }
            .onDisappear {
                scanner.stop()
            }
        }
    }
}

private final class BarcodeScannerModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()

    @Published private(set) var statusMessage = "Position the barcode inside the frame."
    @Published private(set) var isRunning = false

    private let sessionQueue = DispatchQueue(label: "my-fatness-tracker.barcode-scanner")
    private var isConfigured = false
    private var didScan = false
    private var onScan: ((String) -> Void)?

    func start(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
        didScan = false

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startAuthorizedSession()
        case .notDetermined:
            updateStatus("Camera access is needed to scan barcodes.")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                granted ? self.startAuthorizedSession() : self.updateStatus("Camera access is off. Enter the barcode manually or enable camera access in Settings.")
            }
        case .denied, .restricted:
            updateStatus("Camera access is off. Enter the barcode manually or enable camera access in Settings.")
        @unknown default:
            updateStatus("The app could not confirm camera access. Manual entry still works.")
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func startAuthorizedSession() {
        updateStatus("Position the barcode inside the frame.")

        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureSessionIfNeeded()
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async {
                    self.isRunning = true
                    self.statusMessage = "Looking for barcode..."
                }
            } catch {
                self.updateStatus(error.localizedDescription)
            }
        }
    }

    private func configureSessionIfNeeded() throws {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video) else {
            session.commitConfiguration()
            throw BarcodeScannerError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw BarcodeScannerError.cameraInputUnavailable
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw BarcodeScannerError.metadataOutputUnavailable
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)

        let requestedTypes: [AVMetadataObject.ObjectType] = [
            .ean8,
            .ean13,
            .upce,
            .code39,
            .code39Mod43,
            .code93,
            .code128,
            .itf14,
            .interleaved2of5,
            .pdf417,
            .qr,
            .aztec,
            .dataMatrix
        ]
        output.metadataObjectTypes = requestedTypes.filter { output.availableMetadataObjectTypes.contains($0) }

        session.commitConfiguration()
        isConfigured = true
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !barcode.isEmpty else {
            return
        }

        didScan = true
        updateStatus("Barcode found. Pulling up the receipts...")
        stop()
        onScan?(barcode)
    }

    private func updateStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private enum BarcodeScannerError: LocalizedError {
    case cameraUnavailable
    case cameraInputUnavailable
    case metadataOutputUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available on this device. Enter the barcode manually."
        case .cameraInputUnavailable:
            return "The app could not connect to the camera. Enter the barcode manually."
        case .metadataOutputUnavailable:
            return "The camera scanner could not read barcodes right now. Enter the barcode manually."
        }
    }
}
