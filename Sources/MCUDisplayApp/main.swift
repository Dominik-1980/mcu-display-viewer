import AppKit
import CoreMIDI
#if canImport(MCUDisplayCore)
import MCUDisplayCore
#endif

private let bridgeName = "MCU Display Bridge"

struct MIDIOutput: Equatable {
    let endpoint: MIDIEndpointRef
    let uniqueID: Int32
    let name: String
}

final class MIDIBridge {
    var onBytes: (([UInt8]) -> Void)?
    var onStatus: ((String) -> Void)?
    var onOutputsChanged: (([MIDIOutput], Int32) -> Void)? {
        didSet { onOutputsChanged?(outputs, selectedID) }
    }

    private var client: MIDIClientRef = 0
    private var input: MIDIEndpointRef = 0
    private var outputPort: MIDIPortRef = 0
    private var outputs: [MIDIOutput] = []
    private var publishedSelection: Int32?
    private var selectedOutput: MIDIEndpointRef = 0
    private var selectedID: Int32 = 0
    private let outputLock = NSLock()
    private var timer: Timer?

    init() {
        selectedID = Int32(UserDefaults.standard.integer(forKey: "midiOutputUniqueID"))
        let clientStatus = MIDIClientCreateWithBlock("MCU Display Viewer" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshOutputs() }
        }
        guard clientStatus == noErr else { return }

        let outputStatus = MIDIOutputPortCreate(client, "MCU Hardware Output" as CFString, &outputPort)
        guard outputStatus == noErr else { return }

        let inputStatus = MIDIDestinationCreateWithBlock(client, bridgeName as CFString, &input) { [weak self] packetList, _ in
            self?.receive(packetList)
        }
        guard inputStatus == noErr else { return }

        refreshOutputs()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshOutputs()
        }
    }

    private func receive(_ packetList: UnsafePointer<MIDIPacketList>) {
        outputLock.lock()
        let destination = selectedOutput
        outputLock.unlock()
        if destination != 0 {
            let status = MIDISend(outputPort, destination, packetList)
            if status != noErr {
                DispatchQueue.main.async { [weak self] in
                    self?.onStatus?("MIDI-Ausgang nicht erreichbar · Ausgang im MIDI-Menü prüfen")
                }
            }
        }

        let packetOffset = MemoryLayout<MIDIPacketList>.offset(of: \.packet)!
        var packet = UnsafeRawPointer(packetList).advanced(by: packetOffset)
            .assumingMemoryBound(to: MIDIPacket.self)
        var bytes: [UInt8] = []
        for _ in 0..<packetList.pointee.numPackets {
            bytes += withUnsafeBytes(of: packet.pointee.data) {
                Array($0.prefix(Int(packet.pointee.length)))
            }
            packet = UnsafePointer(MIDIPacketNext(packet))
        }
        guard !bytes.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in self?.onBytes?(bytes) }
    }

    func selectOutput(_ uniqueID: Int32) {
        selectedID = uniqueID
        UserDefaults.standard.set(Int(uniqueID), forKey: "midiOutputUniqueID")
        if let output = outputs.first(where: { $0.uniqueID == uniqueID }) {
            UserDefaults.standard.set(output.name, forKey: "midiOutputName")
        } else {
            UserDefaults.standard.removeObject(forKey: "midiOutputName")
        }
        refreshOutputs()
    }

    func refreshOutputs() {
        var found: [MIDIOutput] = []
        for index in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(index)
            guard endpoint != input else { continue }
            var name: Unmanaged<CFString>?
            guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) == noErr,
                  let name else { continue }
            var uniqueID: Int32 = 0
            guard MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID) == noErr else { continue }
            found.append(MIDIOutput(endpoint: endpoint, uniqueID: uniqueID, name: name.takeRetainedValue() as String))
        }

        if selectedID != 0 && !found.contains(where: { $0.uniqueID == selectedID }),
           let savedName = UserDefaults.standard.string(forKey: "midiOutputName") {
            let matches = found.filter { $0.name == savedName }
            if matches.count == 1 {
                selectedID = matches[0].uniqueID
                UserDefaults.standard.set(Int(selectedID), forKey: "midiOutputUniqueID")
            }
        }
        let selected = found.first(where: { $0.uniqueID == selectedID })
        outputLock.lock()
        selectedOutput = selected?.endpoint ?? 0
        outputLock.unlock()
        if outputs != found || publishedSelection != selectedID {
            outputs = found
            publishedSelection = selectedID
            onOutputsChanged?(found, selectedID)
        }
        if input == 0 {
            onStatus?("MCU Display Bridge konnte nicht erstellt werden")
        } else if let selected {
            onStatus?("MCU Display Bridge bereit · Ausgang: \(selected.name) · wartet auf Logic")
        } else {
            onStatus?("MCU Display Bridge bereit · MIDI-Ausgang im Menü auswählen")
        }
    }

    deinit {
        timer?.invalidate()
        if input != 0 { MIDIEndpointDispose(input) }
        if outputPort != 0 { MIDIPortDispose(outputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }
}

final class DisplayView: NSView {
    var channels: [MCUChannel] = MCUDisplayState().channels {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let columns = bounds.width >= 1040 ? 8 : bounds.width >= 540 ? 4 : bounds.width >= 300 ? 2 : 1
        let rows = Int(ceil(Double(channels.count) / Double(columns)))
        let gap: CGFloat = 8
        let inset: CGFloat = 12
        let availableWidth = max(0, bounds.width - inset * 2 - CGFloat(columns - 1) * gap)
        let availableHeight = max(0, bounds.height - inset * 2 - CGFloat(rows - 1) * gap)
        let cardWidth = availableWidth / CGFloat(columns)
        let cardHeight = availableHeight / CGFloat(rows)

        for index in channels.indices {
            let column = index % columns
            let row = index / columns
            let rect = CGRect(
                x: inset + CGFloat(column) * (cardWidth + gap),
                y: inset + CGFloat(row) * (cardHeight + gap),
                width: cardWidth,
                height: cardHeight
            )
            drawCard(channels[index], index: index, in: rect)
        }
    }

    private func drawCard(_ channel: MCUChannel, index: Int, in rect: CGRect) {
        let isEmpty = channel.name.isEmpty && channel.value.isEmpty
        let fill = isEmpty ? NSColor(calibratedWhite: 0.16, alpha: 1) : background(for: channel.color)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        fill.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let foreground: NSColor = isEmpty ? .white : ([2, 3, 6, 7].contains(channel.color) ? .black : .white)
        let muted = foreground.withAlphaComponent(isEmpty ? 0.35 : 0.65)
        let horizontal = min(12, rect.width * 0.07)
        let inner = rect.insetBy(dx: horizontal, dy: 8)
        let titleSize = min(30, max(12, min(inner.width / 4.8, inner.height * 0.27)))
        let valueSize = min(32, max(12, min(inner.width / 4.8, inner.height * 0.30)))

        drawText(String(format: "%02d", index + 1), in: CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: 16),
                 font: .monospacedDigitSystemFont(ofSize: 11, weight: .medium), color: muted)
        if isEmpty { return }
        let name = channel.name.isEmpty ? "—" : channel.name
        let value = channel.value.isEmpty ? "—" : channel.value
        drawText(name, in: CGRect(x: inner.minX, y: inner.midY - titleSize - 5, width: inner.width, height: titleSize + 6),
                 font: .monospacedSystemFont(ofSize: titleSize, weight: .semibold), color: foreground)
        drawText(value, in: CGRect(x: inner.minX, y: inner.midY + 2, width: inner.width, height: valueSize + 6),
                 font: .monospacedSystemFont(ofSize: valueSize, weight: .regular), color: foreground)
    }

    private func drawText(_ text: String, in rect: CGRect, font: NSFont, color: NSColor) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ]).draw(in: rect)
    }

    private func background(for code: UInt8) -> NSColor {
        switch code {
        case 1: return NSColor(calibratedRed: 0.72, green: 0.17, blue: 0.20, alpha: 1)
        case 2: return NSColor(calibratedRed: 0.24, green: 0.69, blue: 0.32, alpha: 1)
        case 3: return NSColor(calibratedRed: 0.95, green: 0.79, blue: 0.27, alpha: 1)
        case 4: return NSColor(calibratedRed: 0.19, green: 0.39, blue: 0.78, alpha: 1)
        case 5: return NSColor(calibratedRed: 0.57, green: 0.29, blue: 0.67, alpha: 1)
        case 6: return NSColor(calibratedRed: 0.41, green: 0.79, blue: 0.83, alpha: 1)
        case 7: return NSColor(calibratedWhite: 0.94, alpha: 1)
        default: return NSColor(calibratedWhite: 0.25, alpha: 1)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var displayView: DisplayView!
    private var statusField: NSTextField!
    private var alwaysOnTopItem: NSMenuItem!
    private var outputMenu: NSMenu!
    private var bridge: MIDIBridge!
    private var receivedBridgeData = false
    private var state = MCUDisplayState()
    private var stream = MCUSysExStream()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMenu()
        configureWindow()

        bridge = MIDIBridge()
        bridge.onBytes = { [weak self] bytes in self?.handle(bytes) }
        bridge.onStatus = { [weak self] status in
            guard let self else { return }
            self.statusField.stringValue = self.receivedBridgeData
                ? status.replacingOccurrences(of: "wartet auf Logic", with: "MIDI-Daten empfangen")
                : status
        }
        bridge.onOutputsChanged = { [weak self] outputs, selectedID in
            self?.refreshOutputMenu(outputs, selectedID: selectedID)
        }
        bridge.refreshOutputs()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Über MCU Display Viewer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let koFiItem = appMenu.addItem(withTitle: "Auf Ko-fi unterstützen", action: #selector(openKoFi), keyEquivalent: "")
        koFiItem.target = self
        let payPalItem = appMenu.addItem(withTitle: "Mit PayPal unterstützen", action: #selector(openPayPal), keyEquivalent: "")
        payPalItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "MCU Display Viewer beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "Ansicht")
        alwaysOnTopItem = viewMenu.addItem(withTitle: "Immer im Vordergrund", action: #selector(toggleAlwaysOnTop), keyEquivalent: "t")
        alwaysOnTopItem.target = self
        viewItem.title = "Ansicht"
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let midiItem = NSMenuItem()
        midiItem.title = "MIDI"
        let midiMenu = NSMenu(title: "MIDI")
        let outputItem = NSMenuItem(title: "Ausgangsgerät", action: nil, keyEquivalent: "")
        outputMenu = NSMenu(title: "Ausgangsgerät")
        outputItem.submenu = outputMenu
        midiMenu.addItem(outputItem)
        midiMenu.addItem(.separator())
        let setupItem = midiMenu.addItem(withTitle: "Logic einrichten …", action: #selector(showLogicSetup), keyEquivalent: "")
        setupItem.target = self
        midiItem.submenu = midiMenu
        main.addItem(midiItem)
        NSApp.mainMenu = main
    }

    private func refreshOutputMenu(_ outputs: [MIDIOutput], selectedID: Int32) {
        outputMenu.removeAllItems()
        let none = outputMenu.addItem(withTitle: "Kein Ausgang gewählt", action: #selector(chooseOutput(_:)), keyEquivalent: "")
        none.target = self
        none.representedObject = NSNumber(value: Int32(0))
        none.state = selectedID == 0 ? .on : .off
        if !outputs.isEmpty { outputMenu.addItem(.separator()) }
        for output in outputs {
            let item = outputMenu.addItem(withTitle: output.name, action: #selector(chooseOutput(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: output.uniqueID)
            item.state = output.uniqueID == selectedID ? .on : .off
        }
    }

    @objc private func chooseOutput(_ sender: NSMenuItem) {
        guard let uniqueID = sender.representedObject as? NSNumber else { return }
        bridge.selectOutput(uniqueID.int32Value)
    }

    @objc private func showLogicSetup() {
        let alert = NSAlert()
        alert.messageText = "Logic Pro mit MCU Display Bridge verbinden"
        alert.informativeText = "Bedienoberflächen → Setup → vorhandene Mackie Control: Eingang = dein physischer Controller, Ausgang = MCU Display Bridge. Wähle zuvor unter MIDI → Ausgangsgerät den physischen MIDI-Ausgang des Controllers."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func configureWindow() {
        window = NSWindow(contentRect: NSRect(x: 120, y: 120, width: 1200, height: 260),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "MCU Display Viewer"
        window.minSize = NSSize(width: 320, height: 180)
        window.delegate = self
        window.setFrameAutosaveName("MCUDisplayMainWindow")
        window.setFrameUsingName("MCUDisplayMainWindow")

        let content = NSView()
        displayView = DisplayView()
        statusField = NSTextField(labelWithString: "MCU Display Bridge wird eingerichtet …")
        statusField.font = .systemFont(ofSize: 11)
        statusField.textColor = .secondaryLabelColor
        displayView.translatesAutoresizingMaskIntoConstraints = false
        statusField.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(displayView)
        content.addSubview(statusField)
        NSLayoutConstraint.activate([
            displayView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            displayView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            displayView.topAnchor.constraint(equalTo: content.topAnchor),
            displayView.bottomAnchor.constraint(equalTo: statusField.topAnchor),
            statusField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            statusField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            statusField.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -7),
            statusField.heightAnchor.constraint(equalToConstant: 16)
        ])
        window.contentView = content
        applyAlwaysOnTop()
    }

    private func handle(_ bytes: [UInt8]) {
        let messages = stream.consume(bytes)
        var changed = false
        for message in messages {
            if state.apply(message) { changed = true }
        }
        if changed {
            receivedBridgeData = true
            displayView.channels = state.channels
            bridge.refreshOutputs()
        }
    }

    @objc private func toggleAlwaysOnTop() {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "alwaysOnTop"), forKey: "alwaysOnTop")
        applyAlwaysOnTop()
    }

    @objc private func openKoFi() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/dominik_w")!)
    }

    @objc private func openPayPal() {
        NSWorkspace.shared.open(URL(string: "https://paypal.me/DominikWeiland")!)
    }

    private func applyAlwaysOnTop() {
        let enabled = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        window.level = enabled ? .floating : .normal
        alwaysOnTopItem.state = enabled ? .on : .off
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
