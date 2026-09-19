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
    static let vocalVolume = "inear.vocalVolume"
    static let backingVolume = "inear.backingVolume"
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

    // MARK: - Audio Core Nodes

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
    private let vocalMixerNode = AVAudioMixerNode()

    // MARK: - Sub-Managers

    let deviceManager = AudioDeviceManager()
    let pitchDetector = PitchDetector()
    let spectrumAnalyzer = SpectrumAnalyzer()
    let backingManager = BackingTrackManager()
    let metronomeManager = MetronomeManager()
    let recordingManager = RecordingManager()

    // MARK: - Engine State

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
    @Published var vocalVolume: Float = 0.85 {
        didSet {
            guard isRunning else { return }
            vocalMixerNode.outputVolume = vocalVolume
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

        // Link Metronome delay sync callback to AudioEngineManager delay time
        metronomeManager.onDelayTimeChanged = { [weak self] newDelay in
            DispatchQueue.main.async {
                self?.delayTime = newDelay
            }
        }
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

            // Attach core vocal processing nodes
            engine.attach(gainMixer)
            engine.attach(eqNode)
            engine.attach(gateNode)
            engine.attach(reverbNode)
            engine.attach(delayNode)
            engine.attach(limiterNode)
            engine.attach(vocalMixerNode)

            // Attach sub-manager nodes
            backingManager.attachNodes(to: engine)
            metronomeManager.attachNodes(to: engine)

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

            // Check input node format
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                print("[VocalCue] Invalid input format: \(inputFormat)")
                return
            }

            // Processing format (Stereo @ Hardware sample rate)
            let processingFormat = AVAudioFormat(
                standardFormatWithSampleRate: inputFormat.sampleRate,
                channels: 2
            ) ?? inputFormat

            // 1. Connect Vocal Chain:
            // Input -> GainMixer -> EQ -> Gate -> Reverb -> Delay -> Limiter -> VocalMixerNode -> MainMixerNode
            engine.connect(inputNode, to: gainMixer, format: inputFormat)
            engine.connect(gainMixer, to: eqNode, format: processingFormat)
            engine.connect(eqNode, to: gateNode, format: processingFormat)
            engine.connect(gateNode, to: reverbNode, format: processingFormat)
            engine.connect(reverbNode, to: delayNode, format: processingFormat)
            engine.connect(delayNode, to: limiterNode, format: processingFormat)
            engine.connect(limiterNode, to: vocalMixerNode, format: processingFormat)
            engine.connect(vocalMixerNode, to: engine.mainMixerNode, format: processingFormat)

            // 2. Connect Backing Track Chain to MainMixer
            backingManager.connectNodes(in: engine, format: processingFormat)

            // 3. Connect Metronome Click to MainMixer (Headphones only)
            metronomeManager.connectNodes(in: engine, format: processingFormat)

            // Apply volume settings
            gainMixer.outputVolume = micGain
            vocalMixerNode.outputVolume = vocalVolume
            engine.mainMixerNode.outputVolume = monitorVolume

            // Install live audio taps:
            // - Tap 1: limiterNode (Wet signal, Level meters, Spectrum, Wet recording)
            // - Tap 2: gainMixer (Dry signal, Pitch detector, Dry recording)
            installAudioTaps(format: processingFormat)

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
        if recordingManager.isRecording {
            recordingManager.stopRecording()
        }

        backingManager.stop()
        metronomeManager.stop()

        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
            configObserver = nil
        }

        removeAudioTaps()
        if engine.isRunning {
            engine.stop()
        }
        engine.reset()

        pitchDetector.reset()
        spectrumAnalyzer.reset()

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

    // MARK: - Dual Recording Convenience

    func startRecording() {
        if !isRunning {
            start()
        }
        let sampleRate = engine.inputNode.outputFormat(forBus: 0).sampleRate
        recordingManager.startRecording(sampleRate: sampleRate)
    }

    func stopRecording() {
        recordingManager.stopRecording()
    }

    func toggleRecording() {
        if recordingManager.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Audio Taps (Wet & Dry Streams)

    private func installAudioTaps(format: AVAudioFormat) {
        guard format.channelCount > 0 else { return }
        let sampleRate = format.sampleRate

        // --- Tap 1: Post-Limiter (WET SIGNAL) ---
        limiterNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData else { return }

            // Feed wet buffer to recording manager
            self.recordingManager.writeWetBuffer(buffer)

            // Feed to real-time FFT spectrum analyzer
            self.spectrumAnalyzer.process(samples: channelData[0], count: Int(buffer.frameLength), sampleRate: sampleRate)

            let frameLength = UInt(buffer.frameLength)
            guard frameLength > 0 else { return }

            // Left channel RMS
            var rmsLeft: Float = 0
            vDSP_measqv(channelData[0], 1, &rmsLeft, vDSP_Length(frameLength))
            rmsLeft = sqrtf(rmsLeft)

            // Right channel RMS
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

            let dbLeft = 20 * log10(max(rmsLeft, 1e-7))
            let dbRight = 20 * log10(max(rmsRight, 1e-7))
            let dbPeak = 20 * log10(max(peak, 1e-7))

            DispatchQueue.main.async {
                self.inputLevelLeft = self.inputLevelLeft * 0.6 + dbLeft * 0.4
                self.inputLevelRight = self.inputLevelRight * 0.6 + dbRight * 0.4
                self.peakLevel = max(self.peakLevel * 0.97, dbPeak)

                // Gate status
                if self.noiseGateEnabled {
                    self.isGateOpen = dbPeak >= self.noiseGateThreshold
                } else {
                    self.isGateOpen = true
                }

                // Limiter active indicator
                if self.limiterEnabled && dbPeak >= -1.5 {
                    self.isLimiterActive = true
                } else {
                    self.isLimiterActive = false
                }
            }
        }

        // --- Tap 2: Post-GainMixer (DRY SIGNAL) ---
        gainMixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData else { return }

            // Feed dry buffer to recording manager
            self.recordingManager.writeDryBuffer(buffer)

            // Feed clean vocal to pitch detector
            self.pitchDetector.process(samples: channelData[0], count: Int(buffer.frameLength), sampleRate: sampleRate)
        }
    }

    private func removeAudioTaps() {
        if engine.isRunning {
            limiterNode.removeTap(onBus: 0)
            gainMixer.removeTap(onBus: 0)
        }
    }

    // MARK: - Engine Configuration Change (Device Hot-Swap)

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

        // 3-Band EQ gains
        eqNode.bands[1].gain = eqEnabled ? eqLowGain : 0.0
        eqNode.bands[2].gain = eqEnabled ? eqMidGain : 0.0
        eqNode.bands[3].gain = eqEnabled ? eqHighGain : 0.0

        // Entire EQ node bypass
        eqNode.bypass = !lowCutEnabled && !eqEnabled
    }

    private func setupGateNode() {
        let au = gateNode.audioUnit
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
            AudioUnitSetParameter(au, 2, kAudioUnitScope_Global, 0, 20.0, 0)
        } else {
            gateNode.bypass = true
            AudioUnitSetParameter(au, 2, kAudioUnitScope_Global, 0, 1.0, 0)
        }
    }

    private func setupLimiterNode() {
        let au = limiterNode.audioUnit
        AudioUnitSetParameter(au, 0, kAudioUnitScope_Global, 0, 0.002, 0)
        AudioUnitSetParameter(au, 1, kAudioUnitScope_Global, 0, 0.005, 0)
        AudioUnitSetParameter(au, 2, kAudioUnitScope_Global, 0, 0.0, 0)
        applyLimiterSettings()
    }

    private func applyLimiterSettings() {
        limiterNode.bypass = !limiterEnabled
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
        if d.object(forKey: SettingsKey.vocalVolume) != nil {
            vocalVolume = d.float(forKey: SettingsKey.vocalVolume)
        }
        if d.object(forKey: SettingsKey.backingVolume) != nil {
            backingManager.backingVolume = d.float(forKey: SettingsKey.backingVolume)
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
        d.set(vocalVolume, forKey: SettingsKey.vocalVolume)
        d.set(backingManager.backingVolume, forKey: SettingsKey.backingVolume)
        d.set(reverbEnabled, forKey: SettingsKey.reverbEnabled)
        d.set(reverbWetDryMix, forKey: SettingsKey.reverbWetDryMix)
        d.set(reverbPreset.rawValue, forKey: SettingsKey.reverbPreset)
        d.set(delayEnabled, forKey: SettingsKey.delayEnabled)
        d.set(delayTime, forKey: SettingsKey.delayTime)
        d.set(delayFeedback, forKey: SettingsKey.delayFeedback)
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

    private func setupObservers() {
        deviceManager.$selectedOutputDeviceID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] deviceID in
                guard let self, let deviceID else { return }
                self.showSpeakerWarning = self.deviceManager.isBuiltInSpeaker(deviceID)
            }
            .store(in: &cancellables)

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

        objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
}
