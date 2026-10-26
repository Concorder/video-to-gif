import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

@main struct ClipTextApp: App {
    var body: some Scene { WindowGroup { EditorView() } }
}

struct EditorView: View {
    @State private var selection: PhotosPickerItem?
    @State private var source: URL?
    @State private var player: AVPlayer?
    @State private var link = ""
    @AppStorage("resolver") private var resolver = ""
    @State private var caption = "Your story, your words"
    @State private var format = FrameFormat.vertical
    @State private var gif = false
    @State private var busy = false
    @State private var message: String?
    @State private var output: URL?
    @State private var settings = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Make a moment.\nMake it yours.").font(.largeTitle.bold())
                    Text("Import a clip, frame it, and add your words.").foregroundStyle(.secondary)
                    HStack {
                        TextField("Paste YouTube, TikTok or video URL", text: $link).textInputAutocapitalization(.never).keyboardType(.URL)
                        Button { run { source = try await VideoImporter.load(link, resolver: resolver); player = AVPlayer(url: source!) } } label: { Image(systemName: "arrow.down.circle.fill").font(.title) }.disabled(busy || link.isEmpty)
                    }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    PhotosPicker(selection: $selection, matching: .videos) { Label("Choose from Photos", systemImage: "photo.on.rectangle") }
                    if let player {
                        ZStack(alignment: .bottom) {
                            VideoPlayer(player: player)
                            Text(caption).font(.title2.bold()).foregroundStyle(.white).shadow(color: .black, radius: 3).multilineTextAlignment(.center).padding(24).allowsHitTesting(false)
                        }.aspectRatio(format.ratio, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 20))
                        Text("Preview shows the text position. Export fills the selected frame with a centered crop.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView("Your next great clip", systemImage: "film.stack", description: Text("Choose a video to start editing."))
                    }
                    Picker("Frame", selection: $format) { ForEach(FrameFormat.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    TextField("Text on your video", text: $caption, axis: .vertical).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    Toggle("Export as GIF (first 6 seconds, no audio)", isOn: $gif)
                    Button { run { guard let source else { return }; output = try await VideoExporter.export(source, caption: caption, format: format, gif: gif) } } label: {
                        HStack { Spacer(); if busy { ProgressView() }; Text(busy ? "Working…" : "Create \(gif ? "GIF" : "video")").bold(); Spacer() }.padding(8)
                    }.buttonStyle(.borderedProminent).disabled(source == nil || busy)
                    if let output { ShareLink(item: output) { Label("Save or share your clip", systemImage: "square.and.arrow.up") } }
                    if let message { Text(message).foregroundStyle(.red).font(.callout) }
                }.padding()
            }.navigationTitle("ClipText").toolbar { Button { settings = true } label: { Image(systemName: "gearshape") } }
            .sheet(isPresented: $settings) { NavigationStack { Form { TextField("HTTPS import service URL", text: $resolver).textInputAutocapitalization(.never); Text("For YouTube and TikTok, configure a service that accepts POST {url} and returns {videoURL}. Use videos you have permission to edit. Direct HTTPS video links work without a service.") }.navigationTitle("Link imports").toolbar { Button("Done") { settings = false } } } }
            .onChange(of: selection) { _, item in
                run {
                    guard let data = try await item?.loadTransferable(type: Data.self) else { return }
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                    try data.write(to: url); source = url; player = AVPlayer(url: url); output = nil
                }
            }
        }.tint(.indigo)
    }
    private func run(_ operation: @escaping () async throws -> Void) {
        busy = true; message = nil; output = nil
        Task { @MainActor in defer { busy = false }; do { try await operation() } catch { message = error.localizedDescription } }
    }
}
