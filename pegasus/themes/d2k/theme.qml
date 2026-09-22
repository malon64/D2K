import QtQuick 2.0
import QtQuick.Window 2.15
import QtMultimedia 5.9

FocusScope {
    id: root
    focus: true

    property string navState: "boot"
    property int consoleIndex: 0

    // Direction of the last console change: +1 for next, -1 for previous.
    property int consoleStep: 1
    property int gameIndex: 0
    property bool launching: false
    property var orderedCollections: []

    // Music state. The theme never plays audio itself: MPD owns playback (it
    // already runs the menu music), and every control here is a command posted
    // through api.memory for run.ps1 to hand to scripts/windows/mpd.ps1.
    // playingIndex is what this theme last asked MPD to play, which is why it
    // survives leaving and re-entering the music screen.
    property int playingIndex: -1
    property bool musicPaused: false
    property int musicSeq: 0
    property int musicPositionMs: -1
    property int musicDurationMs: -1

    // Last file MPD reported, so the track lookup only runs when it changes
    // rather than on every poll.
    property string musicStatusFile: ""

    // When the last play/pause command was sent. Pause fades MPD's volume down
    // over ~600ms before the state actually flips, so a status poll landing in
    // that window still reports the old state. Honouring it would snap the
    // button back mid-transition, so local state wins briefly.
    property double musicCommandAt: 0
    readonly property int musicCommandGrace: 1500
    property var hostWindow: Window.window
    readonly property real soundEffectVolume: 0.75

    readonly property var currentCollection: orderedCollections.length > consoleIndex
                                             ? orderedCollections[consoleIndex] : null
    readonly property var games: currentCollection ? currentCollection.games : null
    readonly property int gameCount: games ? games.count : 0
    readonly property var selectedGame: games && gameCount > gameIndex ? games.get(gameIndex) : null
    readonly property int pageCount: Math.max(1, Math.ceil(gameCount / d2k.pageSize))
    readonly property int pageIndex: Math.floor(gameIndex / d2k.pageSize)

    // The music collection is a normal Pegasus collection whose "games" are
    // tracks, so it needs its own screens rather than the game grid.
    readonly property bool musicCollection: d2k.consoleId(currentCollection) === "music"
    readonly property var playingTrack: games && playingIndex >= 0 && playingIndex < gameCount
                                        ? games.get(playingIndex) : null

    D2KTheme { id: d2k }

    SoundEffect {
        id: navigationSound
        source: "assets/sound-effects/MNT_YTK_fx_reflect.wav"
        volume: root.soundEffectVolume
    }

    SoundEffect {
        id: backSound
        source: "assets/sound-effects/MNT_YTK_drums_perc_blooper.wav"
        volume: 1.0
    }

    // Same sample as backSound, kept as its own instance so the two can be
    // retuned independently.
    SoundEffect {
        id: musicToggleSound
        source: "assets/sound-effects/MNT_YTK_drums_perc_blooper.wav"
        volume: root.soundEffectVolume
    }

    SoundEffect {
        id: consoleSound
        source: "assets/sound-effects/ESM_Mellow_Message_Ping_Notification_Synth_Electronic_Cartoon.wav"
        volume: 1.0
    }

    SoundEffect {
        id: gameSound
        source: "assets/sound-effects/MNT_YTK_ui_button.wav"
        volume: root.soundEffectVolume
    }

    SoundEffect {
        id: launchSound
        source: "assets/sound-effects/MNT_YTK_fx_course_clear_C.wav"
        volume: root.soundEffectVolume
    }

    SoundEffect {
        id: bootSound
        source: "assets/sound-effects/MNT_YTK_ui_console_awake.wav"
        volume: root.soundEffectVolume
    }

    function rebuildCollections() {
        var list = []
        for (var i = 0; i < api.collections.count; i++)
            list.push(api.collections.get(i))

        var order = d2k.consoleOrder
        list.sort(function (a, b) {
            var rankA = order.indexOf(d2k.consoleId(a))
            var rankB = order.indexOf(d2k.consoleId(b))
            if (rankA < 0) rankA = order.length
            if (rankB < 0) rankB = order.length
            if (rankA !== rankB)
                return rankA - rankB
            return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0)
        })

        orderedCollections = list
    }

    function restoreConsole() {
        var saved = api.memory.get("d2kConsole")
        if (typeof saved !== "string" || !saved.length)
            return

        for (var i = 0; i < orderedCollections.length; i++) {
            if (d2k.consoleId(orderedCollections[i]) === saved) {
                consoleIndex = i
                return
            }
        }
    }

    function selectConsole(index) {
        if (!orderedCollections.length)
            return

        navigationSound.play()

        // The selector slides its console art sideways, and the direction has
        // to come from the press rather than from the resulting index: the
        // ends of the list wrap around, so the index alone would send the last
        // -> first step scrolling backwards through the whole carousel.
        // Assigned before consoleIndex so the panels always see the step that
        // belongs to the change they are about to render.
        var wrapped = (index + orderedCollections.length) % orderedCollections.length
        if (wrapped !== consoleIndex)
            consoleStep = index > consoleIndex ? 1 : -1

        consoleIndex = wrapped
        api.memory.set("d2kConsole", d2k.consoleId(currentCollection))
    }

    function openConsole() {
        if (!currentCollection || !gameCount)
            return

        consoleSound.play()

        if (musicCollection) {
            navState = "music"
            api.memory.set("d2kNav", "music")
            return
        }

        var saved = api.memory.get("d2kGame:" + d2k.consoleId(currentCollection))
        gameIndex = (typeof saved === "number" && saved >= 0 && saved < gameCount) ? saved : 0
        navState = "games"
        api.memory.set("d2kNav", "games")
    }

    // Every music control is posted the same way: run.ps1 already polls
    // config/theme_settings/d2k.json every 100 ms, so bumping the sequence
    // number is what makes it notice a new command. The track path is sent
    // rather than an index because MPD's queue order is its own -- the script
    // resolves the path against the queue.
    function sendMusicCommand(action, track) {
        musicSeq += 1
        api.memory.set("d2kMusicAction", action)
        api.memory.set("d2kMusicTrack", track === undefined ? "" : track)
        api.memory.set("d2kMusicSeq", musicSeq)
    }

    function trackPath(index) {
        if (!games || index < 0 || index >= gameCount)
            return ""

        var track = games.get(index)
        if (!track || !track.files || track.files.count < 1)
            return ""

        return "" + track.files.get(0).path
    }

    function playTrack(index) {
        if (!gameCount || index < 0 || index >= gameCount)
            return

        gameSound.play()
        playingIndex = index
        musicPaused = false
        musicCommandAt = Date.now()
        musicPositionMs = -1
        musicDurationMs = -1
        sendMusicCommand("play", trackPath(index))
    }

    function toggleMusic() {
        if (playingIndex < 0)
            return

        musicToggleSound.play()
        musicPaused = !musicPaused
        musicCommandAt = Date.now()
        sendMusicCommand(musicPaused ? "pause" : "resume")
    }

    function baseName(path) {
        var text = "" + path
        return text.substring(Math.max(text.lastIndexOf("/"), text.lastIndexOf("\\")) + 1)
    }

    // Applies what run.ps1 published. MPD is the authority here, not this
    // theme: it shuffles and advances on its own, so the highlighted row
    // follows the status file rather than only what was last tapped.
    function applyMusicStatus(status) {
        if (!status)
            return

        if (Date.now() - musicCommandAt > musicCommandGrace)
            musicPaused = status.state === "pause"

        musicPositionMs = typeof status.positionMs === "number" ? status.positionMs : -1
        musicDurationMs = typeof status.durationMs === "number" ? status.durationMs : -1

        if (!status.file || !games)
            return

        var name = baseName(status.file)
        if (name === musicStatusFile)
            return

        musicStatusFile = name
        for (var i = 0; i < gameCount; i++) {
            if (baseName(trackPath(i)) === name) {
                playingIndex = i
                return
            }
        }
    }

    function readMusicStatus() {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE || !request.responseText)
                return

            try { root.applyMusicStatus(JSON.parse(request.responseText)) }
            catch (error) { /* half-written file: the next poll picks it up */ }
        }
        request.open("GET", Qt.resolvedUrl("mpd-status.json"))
        request.send()
    }

    // Only while the music screen is up -- nothing else binds to these values,
    // and MPD does not need polling for the rest of the menu.
    Timer {
        id: musicStatusPoll
        interval: 500
        repeat: true
        running: root.navState === "music"
        triggeredOnStart: true
        onTriggered: root.readMusicStatus()
    }

    function selectGame(index) {
        if (!gameCount)
            return

        gameIndex = Math.max(0, Math.min(gameCount - 1, index))
        if (currentCollection)
            api.memory.set("d2kGame:" + d2k.consoleId(currentCollection), gameIndex)
    }

    function stepPage(delta) {
        if (!gameCount)
            return

        navigationSound.play()
        selectGame(gameIndex + delta * d2k.pageSize)
    }

    function launchSelectedGame() {
        if (launching || !selectedGame)
            return

        api.memory.set("d2kMusicLaunch", Date.now())
        launchSound.play()
        launching = true
        launchGuard.restart()
    }

    function backToCollections() {
        backSound.play()
        navState = "consoles"
        api.memory.set("d2kNav", "consoles")
    }

    Timer {
        id: launchGuard
        interval: 1350 // The launch effect is 1310 ms; leave time for its ending before teardown.
        onTriggered: {
            root.selectedGame.launch()
        }
    }

    // Pegasus tears down this entire QML scene before the game process starts
    // and only rebuilds it -- cold, from Component.onCompleted -- once that
    // process exits (confirmed via lastrun.log: the "D2K preview" boot log
    // line reappears in the same second the launched process is reported
    // finished, and the binary exports processLaunchOk / teardownComplete /
    // rebuild symbols consistent with that). So there is no window to hide or
    // restore here, no code that can run while a game is playing, and no
    // signal that "the game is still running" to react to -- this theme
    // instance is simply gone for the whole game. The only channel that
    // survives is api.memory (persisted to
    // config/theme_settings/d2k.json), which is why navState is mirrored into
    // it below and restored on the next boot instead of being kept as
    // in-memory-only state.
    //
    // Ending a DS game is therefore entirely scripts/windows/launch-emulator.ps1's
    // job, not this theme's: it is the only D2K code alive for the whole
    // session. The physical Home button (ESP32, not yet built) will signal it
    // directly; until then dropping a file at
    // %LOCALAPPDATA%\D2K\home-request has the same effect. When melonDS
    // exits, Pegasus rebuilds this scene and bootSequence below restores
    // navState from memory.

    Timer {
        id: bootSequence
        interval: 2050 // The boot effect is 2000 ms; keep the logo visible through its ending.
        running: true
        onTriggered: {
            root.rebuildCollections()
            root.restoreConsole()
            api.memory.set("d2kMusicReady", true)
            root.navState = "consoles"
        }
    }

    // Both target panels are 800x480. Windows keeps its existing desktop
    // preview; Linux uses the two physical outputs when present, or scales a
    // vertical preview to fit a single TV while the hardware screens are away.
    // previewTitleBar is the measured Windows caption plus border above a
    // client area (SM_CYCAPTION + SM_CYSIZEFRAME + SM_CXPADDEDBORDER = 58
    // here); previewHinge is the visible gap left between the two windows.
    // Adjust both together with launch-emulator.ps1 if the desktop theme
    // changes. None of this applies on the device, which has no chrome.
    readonly property int previewPanelWidth: 800
    readonly property int previewPanelHeight: 480
    readonly property int previewTitleBar: 58
    readonly property int previewHinge: 32

    Component.onCompleted: {
        if (hostWindow) {
            if (Qt.platform.os === "windows") {
                var screen = Qt.application.screens[0]
                var stackHeight = previewPanelHeight * 2 + previewTitleBar + previewHinge
                var left = Math.round(screen.virtualX + (screen.width - previewPanelWidth) / 2)
                var top = Math.round(screen.virtualY + Math.max(40, (screen.height - stackHeight) / 2))

                hostWindow.width = previewPanelWidth
                hostWindow.height = previewPanelHeight
                hostWindow.x = left
                hostWindow.y = top

                touchWindow.width = previewPanelWidth
                touchWindow.height = previewPanelHeight
                touchWindow.x = left
                touchWindow.y = top + previewPanelHeight + previewTitleBar + previewHinge

                console.log("D2K preview: screen " + screen.width + "x" + screen.height
                            + "  top " + left + "," + top
                            + "  touch " + touchWindow.x + "," + touchWindow.y)
            }
            else if (Qt.application.screens.length >= 2) {
                hostWindow.flags = Qt.FramelessWindowHint
                var upper = Qt.application.screens[0]
                var lower = Qt.application.screens[1]
                hostWindow.screen = upper
                hostWindow.x = upper.virtualX
                hostWindow.y = upper.virtualY
                hostWindow.width = upper.width
                hostWindow.height = upper.height
                touchWindow.screen = lower
                touchWindow.x = lower.virtualX
                touchWindow.y = lower.virtualY
                touchWindow.width = lower.width
                touchWindow.height = lower.height
            }
            else {
                hostWindow.flags = Qt.FramelessWindowHint
                var tv = Qt.application.screens[0]
                var tvGap = 20
                var tvScale = Math.min(tv.width / previewPanelWidth,
                                       (tv.height - tvGap) / (previewPanelHeight * 2))
                var tvWidth = Math.max(1, Math.round(previewPanelWidth * tvScale))
                var tvHeight = Math.max(1, Math.round(previewPanelHeight * tvScale))
                var tvLeft = Math.round(tv.virtualX + (tv.width - tvWidth) / 2)
                var tvTop = Math.round(tv.virtualY + (tv.height - (tvHeight * 2 + tvGap)) / 2)

                hostWindow.screen = tv
                hostWindow.x = tvLeft
                hostWindow.y = tvTop
                hostWindow.width = tvWidth
                hostWindow.height = tvHeight
                touchWindow.screen = tv
                touchWindow.x = tvLeft
                touchWindow.y = tvTop + tvHeight + tvGap
                touchWindow.width = tvWidth
                touchWindow.height = tvHeight
            }
        }

        // Resume where the last game left off. run.ps1 clears d2kNav on every
        // power-on, so this only fires on the mid-session rebuild that
        // follows a game exiting (see the note above launchGuard) -- never
        // on an actual cold boot, which always plays the boot screen and
        // lands on the console selector as before.
        var savedNav = api.memory.get("d2kNav")
        if (savedNav === "games" || savedNav === "consoles" || savedNav === "music") {
            rebuildCollections()
            restoreConsole()

            if (savedNav === "music" && currentCollection && gameCount && musicCollection) {
                navState = "music"
            }
            else if (savedNav === "games" && currentCollection && gameCount) {
                var savedGame = api.memory.get("d2kGame:" + d2k.consoleId(currentCollection))
                gameIndex = (typeof savedGame === "number" && savedGame >= 0 && savedGame < gameCount) ? savedGame : 0
                navState = "games"
            }
            else {
                navState = "consoles"
            }

            bootSequence.stop()
        }
        else {
            bootSound.play()
        }
    }

    Keys.onPressed: {
        if (navState === "boot")
            return

        if (navState === "consoles") {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                event.accepted = true
                selectConsole(consoleIndex - 1)
            }
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                event.accepted = true
                selectConsole(consoleIndex + 1)
            }
            else if (api.keys.isAccept(event)) {
                event.accepted = true
                openConsole()
            }
            return
        }

        // The track list is touch-only by design: there is no focused row to
        // move, so the D-pad does nothing here and only Back is wired up.
        if (navState === "music") {
            if (api.keys.isCancel(event)) {
                event.accepted = true
                backToCollections()
            }
            else if (api.keys.isAccept(event)) {
                event.accepted = true
                toggleMusic()
            }
            return
        }

        if (event.key === Qt.Key_Left) {
            event.accepted = true
            navigationSound.play()
            selectGame(gameIndex - 1)
        }
        else if (event.key === Qt.Key_Right) {
            event.accepted = true
            navigationSound.play()
            selectGame(gameIndex + 1)
        }
        else if (event.key === Qt.Key_Up) {
            event.accepted = true
            navigationSound.play()
            selectGame(gameIndex - d2k.gridColumns)
        }
        else if (event.key === Qt.Key_Down) {
            event.accepted = true
            navigationSound.play()
            selectGame(gameIndex + d2k.gridColumns)
        }
        else if (event.key === Qt.Key_PageUp) {
            event.accepted = true
            stepPage(-1)
        }
        else if (event.key === Qt.Key_PageDown) {
            event.accepted = true
            stepPage(1)
        }
        else if (api.keys.isAccept(event)) {
            event.accepted = true
            launchSelectedGame()
        }
        else if (api.keys.isCancel(event)) {
            event.accepted = true
            backToCollections()
        }
    }

    TopPanel {
        theme: d2k
        scale: root.width / 800
        transformOrigin: Item.TopLeft
        navState: root.navState
        collection: root.currentCollection
        game: root.selectedGame
        gameCount: root.gameCount
        playingTrack: root.playingTrack
        playingIndex: root.playingIndex
        paused: root.musicPaused
        positionMs: root.musicPositionMs
        durationMs: root.musicDurationMs
    }

    Window {
        id: touchWindow
        title: "D2K Touch"
        flags: Qt.platform.os === "windows" ? Qt.Window : Qt.FramelessWindowHint
        width: root.previewPanelWidth
        height: root.previewPanelHeight
        x: 40
        y: 640
        visible: true
        transientParent: null
        color: d2k.touchBase

        TouchPanel {
            theme: d2k
            scale: touchWindow.width / 800
            transformOrigin: Item.TopLeft
            navState: root.navState
            collection: root.currentCollection
            consoleStep: root.consoleStep
            games: root.games
            gameCount: root.gameCount
            gameIndex: root.gameIndex
            pageIndex: root.pageIndex
            pageCount: root.pageCount
            launching: root.launching
            playingIndex: root.playingIndex
            paused: root.musicPaused

            onPlayTrack: root.playTrack(index)
            onTogglePlayback: root.toggleMusic()
            onPreviousConsole: root.selectConsole(root.consoleIndex - 1)
            onNextConsole: root.selectConsole(root.consoleIndex + 1)
            onOpenConsole: root.openConsole()
            onChooseGame: {
                gameSound.play()
                root.selectGame(index)
            }
            onStepPage: root.stepPage(delta)
            onLaunch: root.launchSelectedGame()
            onBack: root.backToCollections()
        }
    }
}
