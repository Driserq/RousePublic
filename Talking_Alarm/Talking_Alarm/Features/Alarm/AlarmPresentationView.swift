import SwiftUI
import AVFoundation

struct AlarmPresentationView: View {
    @State private var isPlaying = false
    @State private var showTapToStart = false
    @State private var audioPlayer: AVAudioPlayer?
    
    let onTapToStart: () -> Void
    
    var body: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Alarm icon with pulsing animation
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 200, height: 200)
                        .scaleEffect(isPlaying ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPlaying)
                    
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .scaleEffect(isPlaying ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPlaying)
                }
                
                // Alarm title
                VStack(spacing: 16) {
                    Text("Talking Alarm")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Time to wake up!")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Tap to start button (appears after audio plays)
                if showTapToStart {
                    Button(action: {
                        onTapToStart()
                    }) {
                        VStack(spacing: 12) {
                            Text("Tap anywhere to start")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Image(systemName: "hand.tap.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
            }
            .padding()
        }
        .onTapGesture {
            // Allow tapping anywhere on the screen to start
            onTapToStart()
        }
        .onAppear {
            startAlarmSequence()
        }
    }
    
    private func startAlarmSequence() {
        // Start the pulsing animation
        isPlaying = true
        
        // Play the pre-recorded message
        Task {
            await playPersonalWakeMessage()
        }
        
        // Show "tap to start" after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showTapToStart = true
            }
        }
    }
    
    private func playPersonalWakeMessage() async {
        guard let audioURL = getPersonalWakeMessageURL() else {
            DebugLogger.log("[AlarmPresentationView] Personal wake message not found")
            return
        }
        
        DebugLogger.log("[AlarmPresentationView] Found wake message at: \(audioURL.path)")
        
        // Check file size and validity
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            DebugLogger.log("[AlarmPresentationView] Audio file size: \(fileSize) bytes")
            
            if fileSize == 0 {
                DebugLogger.log("[AlarmPresentationView] ERROR: Audio file is empty!")
                return
            }
        } catch {
            DebugLogger.log("[AlarmPresentationView] Could not read file attributes: \(error)")
        }
        
        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers]) // Duck others to ensure we are heard
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            DebugLogger.log("[AlarmPresentationView] Audio session configured and activated successfully")
            
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            DebugLogger.log("[AlarmPresentationView] Audio player created successfully")
            DebugLogger.log("[AlarmPresentationView] Audio duration: \(audioPlayer?.duration ?? 0) seconds")
            
            // Set volume to max just in case
            audioPlayer?.volume = 1.0
            
            let prepared = audioPlayer?.prepareToPlay() ?? false
            DebugLogger.log("[AlarmPresentationView] Audio player prepared: \(prepared)")
            
            let started = audioPlayer?.play() ?? false
            DebugLogger.log("[AlarmPresentationView] Audio player started: \(started)")
            DebugLogger.log("[AlarmPresentationView] Audio player is playing: \(audioPlayer?.isPlaying ?? false)")
            
            if !started {
                DebugLogger.log("[AlarmPresentationView] Audio playback failed to start!")
                return
            }
            
            // Wait for playback to complete (simple polling for this context)
            var playbackTime = 0.0
            while audioPlayer?.isPlaying == true {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                playbackTime += 0.1
                if playbackTime > 60.0 { // Safety timeout after 60 seconds (since we have longer files now)
                    DebugLogger.log("[AlarmPresentationView] Playback timeout after 60 seconds")
                    break
                }
            }
            DebugLogger.log("[AlarmPresentationView] Wake message playback completed after \(playbackTime) seconds")
        } catch let error as NSError where error.code == 561015905 {
            DebugLogger.log("[AlarmPresentationView] Audio session already active (likely AlarmKit). Skipping manual playback.")
            return // Exit gracefully, assuming audio is playing
        } catch {
            DebugLogger.log("[AlarmPresentationView] Failed to play personal wake message: \(error)")
        }
    }
    
    private func getPersonalWakeMessageURL() -> URL? {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsPath = libraryPath.appendingPathComponent("Sounds")
        let audioURL = soundsPath.appendingPathComponent("personal-wake-message.m4a")

        // Fallback to old Documents/Library/Sounds if present
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacyPath = documentsPath.appendingPathComponent("Library/Sounds")
        let legacyURL = legacyPath.appendingPathComponent("personal-wake-message.m4a")

        func debugList(_ path: URL) {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: path.path)
                DebugLogger.log("[AlarmPresentationView] Files in sounds directory (\(path.lastPathComponent)): \(files)")
            } catch {
                DebugLogger.log("[AlarmPresentationView] Could not list sounds directory \(path): \(error)")
            }
        }

        DebugLogger.log("[AlarmPresentationView] Checking for wake message at: \(audioURL.path)")
        DebugLogger.log("[AlarmPresentationView] File exists: \(FileManager.default.fileExists(atPath: audioURL.path))")
        debugList(soundsPath)

        if FileManager.default.fileExists(atPath: audioURL.path) {
            return audioURL
        }

        DebugLogger.log("[AlarmPresentationView] Falling back to legacy path: \(legacyURL.path)")
        DebugLogger.log("[AlarmPresentationView] Legacy exists: \(FileManager.default.fileExists(atPath: legacyURL.path))")
        debugList(legacyPath)

        return FileManager.default.fileExists(atPath: legacyURL.path) ? legacyURL : nil
    }
}

#Preview {
    AlarmPresentationView {
        DebugLogger.log("Tap to start pressed")
    }
}

