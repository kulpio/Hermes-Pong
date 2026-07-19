import AppKit

/// Modern SuperGrok-inspired control panel: tabs, cards, snapshot mission view.
final class PanelController: NSObject {
    static let shared = PanelController()

    private var window: NSWindow?
    private var rootView: NSView!
    private var headerStatus: NSTextField!
    private var liveDot: NSView!
    private var tabTeams: NSButton!
    private var tabMission: NSButton!
    private var tabSetup: NSButton!
    private var bodyHost: NSView!
    private var teamsScroll: NSScrollView!
    private var teamsList: NSView!
    private var missionScroll: NSScrollView!
    private var missionList: NSView!
    private var setupView: NSView!
    private var showTeamsBtn: NSButton?
    private var showTeamsHint: NSTextField?
    private var refreshTimer: Timer?
    private var selectedTab: Tab = .teams
    private let guide = LinkGuideController()

    private let W: CGFloat = 520
    private let H: CGFloat = 720
    private let PAD: CGFloat = 20
    private let headerH: CGFloat = 72
    private let tabH: CGFloat = 44
    private let footerH: CGFloat = 56

    enum Tab: Int { case teams = 0, mission = 1, setup = 2 }

    // MARK: - Public

    func show() {
        if window == nil { buildWindow() }
        refreshUI()
        startPolling()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func refreshUI() {
        updateHeader()
        updateShowTeamsChrome()
        switch selectedTab {
        case .teams: rebuildTeams()
        case .mission: rebuildMission()
        case .setup: break
        }
    }

    // MARK: - Shared label helper (LinkGuide + sheets)

    static func label(_ text: String, frame: NSRect, bold: Bool = false,
                      size: CGFloat = 13, secondary: Bool = false) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = bold ? PongTheme.font(size, weight: .semibold) : PongTheme.font(size)
        f.textColor = secondary ? PongTheme.textSecondary : PongTheme.textPrimary
        f.frame = frame
        f.lineBreakMode = .byWordWrapping
        f.maximumNumberOfLines = 6
        f.backgroundColor = .clear
        f.isBezeled = false
        f.drawsBackground = false
        return f
    }

    // MARK: - Window chrome

    private func buildWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        win.title = "Pong"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.backgroundColor = PongTheme.bg
        win.isMovableByWindowBackground = true
        win.center()

        let root = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        root.wantsLayer = true
        root.layer?.backgroundColor = PongTheme.bg.cgColor
        rootView = root

        buildHeader(into: root)
        buildTabs(into: root)
        buildBody(into: root)
        buildFooter(into: root)

        win.contentView = root
        window = win
        selectTab(.teams, animated: false)
    }

    private func buildHeader(into root: NSView) {
        let header = NSView(frame: NSRect(x: 0, y: H - headerH, width: W, height: headerH))
        header.wantsLayer = true

        // Logo
        let res = Bundle.main.resourcePath ?? ""
        let logoPath = ["AppIcon-1024.png", "logo-accent.png", "logo.png"]
            .map { res + "/" + $0 }
            .first { FileManager.default.fileExists(atPath: $0) }
        if let logoPath, let img = NSImage(contentsOfFile: logoPath) {
            let wrap = NSView(frame: NSRect(x: PAD, y: 18, width: 36, height: 36))
            wrap.wantsLayer = true
            wrap.layer?.cornerRadius = 10
            wrap.layer?.masksToBounds = true
            wrap.layer?.backgroundColor = PongTheme.bgElevated.cgColor
            wrap.layer?.borderWidth = 1
            wrap.layer?.borderColor = PongTheme.border.cgColor
            let iv = NSImageView(frame: NSRect(x: 3, y: 3, width: 30, height: 30))
            iv.image = img
            iv.imageScaling = .scaleProportionallyUpOrDown
            wrap.addSubview(iv)
            header.addSubview(wrap)
        }

        let title = Self.label("Pong", frame: NSRect(x: PAD + 48, y: 32, width: 120, height: 24),
                               bold: true, size: 18)
        header.addSubview(title)

        let sub = Self.label("Mission control", frame: NSRect(x: PAD + 48, y: 14, width: 160, height: 16),
                             size: 11, secondary: true)
        header.addSubview(sub)

        // Live status pill
        let pill = NSView(frame: NSRect(x: W - PAD - 168, y: 22, width: 168, height: 28))
        PongTheme.applyCard(pill)
        pill.layer?.cornerRadius = 14
        liveDot = NSView(frame: NSRect(x: 10, y: 10, width: 8, height: 8))
        liveDot.wantsLayer = true
        liveDot.layer?.cornerRadius = 4
        liveDot.layer?.backgroundColor = PongTheme.idle.cgColor
        pill.addSubview(liveDot)
        headerStatus = Self.label("Idle", frame: NSRect(x: 24, y: 5, width: 136, height: 18), size: 11, secondary: true)
        headerStatus.lineBreakMode = .byTruncatingTail
        headerStatus.maximumNumberOfLines = 1
        pill.addSubview(headerStatus)
        header.addSubview(pill)

        // Hairline
        let line = NSView(frame: NSRect(x: 0, y: 0, width: W, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = PongTheme.border.cgColor
        header.addSubview(line)

        root.addSubview(header)
    }

    private func buildTabs(into root: NSView) {
        let barY = H - headerH - tabH
        let bar = NSView(frame: NSRect(x: PAD, y: barY + 6, width: W - 2 * PAD, height: 36))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = PongTheme.bgInput.cgColor
        bar.layer?.cornerRadius = 12
        bar.layer?.borderWidth = 1
        bar.layer?.borderColor = PongTheme.border.cgColor

        let tw = (W - 2 * PAD - 8) / 3
        tabTeams = makeTab("Teams", tag: 0, frame: NSRect(x: 4, y: 3, width: tw, height: 30))
        tabMission = makeTab("Mission", tag: 1, frame: NSRect(x: 4 + tw, y: 3, width: tw, height: 30))
        tabSetup = makeTab("Setup", tag: 2, frame: NSRect(x: 4 + 2 * tw, y: 3, width: tw, height: 30))
        bar.addSubview(tabTeams)
        bar.addSubview(tabMission)
        bar.addSubview(tabSetup)
        root.addSubview(bar)
    }

    private func makeTab(_ title: String, tag: Int, frame: NSRect) -> NSButton {
        let b = NSButton(frame: frame)
        b.title = title
        b.bezelStyle = .inline
        b.isBordered = false
        b.font = PongTheme.font(12, weight: .medium)
        b.contentTintColor = PongTheme.textSecondary
        b.wantsLayer = true
        b.layer?.cornerRadius = 9
        b.tag = tag
        b.target = self
        b.action = #selector(tabPressed(_:))
        return b
    }

    private func buildBody(into root: NSView) {
        let top = H - headerH - tabH
        let bodyFrame = NSRect(x: 0, y: footerH, width: W, height: top - footerH)
        bodyHost = NSView(frame: bodyFrame)
        bodyHost.wantsLayer = true
        root.addSubview(bodyHost)

        let inset = NSRect(x: PAD, y: 8, width: W - 2 * PAD, height: bodyFrame.height - 16)

        teamsScroll = makeScroll(inset)
        teamsList = NSView(frame: inset)
        teamsScroll.documentView = teamsList
        bodyHost.addSubview(teamsScroll)

        missionScroll = makeScroll(inset)
        missionList = NSView(frame: inset)
        missionScroll.documentView = missionList
        missionScroll.isHidden = true
        bodyHost.addSubview(missionScroll)

        setupView = NSView(frame: inset)
        setupView.isHidden = true
        bodyHost.addSubview(setupView)
        buildSetupContent()
    }

    private func makeScroll(_ frame: NSRect) -> NSScrollView {
        let s = NSScrollView(frame: frame)
        s.hasVerticalScroller = true
        s.hasHorizontalScroller = false
        s.autohidesScrollers = true
        s.borderType = .noBorder
        s.drawsBackground = false
        s.scrollerStyle = .overlay
        s.backgroundColor = .clear
        return s
    }

    private func buildSetupContent() {
        var y = setupView.bounds.height - 8
        if setupView.bounds.height < 10 {
            y = H - headerH - tabH - footerH - 40
            setupView.setFrameSize(NSSize(width: W - 2 * PAD, height: max(400, y)))
            y = setupView.bounds.height - 8
        }

        func section(_ t: String) {
            y -= 22
            let l = Self.label(t.uppercased(), frame: NSRect(x: 4, y: y, width: 300, height: 16),
                               size: 10, secondary: true)
            l.font = PongTheme.font(10, weight: .semibold)
            setupView.addSubview(l)
            y -= 10
        }

        section("Start")
        y -= 44
        setupView.addSubview(primaryButton("New team", #selector(newPairPressed(_:)),
            NSRect(x: 0, y: y, width: setupView.bounds.width, height: 40)))
        y -= 12
        y -= 36
        let st = softButton("Show saved teams", #selector(showTeamsPressed(_:)),
            NSRect(x: 0, y: y, width: setupView.bounds.width, height: 36))
        st.isHidden = true
        setupView.addSubview(st)
        showTeamsBtn = st
        y -= 22
        let hint = Self.label("Open, duplicate, or delete saved team layouts.",
            frame: NSRect(x: 4, y: y, width: setupView.bounds.width - 8, height: 16),
            size: 11, secondary: true)
        hint.isHidden = true
        setupView.addSubview(hint)
        showTeamsHint = hint

        y -= 48
        setupView.addSubview(softButton("Link existing terminals", #selector(linkPressed(_:)),
            NSRect(x: 0, y: y, width: setupView.bounds.width, height: 36)))
        y -= 56
        let tipCard = NSView(frame: NSRect(x: 0, y: y - 90, width: setupView.bounds.width, height: 100))
        PongTheme.applyCard(tipCard)
        tipCard.addSubview(Self.label("How it works",
            frame: NSRect(x: 14, y: 70, width: 200, height: 18), bold: true, size: 12))
        tipCard.addSubview(Self.label(
            "1. Pick a conductor (Grok recommended)\n2. Staff workers (Claude, Codex, …)\n3. Type missions in the conductor TUI\n4. Intervene in any worker window anytime",
            frame: NSRect(x: 14, y: 10, width: tipCard.bounds.width - 28, height: 58),
            size: 11, secondary: true))
        setupView.addSubview(tipCard)

        y -= 130
        let cliCard = NSView(frame: NSRect(x: 0, y: y - 70, width: setupView.bounds.width, height: 80))
        PongTheme.applyCard(cliCard)
        cliCard.addSubview(Self.label("Control plane",
            frame: NSRect(x: 14, y: 50, width: 200, height: 18), bold: true, size: 12))
        cliCard.addSubview(Self.label(
            "pong check · pong snapshot · pong job create\nJobs are the source of truth; paste is optional.",
            frame: NSRect(x: 14, y: 12, width: cliCard.bounds.width - 28, height: 36),
            size: 11, secondary: true))
        setupView.addSubview(cliCard)
    }

    private func buildFooter(into root: NSView) {
        let footer = NSView(frame: NSRect(x: 0, y: 0, width: W, height: footerH))
        footer.wantsLayer = true
        footer.layer?.backgroundColor = PongTheme.bgFooter.cgColor
        let line = NSView(frame: NSRect(x: 0, y: footerH - 1, width: W, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = PongTheme.border.cgColor
        footer.addSubview(line)

        let half = (W - 2 * PAD - 10) / 2
        footer.addSubview(softButton("Refresh", #selector(refreshPressed(_:)),
            NSRect(x: PAD, y: 12, width: half, height: 32)))
        footer.addSubview(ghostButton("Close", #selector(closePressed(_:)),
            NSRect(x: PAD + half + 10, y: 12, width: half, height: 32)))
        root.addSubview(footer)
    }

    // MARK: - Buttons

    private func primaryButton(_ title: String, _ sel: Selector, _ frame: NSRect, id: String? = nil) -> NSButton {
        let b = NSButton(frame: frame)
        b.title = title
        b.bezelStyle = .rounded
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = PongTheme.accent.cgColor
        b.layer?.cornerRadius = PongTheme.radiusBtn
        b.font = PongTheme.font(13, weight: .semibold)
        b.contentTintColor = PongTheme.accentInk
        // NSButton with isBordered false needs attributed title for color
        b.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: PongTheme.accentInk,
            .font: PongTheme.font(13, weight: .semibold),
        ])
        b.target = self
        b.action = sel
        if let id { b.identifier = NSUserInterfaceItemIdentifier(id) }
        return b
    }

    private func softButton(_ title: String, _ sel: Selector, _ frame: NSRect, id: String? = nil) -> NSButton {
        let b = NSButton(frame: frame)
        b.bezelStyle = .rounded
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = PongTheme.bgElevated.cgColor
        b.layer?.cornerRadius = PongTheme.radiusBtn
        b.layer?.borderWidth = 1
        b.layer?.borderColor = PongTheme.border.cgColor
        b.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: PongTheme.textPrimary,
            .font: PongTheme.font(12, weight: .medium),
        ])
        b.target = self
        b.action = sel
        if let id { b.identifier = NSUserInterfaceItemIdentifier(id) }
        return b
    }

    private func ghostButton(_ title: String, _ sel: Selector, _ frame: NSRect, id: String? = nil) -> NSButton {
        let b = softButton(title, sel, frame, id: id)
        b.layer?.backgroundColor = PongTheme.bgInput.cgColor
        return b
    }

    private func chipButton(_ title: String, _ sel: Selector, _ frame: NSRect, id: String) -> NSButton {
        let b = NSButton(frame: frame)
        b.bezelStyle = .inline
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = PongTheme.bgHover.cgColor
        b.layer?.cornerRadius = 7
        b.layer?.borderWidth = 1
        b.layer?.borderColor = PongTheme.border.cgColor
        b.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: PongTheme.textSecondary,
            .font: PongTheme.font(10, weight: .medium),
        ])
        b.target = self
        b.action = sel
        b.identifier = NSUserInterfaceItemIdentifier(id)
        return b
    }

    private func nameButton(_ title: String, frame: NSRect, id: String, action: Selector) -> NSButton {
        let b = NSButton(frame: frame)
        b.bezelStyle = .inline
        b.isBordered = false
        b.alignment = .left
        b.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: PongTheme.textPrimary,
            .font: PongTheme.font(12, weight: .semibold),
        ])
        b.target = self
        b.action = action
        b.identifier = NSUserInterfaceItemIdentifier(id)
        b.toolTip = "Click to rename"
        return b
    }

    private func swatchButton(color: NSColor, frame: NSRect, id: String, action: Selector) -> NSButton {
        let b = NSButton(frame: frame)
        b.title = ""
        b.bezelStyle = .shadowlessSquare
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = color.cgColor
        b.layer?.cornerRadius = frame.height / 2
        b.layer?.borderWidth = 1
        b.layer?.borderColor = NSColor(calibratedWhite: 1, alpha: 0.2).cgColor
        b.target = self
        b.action = action
        b.identifier = NSUserInterfaceItemIdentifier(id)
        b.toolTip = "Colors"
        return b
    }

    // MARK: - Tabs

    @objc private func tabPressed(_ sender: NSButton) {
        guard let t = Tab(rawValue: sender.tag) else { return }
        selectTab(t, animated: true)
    }

    private func selectTab(_ tab: Tab, animated: Bool) {
        selectedTab = tab
        styleTab(tabTeams, on: tab == .teams)
        styleTab(tabMission, on: tab == .mission)
        styleTab(tabSetup, on: tab == .setup)
        teamsScroll.isHidden = tab != .teams
        missionScroll.isHidden = tab != .mission
        setupView.isHidden = tab != .setup
        refreshUI()
    }

    private func styleTab(_ b: NSButton, on: Bool) {
        b.layer?.backgroundColor = (on ? PongTheme.tabSelected : PongTheme.tabIdle).cgColor
        b.attributedTitle = NSAttributedString(string: b.title.isEmpty ? (b.attributedTitle.string) : b.attributedTitle.string,
            attributes: [
                .foregroundColor: on ? PongTheme.textPrimary : PongTheme.textSecondary,
                .font: PongTheme.font(12, weight: on ? .semibold : .medium),
            ])
        // Fix titles after first style
        let titles = [0: "Teams", 1: "Mission", 2: "Setup"]
        if let t = titles[b.tag] {
            b.attributedTitle = NSAttributedString(string: t, attributes: [
                .foregroundColor: on ? PongTheme.textPrimary : PongTheme.textSecondary,
                .font: PongTheme.font(12, weight: on ? .semibold : .medium),
            ])
        }
    }

    // MARK: - Header / polling

    private func updateHeader() {
        let pairs = PairState.listPairs()
        let n = pairs.count
        if n == 0 {
            headerStatus?.stringValue = "Idle"
            liveDot?.layer?.backgroundColor = PongTheme.idle.cgColor
        } else {
            headerStatus?.stringValue = n == 1 ? "1 team live" : "\(n) teams live"
            liveDot?.layer?.backgroundColor = PongTheme.live.cgColor
        }
    }

    private func startPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            // Only refresh mission tab on timer (lighter); header always
            self?.updateHeader()
            if self?.selectedTab == .mission {
                self?.rebuildMission()
            }
        }
    }

    private func updateShowTeamsChrome() {
        let n = SavedTeams.loadAll().count
        let has = n > 0
        showTeamsBtn?.isHidden = !has
        showTeamsHint?.isHidden = !has
        if has {
            let title = "Show saved teams (\(n))"
            showTeamsBtn?.attributedTitle = NSAttributedString(string: title, attributes: [
                .foregroundColor: PongTheme.textPrimary,
                .font: PongTheme.font(12, weight: .medium),
            ])
        }
    }

    // MARK: - Teams tab

    private func rebuildTeams() {
        guard let teamsList else { return }
        teamsList.subviews.forEach { $0.removeFromSuperview() }
        let boxW = teamsScroll.contentSize.width > 0 ? teamsScroll.contentSize.width : (W - 2 * PAD)
        let viewH = max(teamsScroll.contentSize.height, 200)
        let pairs = PairState.listPairs()
        let db = PairState.loadPairsDb()

        if pairs.isEmpty {
            teamsList.setFrameSize(NSSize(width: boxW, height: viewH))
            let empty = NSView(frame: NSRect(x: 0, y: viewH / 2 - 50, width: boxW, height: 100))
            PongTheme.applyCard(empty)
            empty.addSubview(Self.label("No teams yet",
                frame: NSRect(x: 16, y: 52, width: boxW - 32, height: 20), bold: true, size: 14))
            empty.addSubview(Self.label("Create a team in Setup, or link terminals you already have open.",
                frame: NSRect(x: 16, y: 20, width: boxW - 32, height: 32), size: 11, secondary: true))
            teamsList.addSubview(empty)
            // Quick CTA
            let cta = primaryButton("New team", #selector(newPairPressed(_:)),
                NSRect(x: 0, y: 24, width: boxW, height: 40))
            teamsList.addSubview(cta)
            return
        }

        var est: CGFloat = 8
        var prepared: [(String, [String: Any], [[String: Any]], String, TerminalTheme.Colors)] = []
        for name in pairs {
            let entry = db[name] as? [String: Any] ?? [:]
            var ws = Workers.list(from: entry)
            if ws.isEmpty {
                ws = [[
                    "id": "w1",
                    "label": (entry["worker_label"] as? String) ?? "Worker",
                    "type": (entry["worker_type"] as? String) ?? "linked",
                ]]
            }
            let display = (entry["display_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stowed = (entry["stowed"] as? Bool) == true
            let hermesTitle = (display.isEmpty ? name : display) + (stowed ? " · hidden" : "")
            let hCols = TerminalTheme.Colors.from(entry["colors"]) ?? .hermesDefault
            prepared.append((name, entry, ws, hermesTitle, hCols))
            est += 72 + CGFloat(ws.count) * 36 + 48 + 14
        }
        let contentH = max(viewH, est)
        teamsList.setFrameSize(NSSize(width: boxW, height: contentH))

        var y = contentH - 4
        for (name, entry, ws, hermesTitle, hCols) in prepared {
            let stowed = (entry["stowed"] as? Bool) == true
            let hNS = hCols.asNSColors
            let cardH: CGFloat = 72 + CGFloat(ws.count) * 36 + 44
            y -= cardH
            let card = NSView(frame: NSRect(x: 0, y: y, width: boxW, height: cardH - 8))
            PongTheme.applyCard(card)
            card.alphaValue = stowed ? 0.55 : 1

            // Conductor row
            let cond = entry["conductor"] as? [String: Any]
            let cl = (cond?["label"] as? String) ?? "Conductor"
            let condType = (cond?["type"] as? String) ?? ""
            card.addSubview(swatchButton(color: hNS.hi,
                frame: NSRect(x: 12, y: cardH - 36, width: 12, height: 12),
                id: name, action: #selector(hermesColorPressed(_:))))
            card.addSubview(nameButton("\(cl) · \(hermesTitle)",
                frame: NSRect(x: 30, y: cardH - 42, width: min(220, boxW - 200), height: 22),
                id: name, action: #selector(hermesNamePressed(_:))))
            if !condType.isEmpty {
                card.addSubview(Self.label(condType,
                    frame: NSRect(x: 30, y: cardH - 54, width: 80, height: 12), size: 9, secondary: true))
            }
            let chipY = cardH - 44
            var cx = boxW - 12
            func placeChip(_ t: String, _ sel: Selector) {
                let w: CGFloat = t.count > 5 ? 52 : 46
                cx -= w + 4
                card.addSubview(chipButton(t, sel, NSRect(x: cx, y: chipY, width: w, height: 24), id: name))
            }
            placeChip("Kill", #selector(killPressed(_:)))
            placeChip(stowed ? "Show" : "Hide", #selector(hidePressed(_:)))
            placeChip("Front", #selector(frontPressed(_:)))
            placeChip("Options", #selector(teamOptionsPressed(_:)))

            // Workers
            var wy = chipY - 8
            for (i, w) in ws.enumerated() {
                let wid = (w["id"] as? String) ?? "w\(i + 1)"
                let lab = (w["label"] as? String) ?? "worker"
                let typ = (w["type"] as? String) ?? ""
                wy -= 36
                let row = NSView(frame: NSRect(x: 8, y: wy, width: boxW - 16, height: 32))
                row.wantsLayer = true
                row.layer?.backgroundColor = PongTheme.bgInput.cgColor
                row.layer?.cornerRadius = 8
                let wCols = TerminalTheme.Colors.from(w["colors"]) ?? .workerDefault
                let wNS = wCols.asNSColors
                let tag = "\(name)|\(wid)"
                row.addSubview(swatchButton(color: wNS.hi,
                    frame: NSRect(x: 8, y: 10, width: 10, height: 10),
                    id: tag, action: #selector(workerColorPressed(_:))))
                row.addSubview(nameButton(lab,
                    frame: NSRect(x: 24, y: 4, width: 100, height: 24),
                    id: tag, action: #selector(workerNamePressed(_:))))
                if !typ.isEmpty {
                    row.addSubview(Self.label(typ,
                        frame: NSRect(x: 124, y: 8, width: 50, height: 14), size: 9, secondary: true))
                }
                row.addSubview(chipButton("Front", #selector(frontWorkerPressed(_:)),
                    NSRect(x: boxW - 200, y: 4, width: 44, height: 24), id: tag))
                row.addSubview(chipButton("Kill", #selector(killWorkerPressed(_:)),
                    NSRect(x: boxW - 152, y: 4, width: 40, height: 24), id: tag))
                let wperms = Workers.permissions(pair: name, workerId: wid)
                let won = ["ban_mcp", "ban_root", "ban_network", "ban_system_paths", "repo_only"]
                    .filter { (wperms[$0] as? Bool) == true }.count
                let wnote = !((wperms["custom_prompt"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let wtitle = (won > 0 || wnote) ? "Perms \(won + (wnote ? 1 : 0))" : "Perms"
                row.addSubview(chipButton(wtitle, #selector(permsWorkerPressed(_:)),
                    NSRect(x: boxW - 108, y: 4, width: 56, height: 24), id: tag))
                card.addSubview(row)
            }

            // Activity footer of card
            let act = TeamActivity.info(for: name)
            let actY: CGFloat = 8
            card.addSubview(Self.label("\(act.status)" + (act.sentAge.isEmpty ? "" : " · \(act.sentAge)"),
                frame: NSRect(x: 12, y: actY + 14, width: boxW - 140, height: 14), size: 10, secondary: true))
            card.addSubview(Self.label(act.claim.isEmpty ? "No claim yet" : act.claim,
                frame: NSRect(x: 12, y: actY, width: boxW - 140, height: 14), size: 10, secondary: true))
            card.addSubview(chipButton("Reply", #selector(openReplyPressed(_:)),
                NSRect(x: boxW - 120, y: actY + 4, width: 48, height: 24), id: name))
            card.addSubview(chipButton("Sent", #selector(openSentPressed(_:)),
                NSRect(x: boxW - 68, y: actY + 4, width: 44, height: 24), id: name))

            teamsList.addSubview(card)
            y -= 6
        }

        let cv = teamsScroll.contentView
        let topY = max(0, contentH - cv.bounds.height)
        cv.scroll(to: NSPoint(x: 0, y: topY))
        teamsScroll.reflectScrolledClipView(cv)
    }

    // MARK: - Mission tab (snapshot)

    private func loadSnapshot() -> [String: Any] {
        // Prefer CLI snapshot for contract fidelity
        let out = Pong.sh("export PATH=\"$HOME/bin:/opt/homebrew/bin:$PATH\"; pong snapshot --compact 2>/dev/null | head -c 500000")
        if let data = out.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           obj["contract_version"] != nil {
            return obj
        }
        // Fallback: read snapshot.json
        return Pong.loadJSON(Pong.stateDir + "/snapshot.json")
    }

    private func rebuildMission() {
        guard let missionList else { return }
        missionList.subviews.forEach { $0.removeFromSuperview() }
        let boxW = missionScroll.contentSize.width > 0 ? missionScroll.contentSize.width : (W - 2 * PAD)
        let snap = loadSnapshot()
        let teams = (snap["teams"] as? [[String: Any]]) ?? []
        let ledger = (snap["ledger"] as? [String: Any]) ?? [:]
        let bridgeOn = (snap["bridge_on"] as? Bool) == true
        let bridge = (snap["bridge"] as? String) ?? ""

        var blocks: [NSView] = []
        var totalH: CGFloat = 12

        // Bridge card
        let bridgeCard = NSView(frame: NSRect(x: 0, y: 0, width: boxW, height: 64))
        PongTheme.applyCard(bridgeCard)
        let bridgeTitle = bridgeOn ? "Bridge on" : "Bridge off"
        bridgeCard.addSubview(Self.label(bridgeTitle,
            frame: NSRect(x: 14, y: 34, width: 200, height: 18), bold: true, size: 13))
        bridgeCard.addSubview(Self.label(bridge.isEmpty ? "No bound session" : bridge,
            frame: NSRect(x: 14, y: 12, width: boxW - 28, height: 18), size: 10, secondary: true))
        let dot = NSView(frame: NSRect(x: boxW - 28, y: 28, width: 10, height: 10))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 5
        dot.layer?.backgroundColor = (bridgeOn ? PongTheme.live : PongTheme.idle).cgColor
        bridgeCard.addSubview(dot)
        blocks.append(bridgeCard)
        totalH += 64 + 10

        // Ledger strip
        let rounds = ledger["rounds"] as? Int ?? 0
        let rate = ledger["accept_rate"] as? Double ?? 0
        let streak = ledger["reject_streak"] as? Int ?? 0
        let ledCard = NSView(frame: NSRect(x: 0, y: 0, width: boxW, height: 56))
        PongTheme.applyCard(ledCard)
        ledCard.addSubview(Self.label("Verdict ledger",
            frame: NSRect(x: 14, y: 30, width: 160, height: 16), bold: true, size: 12))
        ledCard.addSubview(Self.label(
            "\(rounds) rounds · \(Int(rate * 100))% accept · reject streak \(streak)",
            frame: NSRect(x: 14, y: 10, width: boxW - 28, height: 16), size: 11, secondary: true))
        blocks.append(ledCard)
        totalH += 56 + 10

        if teams.isEmpty {
            let empty = NSView(frame: NSRect(x: 0, y: 0, width: boxW, height: 80))
            PongTheme.applyCard(empty)
            empty.addSubview(Self.label("No team data in snapshot",
                frame: NSRect(x: 14, y: 44, width: boxW - 28, height: 18), bold: true, size: 13))
            empty.addSubview(Self.label("Start a team, then jobs will appear here.",
                frame: NSRect(x: 14, y: 20, width: boxW - 28, height: 18), size: 11, secondary: true))
            blocks.append(empty)
            totalH += 80 + 10
        }

        for team in teams {
            let session = (team["session"] as? String) ?? "?"
            let display = (team["display_name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? session
            let cond = team["conductor"] as? [String: Any]
            let condLabel = (cond?["label"] as? String) ?? "Conductor"
            let jobs = team["jobs"] as? [String: Any] ?? [:]
            let openJobs = (jobs["open"] as? [[String: Any]]) ?? []
            let counts = jobs["counts"] as? [String: Any] ?? [:]
            let openN = counts["open"] as? Int ?? openJobs.count
            let workers = (team["workers"] as? [[String: Any]]) ?? []

            let jobRows = max(openJobs.count, 1)
            let cardH: CGFloat = 70 + CGFloat(workers.count) * 22 + CGFloat(jobRows) * 28
            let card = NSView(frame: NSRect(x: 0, y: 0, width: boxW, height: cardH))
            PongTheme.applyCard(card)
            card.addSubview(Self.label(display,
                frame: NSRect(x: 14, y: cardH - 28, width: boxW - 100, height: 18), bold: true, size: 13))
            card.addSubview(Self.label("\(condLabel) · \(openN) open job\(openN == 1 ? "" : "s")",
                frame: NSRect(x: 14, y: cardH - 44, width: boxW - 28, height: 14), size: 10, secondary: true))

            var ly = cardH - 56
            for w in workers {
                let lab = (w["label"] as? String) ?? (w["id"] as? String) ?? "?"
                let hint = (w["status_hint"] as? String) ?? "idle"
                let oj = w["open_jobs"] as? Int ?? 0
                ly -= 20
                card.addSubview(Self.label("\(lab)  ·  \(hint)" + (oj > 0 ? " (\(oj))" : ""),
                    frame: NSRect(x: 14, y: ly, width: boxW - 28, height: 16), size: 11, secondary: true))
            }

            ly -= 8
            if openJobs.isEmpty {
                ly -= 24
                card.addSubview(Self.label("No open jobs — use pong job create from the conductor",
                    frame: NSRect(x: 14, y: ly, width: boxW - 28, height: 20), size: 10, secondary: true))
            } else {
                for j in openJobs.prefix(8) {
                    ly -= 28
                    let jid = (j["id"] as? String) ?? "?"
                    let st = (j["status"] as? String) ?? "?"
                    let prev = (j["task_preview"] as? String) ?? ""
                    let row = NSView(frame: NSRect(x: 10, y: ly, width: boxW - 20, height: 24))
                    row.wantsLayer = true
                    row.layer?.backgroundColor = PongTheme.bgInput.cgColor
                    row.layer?.cornerRadius = 6
                    row.addSubview(Self.label(st,
                        frame: NSRect(x: 8, y: 4, width: 70, height: 16), size: 10, secondary: false))
                    row.addSubview(Self.label(prev.isEmpty ? jid : prev,
                        frame: NSRect(x: 82, y: 4, width: boxW - 120, height: 16), size: 10, secondary: true))
                    card.addSubview(row)
                }
            }
            blocks.append(card)
            totalH += cardH + 10
        }

        // Events tail
        let events = (snap["events_tail"] as? [[String: Any]]) ?? []
        if !events.isEmpty {
            let show = Array(events.suffix(6).reversed())
            let eh: CGFloat = 28 + CGFloat(show.count) * 18
            let ec = NSView(frame: NSRect(x: 0, y: 0, width: boxW, height: eh))
            PongTheme.applyCard(ec)
            ec.addSubview(Self.label("Recent events",
                frame: NSRect(x: 14, y: eh - 24, width: 160, height: 16), bold: true, size: 12))
            var ey = eh - 40
            for e in show {
                let t = (e["type"] as? String) ?? "?"
                let jid = (e["job_id"] as? String) ?? ""
                let st = (e["status"] as? String) ?? ""
                let line = [t, jid, st].filter { !$0.isEmpty }.joined(separator: " · ")
                ec.addSubview(Self.label(line,
                    frame: NSRect(x: 14, y: ey, width: boxW - 28, height: 14), size: 10, secondary: true))
                ey -= 18
            }
            blocks.append(ec)
            totalH += eh + 10
        }

        let contentH = max(missionScroll.contentSize.height, totalH + 20)
        missionList.setFrameSize(NSSize(width: boxW, height: contentH))
        var y = contentH - 8
        for b in blocks {
            y -= b.frame.height
            b.setFrameOrigin(NSPoint(x: 0, y: y))
            missionList.addSubview(b)
            y -= 10
        }
        let mcv = missionScroll.contentView
        let mTop = max(0, contentH - mcv.bounds.height)
        mcv.scroll(to: NSPoint(x: 0, y: mTop))
        missionScroll.reflectScrolledClipView(mcv)
    }

    // MARK: - Actions (preserved)

    @objc private func showTeamsPressed(_ sender: NSButton) {
        TeamsManagerPanel.shared.show { [weak self] in self?.refreshUI() }
    }

    @objc private func newPairPressed(_ sender: NSButton) {
        guard let (conductor, workers) = AppDelegate.pickTeamLaunch() else {
            refreshUI()
            return
        }
        if workers.isEmpty { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let name = Pairing.startFresh(workers: workers, conductor: conductor)
            usleep(200_000)
            DispatchQueue.main.async {
                self.selectTab(.teams, animated: true)
                self.refreshUI()
                Self.showPairPersistTip(name)
            }
        }
    }

    @objc private func linkPressed(_ sender: NSButton) {
        Pong.log("link → guide")
        guide.startLink(parent: self)
    }

    @objc private func frontPressed(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue else { return }
        DispatchQueue.global(qos: .userInitiated).async { Pairing.bringToFront(name) }
    }

    @objc private func killPressed(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue else { return }
        Pairing.killPair(name)
        refreshUI()
    }

    @objc private func hidePressed(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue else { return }
        let stowed = ((PairState.loadPairsDb()[name] as? [String: Any])?["stowed"] as? Bool) == true
        DispatchQueue.global(qos: .userInitiated).async {
            if stowed { Pairing.unstow(name) } else { Pairing.stow(name) }
            DispatchQueue.main.async { self.refreshUI() }
        }
    }

    @objc private func openReplyPressed(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue else { return }
        ReplyViewerController.shared.show(session: name, kind: .reply)
    }

    @objc private func openSentPressed(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue else { return }
        ReplyViewerController.shared.show(session: name, kind: .sent)
    }

    @objc private func permsPressed(_ sender: NSButton) {
        guard let name = sender.identifier?.rawValue else { return }
        PermissionsSheetController.shared.show(for: name, workerId: nil) { [weak self] in
            self?.refreshUI()
        }
    }

    @objc private func frontWorkerPressed(_ sender: NSButton) {
        guard let tag = sender.identifier?.rawValue else { return }
        let parts = tag.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        Workers.frontWorker(pair: parts[0], workerId: parts[1])
    }

    @objc private func killWorkerPressed(_ sender: NSButton) {
        guard let tag = sender.identifier?.rawValue else { return }
        let parts = tag.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \(parts[1]) from team?"
        alert.informativeText = "Kills that worker terminal. Conductor stays if other workers remain."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = Workers.removeWorker(pair: parts[0], workerId: parts[1])
        refreshUI()
    }

    @objc private func permsWorkerPressed(_ sender: NSButton) {
        guard let tag = sender.identifier?.rawValue else { return }
        let parts = tag.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        PermissionsSheetController.shared.show(for: parts[0], workerId: parts[1]) { [weak self] in
            self?.refreshUI()
        }
    }

    @objc private func teamOptionsPressed(_ sender: NSButton) {
        guard let pair = sender.identifier?.rawValue else { return }
        TeamOptionsSheetController.shared.show(for: pair) { [weak self] in
            self?.refreshUI()
        }
    }

    @objc private func hermesNamePressed(_ sender: NSButton) {
        guard let pair = sender.identifier?.rawValue else { return }
        let entry = PairState.loadPairsDb()[pair] as? [String: Any] ?? [:]
        let current = (entry["display_name"] as? String) ?? pair
        promptName(title: "Name this team", value: current) { name in
            Workers.setPairDisplayName(pair, name)
            self.refreshUI()
        }
    }

    @objc private func workerNamePressed(_ sender: NSButton) {
        guard let tag = sender.identifier?.rawValue else { return }
        let parts = tag.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let entry = PairState.loadPairsDb()[parts[0]] as? [String: Any] ?? [:]
        let ws = Workers.list(from: entry)
        let cur = (ws.first(where: { ($0["id"] as? String) == parts[1] })?["label"] as? String) ?? parts[1]
        promptName(title: "Name worker \(parts[1])", value: cur) { name in
            Workers.setWorkerLabel(pair: parts[0], workerId: parts[1], label: name)
            self.refreshUI()
        }
    }

    @objc private func hermesColorPressed(_ sender: NSButton) {
        guard let pair = sender.identifier?.rawValue else { return }
        let entry = PairState.loadPairsDb()[pair] as? [String: Any] ?? [:]
        let cols = TerminalTheme.Colors.from(entry["colors"]) ?? .hermesDefault
        ColorThemeSheet.shared.show(title: "Conductor colors · \(pair)", colors: cols) { [weak self] c in
            Workers.setPairColors(pair, colors: c)
            self?.refreshUI()
        }
    }

    @objc private func workerColorPressed(_ sender: NSButton) {
        guard let tag = sender.identifier?.rawValue else { return }
        let parts = tag.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let entry = PairState.loadPairsDb()[parts[0]] as? [String: Any] ?? [:]
        let ws = Workers.list(from: entry)
        let w = ws.first(where: { ($0["id"] as? String) == parts[1] }) ?? [:]
        let cols = TerminalTheme.Colors.from(w["colors"]) ?? .workerDefault
        ColorThemeSheet.shared.show(title: "Colors · \(parts[1])", colors: cols) { [weak self] c in
            Workers.setWorkerColors(pair: parts[0], workerId: parts[1], colors: c)
            self?.refreshUI()
        }
    }

    private func promptName(title: String, value: String, onOK: @escaping (String) -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Shows in the panel and Terminal title."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = value
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { onOK(name) }
    }

    @objc private func refreshPressed(_ sender: NSButton) { refreshUI() }

    @objc private func closePressed(_ sender: NSButton) {
        guide.closeGuide()
        refreshTimer?.invalidate()
        refreshTimer = nil
        window?.close()
    }

    static func showPairPersistTip(_ name: String) {
        let flag = Pong.stateDir + "/dont-remind-pair-persist"
        guard !FileManager.default.fileExists(atPath: flag) else { return }
        let label = name.isEmpty ? "this team" : name
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Team stays connected"
        alert.informativeText =
            "“\(label)” stays linked until you hit Kill — even if you quit Pong.\n\n" +
            "Link existing keeps the worker’s model and chat.\n" +
            "New team starts clean conductor + workers.\n\n" +
            "Jobs: pong job create · paste is optional."
        alert.addButton(withTitle: "Got it")
        alert.addButton(withTitle: "Don't remind me")
        if alert.runModal() == .alertSecondButtonReturn {
            try? "1\n".write(toFile: flag, atomically: true, encoding: .utf8)
        }
    }
}
