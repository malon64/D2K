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
    property var hostWindow: Window.window
    readonly property real soundEffectVolume: 0.75

    readonly property var currentCollection: orderedCollections.length > consoleIndex
                                             ? orderedCollections[consoleIndex] : null
    readonly property var games: currentCollection ? currentCollection.games : null
    readonly property int gameCount: games ? games.count : 0
    readonly property var selectedGame: games && gameCount > gameIndex ? games.get(gameIndex) : null
    readonly property int pageCount: Math.max(1, Math.ceil(gameCount / d2k.pageSize))
    readonly property int pageIndex: Math.floor(gameIndex / d2k.pageSize)

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
        var saved = api.memory.get("d2kGame:" + d2k.consoleId(currentCollection))
        gameIndex = (typeof saved === "number" && saved >= 0 && saved < gameCount) ? saved : 0
        navState = "games"
        api.memory.set("d2kNav", "games")
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
        if (savedNav === "games" || savedNav === "consoles") {
            rebuildCollections()
            restoreConsole()

            if (savedNav === "games" && currentCollection && gameCount) {
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
