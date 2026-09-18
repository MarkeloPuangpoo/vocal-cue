import AVFoundation
import Combine
import Accelerate

// MARK: - Reverb Preset Descriptor

struct ReverbPresetOption: Identifiable, Hashable {
    let id: AVAudioUnitReverbPreset
    let name: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.rawValue)
    }

    static func == (lhs: ReverbPresetOption, rhs: ReverbPresetOption) -> Bool {
        lhs.id.rawValue == rhs.id.rawValue
    }
}

let reverbPresets: [ReverbPresetOption] = [
    ReverbPresetOption(id: .smallRoom, name: "Small Room"),
    ReverbPresetOption(id: .mediumRoom, name: "Medium Room"),
    ReverbPresetOption(id: .largeRoom, name: "Large Room"),
    ReverbPresetOption(id: .mediumHall, name: "Medium Hall"),
    ReverbPresetOption(id: .largeHall, name: "Large Hall"),
    ReverbPresetOption(id: .cathedral, name: "Cathedral"),
    ReverbPresetOption(id: .plate, name: "Plate"),
    ReverbPresetOption(id: .mediumChamber, name: "Medium Chamber"),
    ReverbPresetOption(id: .largeChamber, name: "Large Chamber"),
]

// MARK: - UserDefaults Keys

private enum SettingsKey {
    static let monitorVolume = "inear.monitorVolume"
    static let micGain = "inear.micGain"
    static let reverbEnabled = "inear.reverbEnabled"
    static let reverbWetDryMix = "inear.reverbWetDryMix"
    static let reverbPreset = "inear.reverbPreset"
    static let delayEnabled = "inear.delayEnabled"
    static let delayTime = "inear.delayTime"
    static let delayFeedback = "inear.delayFeedback"
    static let delayWetDryMix = "inear.delayWetDryMix"

    // Audio Processing DSP keys
    static let lowCutEnabled = "inear.lowCutEnabled"
    static let eqEnabled = "inear.eqEnabled"
    static let eqLowGain = "inear.eqLowGain"
    static let eqMidGain = "inear.eqMidGain"
    static let eqHighGain = "inear.eqHighGain"
    static let noiseGateEnabled = "inear.noiseGateEnabled"
    static let noiseGateThreshold = "inear.noiseGateThreshold"
    static let limiterEnabled = "inear.limiterEnabled"
}

// MARK: - AudioEngineManager

class AudioEngineManager: ObservableObject {

    // MARK: - Audio Nodes

    private var engine = AVAudioEngine()
    private let gainMixer = AVAudioMixerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 4)
    private let gateNode: AVAudioUnitEffect = {
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: desc)
    }()
    private let reverbNode = AVAudioUnitReverb()
    private let delayNode = AVAudioUnitDelay()
    private let limiterNode: AVAudioUnitEffect = {
        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: desc)
    }()

    // MARK: - Sub-managers

    let deviceManager = AudioDeviceManager()

    // MARK: - State

    @Published var isRunning = false
    @Published var showSpeakerWarning = false
    @Published var showClockWarning = false

    // MARK: - Volume Controls

    @Published var monitorVolume: Float = 0.7 {
        didSet {
            guard isRunning else { return }
            engine.mainMixerNode.outputVolume = monitorVolume
        }
    }
    @Published var micGain: Float = 1.0 {
        didSet {
            guard isRunning else { return }
            gainMixer.outputVolume = micGain
        }
    }

    // MARK: - Reverb Controls

    @Published var reverbEnabled: Bool = false {
        didSet { applyReverbMix() }
    }
    @Published var reverbWetDryMix: Float = 30 {
        didSet { applyReverbMix() }
    }
    @Published var reverbPreset: AVAudioUnitReverbPreset = .mediumHall {
        didSet {
            reverbNode.loadFactoryPreset(reverbPreset)
            applyReverbMix()
        }
    }

    // MARK: - Delay Controls

    @Published var delayEnabled: Bool = false {
        didSet { applyDelayMix() }
    }
    @Published var delayTime: TimeInterval = 0.08 {
        didSet { delayNode.delayTime = delayTime }
    }
    @Published var delayFeedback: Float = 20 {
        didSet { delayNode.feedback = delayFeedback }
    }
    @Published var delayWetDryMix: Float = 20 {
        didSet { applyDelayMix() }
    }

    // MARK: - EQ & Filter Controls

    @Published var lowCutEnabled: Bool = true {
        didSet { applyEQSettings() }
    }
    @Published var eqEnabled: Bool = false {
        didSet { applyEQSettings() }
    }
    @Published var eqLowGain: Float = 0.0 {
        didSet { applyEQSettings() }
    }
    @Published var eqMidGain: Float = 0.0 {
        didSet { applyEQSettings() }
    }
    @Published var eqHighGain: Float = 0.0 {
        didSet { applyEQSettings() }
    }

    // MARK: - Noise Gate Controls

    @Published var noiseGateEnabled: Bool = false {
        didSet { applyGateSettings() }
    }
    @Published var noiseGateThreshold: Float = -45.0 {
        didSet { applyGateSettings() }
    }
    @Published var isGateOpen: Bool = true

    // MARK: - Ear Safe Limiter Controls

    @Published var limiterEnabled: Bool = true {
        didSet { applyLimiterSettings() }
    }
    @Published var isLimiterActive: Bool = false

    // MARK: - Live Audio Recording (Master Post-Effects)

    @Published var isRecording: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastRecordedFileURL: URL? = nil

    private var recordingFile: AVAudioFile? = nil
    private var currentRecordingURL: URL? = nil
    private let recordingQueue = DispatchQueue(label: "com.vocalcue.recordingQueue", qos: .userInitiated)
    private var recordingTimer: Timer? = nil
    private var recordingStartDate: Date? = nil

    // MARK: - Level Metering

    @Published var inputLevelLeft: Float = -60
    @Published var inputLevelRight: Float = -60
    @Published var peakLevel: Float = -60

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var configObserver: NSObjectProtocol?
    private var isRestarting = false

    // MARK: - Init

    init() {
        loadSettings()
        setupObservers()
    }

    deinit {
        stop()
        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    func start() {
        guard !isRunning else { return }

        do {
            // Remove previous config observer
            if let observer = configObserver {
                NotificationCenter.default.removeObserver(observer)
                configObserver = nil
            }

            // Fresh engine each start to avoid stale state
            engine.stop()
            engine.reset()
            engine = AVAudioEngine()

            // Request low-latency buffer sizes (via Core Audio HAL)
            if let inputID = deviceManager.selectedInputDeviceID {
                deviceManager.setBufferSize(256, forDevice: inputID)
            }
            if let outputID = deviceManager.selectedOutputDeviceID {
                deviceManager.setBufferSize(256, forDevice: outputID)
            }

            // Check clock domain compatibility
            checkClockDomains()

            // Attach processing nodes
            engine.attach(gainMixer)
            engine.attach(eqNode)
            engine.attach(gateNode)
            engine.attach(reverbNode)
            engine.attach(delayNode)
            engine.attach(limiterNode)

            // Configure DSP processing nodes
            setupEQNode()
            setupGateNode()
            setupLimiterNode()

            // Configure effects
            reverbNode.loadFactoryPreset(reverbPreset)
            applyReverbMix()

            delayNode.delayTime = delayTime
            delayNode.feedback = delayFeedback
            delayNode.lowPassCutoff = 15000
            applyDelayMix()

            // Build the audio chain
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                print("[VocalCue] Invalid input format: \(inputFormat)")
                return
            }

            // Create stereo processing format (effects like AVAudioUnitReverb require stereo channels)
            let processingFormat = AVAudioFormat(
                standardFormatWithSampleRate: inputFormat.sampleRate,
                channels: 2
            ) ?? inputFormat

            // Chain: Input (mono/stereo) → GainMixer → EQ (stereo) → Gate (stereo) → Reverb (stereo) → Delay (stereo) → Limiter (stereo) → MainMixer (stereo) → Output
            engine.connect(inputNode, to: gainMixer, format: inputFormat)
            engine.connect(gainMixer, to: eqNode, format: processingFormat)
            engine.connect(eqNode, to: gateNode, format: processingFormat)
            engine.connect(gateNode, to: reverbNode, format: processingFormat)
            engine.connect(reverbNode, to: delayNode, format: processingFormat)
            engine.connect(delayNode, to: limiterNode, format: processingFormat)
            engine.connect(limiterNode, to: engine.mainMixerNode, format: processingFormat)

            // Apply volume settings
            gainMixer.outputVolume = micGain
            engine.mainMixerNode.outputVolume = monitorVolume

            // Start level metering
            installLevelTap()

            // Observe audio configuration changes (device hot-swap, sample rate change, etc.)
            observeEngineConfiguration()

            // Launch the engine
            engine.prepare()
            try engine.start()

            DispatchQueue.main.async {
                self.isRunning = true
            }

            print("[VocalCue] Audio engine started — Format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")

        } catch {
            print("[VocalCue] Failed to start engine: \(error.localizedDescription)")
        }
    }

    func stop() {
        if isRecording {
            stopRecording()
        }

        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
            configObserver = nil
        }

        removeLevelTap()
        if engine.isRunning {
            engine.stop()
        }
        engine.reset()

        DispatchQueue.main.async {
            self.isRunning = false
            self.inputLevelLeft = -60
            self.inputLevelRight = -60
            self.peakLevel = -60
        }
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    // MARK: - Live Audio Recording API

    func startRecording() {
        guard !isRecording else { return }

        // Automatically start engine if not already running
        if !isRunning {
            start()
        }

        // Target directory: ~/Music/VocalCue Recordings/
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Music")
        let recordDir = musicDir.appendingPathComponent("VocalCue Recordings")

        do {
            try FileManager.default.createDirectory(at: recordDir, withIntermediateDirectories: true)
        } catch {
            print("[VocalCue] Failed to create recordings directory: \(error.localizedDescription)")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "VocalCue_Take_\(formatter.string(from: Date())).wav"
        let fileURL = recordDir.appendingPathComponent(filename)

        let sampleRate: Double = engine.inputNode.outputFormat(forBus: 0).sampleRate > 0
            ? engine.inputNode.outputFormat(forBus: 0).sampleRate
            : 48000.0

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        do {
            let file = try AVAudioFile(forWriting: fileURL, settings: settings)
            self.recordingFile = file
            self.currentRecordingURL = fileURL
            self.isRecording = true
            self.recordingDuration = 0
            self.recordingStartDate = Date()

            // Start live duration update timer
            self.recordingTimer?.invalidate()
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let start = self.recordingStartDate else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
            RunLoop.main.add(timer, forMode: .common)
            self.recordingTimer = timer

            print("[VocalCue] 🎙️ Live recording started: \(fileURL.path)")
        } catch {
            print("[VocalCue] Failed to create recording file: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false

        recordingQueue.async { [weak self] in
            guard let self else { return }
            let fileURL = self.currentRecordingURL
            self.recordingFile = nil
            self.currentRecordingURL = nil

            DispatchQueue.main.async {
                self.lastRecordedFileURL = fileURL
                print("[VocalCue] ⏹ Recording saved: \(fileURL?.path ?? "")")
            }
        }
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func restart() {
        guard !isRestarting else { return }
        isRestarting = true

        if isRunning {
            stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.start()
                self?.isRestarting = false
            }
        } else {
            isRestarting = false
        }
    }

    // MARK: - Engine Configuration Change (Device Hot-Swap)

    /// Subscribe to AVAudioEngine configuration change notifications.
    /// Fires when the user unplugs headphones, plugs in a USB mic, etc.
    private func observeEngineConfiguration() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            print("[VocalCue] ⚠️ Audio configuration changed (device hot-swap detected)")
            DispatchQueue.main.async {
                self.restart()
            }
        }
    }

    // MARK: - Clock Domain Check

    private func checkClockDomains() {
        guard let inputID = deviceManager.selectedInputDeviceID,
              let outputID = deviceManager.selectedOutputDeviceID else {
            showClockWarning = false
            return
        }
        let sameClock = deviceManager.areDevicesOnSameClock(inputID: inputID, outputID: outputID)
        DispatchQueue.main.async {
            self.showClockWarning = !sameClock
        }
    }

    // MARK: - Effect & DSP Application

    private func applyReverbMix() {
        reverbNode.wetDryMix = reverbEnabled ? reverbWetDryMix : 0
    }

    private func applyDelayMix() {
        delayNode.wetDryMix = delayEnabled ? delayWetDryMix : 0
    }

    private func setupEQNode() {
        guard eqNode.bands.count >= 4 else { return }

        // Band 0: High-Pass Filter (Low-Cut at 80Hz)
        let hp = eqNode.bands[0]
        hp.filterType = .highPass
        hp.frequency = 80.0

        // Band 1: Low Shelf (150Hz)
        let low = eqNode.bands[1]
        low.filterType = .lowShelf
        low.frequency = 150.0

        // Band 2: Mid Parametric (2500Hz)
        let mid = eqNode.bands[2]
        mid.filterType = .parametric
        mid.frequency = 2500.0
        mid.bandwidth = 1.0

        // Band 3: High Shelf (8000Hz)
        let high = eqNode.bands[3]
        high.filterType = .highShelf
        high.frequency = 8000.0

        applyEQSettings()
    }

    private func applyEQSettings() {
        guard eqNode.bands.count >= 4 else { return }

        // Low-Cut can operate independently of 3-Band EQ
        eqNode.bands[0].bypass = !lowCutEnabled

        // 3-Band EQ gains (flat 0dB if EQ is bypassed)
        eqNode.bands[1].gain = eqEnabled ? eqLowGain : 0.0
        eqNode.bands[2].gain = eqEnabled ? eqMidGain : 0.0
        eqNode.bands[3].gain = eqEnabled ? eqHighGain : 0.0

        // Entire EQ node bypass
        eqNode.bypass = !lowCutEnabled && !eqEnabled
    }

    private func setupGateNode() {
        let au = gateNode.audioUnit
        // Attack 3ms, Release 80ms
        AudioUnitSetParameter(au, 4, kAudioUnitScope_Global, 0, 0.003, 0)
        AudioUnitSetParameter(au, 5, kAudioUnitScope_Global, 0, 0.080, 0)
        AudioUnitSetParameter(au, 0, kAudioUnitScope_Global, 0, 0.0, 0)
        AudioUnitSetParameter(au, 1, kAudioUnitScope_Global, 0, 20.0, 0)
        AudioUnitSetParameter(au, 6, kAudioUnitScope_Global, 0, 0.0, 0)
        applyGateSettings()
    }

    private func applyGateSettings() {
        let au = gateNode.audioUnit
        if noiseGateEnabled {
            gateNode.bypass = false
            AudioUnitSetParameter(au, 3, kAudioUnitScope_Global, 0, noiseGateThreshold, 0)
            AudioUnitSetParameter(au, 2, kAudioUnitScope_Global, 0, 20.0, 0) // 20:1 expansion
        } else {
            gateNode.bypass = true
            AudioUnitSetParameter(au, 2, kAudioUnitScope_Global, 0, 1.0, 0) // 1:1 transparent
        }
    }

    private func setupLimiterNode() {
        let au = limiterNode.audioUnit
        // Attack 2ms, Decay 5ms, Pre-Gain 0dB
        AudioUnitSetParameter(au, 0, kAudioUnitScope_Global, 0, 0.002, 0)
        AudioUnitSetParameter(au, 1, kAudioUnitScope_Global, 0, 0.005, 0)
        AudioUnitSetParameter(au, 2, kAudioUnitScope_Global, 0, 0.0, 0)
        applyLimiterSettings()
    }

    private func applyLimiterSettings() {
        limiterNode.bypass = !limiterEnabled
    }

    // MARK: - Level Metering & Live Recording Tap

    private func installLevelTap() {
        let tapNode = limiterNode
        let format = tapNode.outputFormat(forBus: 0)
        guard format.channelCount > 0 else { return }

        tapNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData else { return }

            // Live recording: asynchronously write post-effects audio to WAV file
            if self.isRecording, let recFile = self.recordingFile {
                if let bufferCopy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) {
                    bufferCopy.frameLength = buffer.frameLength
                    for ch in 0..<Int(buffer.format.channelCount) {
                        if let src = buffer.floatChannelData?[ch], let dst = bufferCopy.floatChannelData?[ch] {
                            memcpy(dst, src, Int(buffer.frameLength) * MemoryLayout<Float>.size)
                        }
                    }
                    self.recordingQueue.async {
                        do {
                            try recFile.write(from: bufferCopy)
                        } catch {
                            print("[VocalCue] Recording buffer write error: \(error.localizedDescription)")
                        }
                    }
                }
            }

            let frameLength = UInt(buffer.frameLength)
            guard frameLength > 0 else { return }

            // Left channel RMS
            var rmsLeft: Float = 0
            vDSP_measqv(channelData[0], 1, &rmsLeft, vDSP_Length(frameLength))
            rmsLeft = sqrtf(rmsLeft)

            // Right channel RMS (fallback to left if mono)
            var rmsRight: Float = 0
            if format.channelCount > 1 {
                vDSP_measqv(channelData[1], 1, &rmsRight, vDSP_Length(frameLength))
                rmsRight = sqrtf(rmsRight)
            } else {
                rmsRight = rmsLeft
            }

            // Peak detection
            var peak: Float = 0
            vDSP_maxmgv(channelData[0], 1, &peak, vDSP_Length(frameLength))

            // Convert to dB
            let dbLeft = 20 * log10(max(rmsLeft, 1e-7))
            let dbRight = 20 * log10(max(rmsRight, 1e-7))
            let dbPeak = 20 * log10(max(peak, 1e-7))

            DispatchQueue.main.async {
                // Exponential smoothing for fluid meter movement
                self.inputLevelLeft = self.inputLevelLeft * 0.6 + dbLeft * 0.4
                self.inputLevelRight = self.inputLevelRight * 0.6 + dbRight * 0.4
                // Peak holds slightly longer
                self.peakLevel = max(self.peakLevel * 0.97, dbPeak)

                // Gate status: OPEN if signal is above threshold or gate is disabled
                if self.noiseGateEnabled {
                    self.isGateOpen = dbPeak >= self.noiseGateThreshold
                } else {
                    self.isGateOpen = true
                }

                // Limiter active indicator: flashes when audio peaks near 0 dBFS ceiling
                if self.limiterEnabled && dbPeak >= -1.5 {
                    self.isLimiterActive = true
                } else {
                    self.isLimiterActive = false
                }
            }
        }
    }

    private func removeLevelTap() {
        if engine.isRunning {
            limiterNode.removeTap(onBus: 0)
        }
    }

    // MARK: - Settings Persistence (UserDefaults)

    private func loadSettings() {
        let d = UserDefaults.standard

        if d.object(forKey: SettingsKey.monitorVolume) != nil {
            monitorVolume = d.float(forKey: SettingsKey.monitorVolume)
        }
        if d.object(forKey: SettingsKey.micGain) != nil {
            micGain = d.float(forKey: SettingsKey.micGain)
        }
        if d.object(forKey: SettingsKey.reverbEnabled) != nil {
            reverbEnabled = d.bool(forKey: SettingsKey.reverbEnabled)
        }
        if d.object(forKey: SettingsKey.reverbWetDryMix) != nil {
            reverbWetDryMix = d.float(forKey: SettingsKey.reverbWetDryMix)
        }
        if d.object(forKey: SettingsKey.reverbPreset) != nil {
            let raw = d.integer(forKey: SettingsKey.reverbPreset)
            if let preset = AVAudioUnitReverbPreset(rawValue: raw) {
                reverbPreset = preset
            }
        }
        if d.object(forKey: SettingsKey.delayEnabled) != nil {
            delayEnabled = d.bool(forKey: SettingsKey.delayEnabled)
        }
        if d.object(forKey: SettingsKey.delayTime) != nil {
            delayTime = d.double(forKey: SettingsKey.delayTime)
        }
        if d.object(forKey: SettingsKey.delayFeedback) != nil {
            delayFeedback = d.float(forKey: SettingsKey.delayFeedback)
        }
        if d.object(forKey: SettingsKey.delayWetDryMix) != nil {
            delayWetDryMix = d.float(forKey: SettingsKey.delayWetDryMix)
        }

        // DSP settings
        if d.object(forKey: SettingsKey.lowCutEnabled) != nil {
            lowCutEnabled = d.bool(forKey: SettingsKey.lowCutEnabled)
        }
        if d.object(forKey: SettingsKey.eqEnabled) != nil {
            eqEnabled = d.bool(forKey: SettingsKey.eqEnabled)
        }
        if d.object(forKey: SettingsKey.eqLowGain) != nil {
            eqLowGain = d.float(forKey: SettingsKey.eqLowGain)
        }
        if d.object(forKey: SettingsKey.eqMidGain) != nil {
            eqMidGain = d.float(forKey: SettingsKey.eqMidGain)
        }
        if d.object(forKey: SettingsKey.eqHighGain) != nil {
            eqHighGain = d.float(forKey: SettingsKey.eqHighGain)
        }
        if d.object(forKey: SettingsKey.noiseGateEnabled) != nil {
            noiseGateEnabled = d.bool(forKey: SettingsKey.noiseGateEnabled)
        }
        if d.object(forKey: SettingsKey.noiseGateThreshold) != nil {
            noiseGateThreshold = d.float(forKey: SettingsKey.noiseGateThreshold)
        }
        if d.object(forKey: SettingsKey.limiterEnabled) != nil {
            limiterEnabled = d.bool(forKey: SettingsKey.limiterEnabled)
        }
    }

    private func saveSettings() {
        let d = UserDefaults.standard
        d.set(monitorVolume, forKey: SettingsKey.monitorVolume)
        d.set(micGain, forKey: SettingsKey.micGain)
        d.set(reverbEnabled, forKey: SettingsKey.reverbEnabled)
        d.set(reverbWetDryMix, forKey: SettingsKey.reverbWetDryMix)
        d.set(reverbPreset.rawValue, forKey: SettingsKey.reverbPreset)
        d.set(delayEnabled, forKey: SettingsKey.delayEnabled)
        d.set(delayTime, forKey: SettingsKey.delayTime)
        d.set(delayFeedback, forKey: SettingsKey.delayFeedback)
        d.set(delayWetDryMix, forKey: SettingsKey.delayWetDryMix)

        // DSP settings
        d.set(lowCutEnabled, forKey: SettingsKey.lowCutEnabled)
        d.set(eqEnabled, forKey: SettingsKey.eqEnabled)
        d.set(eqLowGain, forKey: SettingsKey.eqLowGain)
        d.set(eqMidGain, forKey: SettingsKey.eqMidGain)
        d.set(eqHighGain, forKey: SettingsKey.eqHighGain)
        d.set(noiseGateEnabled, forKey: SettingsKey.noiseGateEnabled)
        d.set(noiseGateThreshold, forKey: SettingsKey.noiseGateThreshold)
        d.set(limiterEnabled, forKey: SettingsKey.limiterEnabled)
    }

    // MARK: - Observers

    private func setupObservers() {
        // Speaker warning
        deviceManager.$selectedOutputDeviceID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceID in
                guard let self, let deviceID else { return }
                self.showSpeakerWarning = self.deviceManager.isBuiltInSpeaker(deviceID)
            }
            .store(in: &cancellables)

        // Restart engine when device selection changes
        deviceManager.$selectedInputDeviceID
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.restart() }
            .store(in: &cancellables)

        deviceManager.$selectedOutputDeviceID
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.restart() }
            .store(in: &cancellables)

        // Auto-save settings on any change (debounced 0.5s)
        objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
}
