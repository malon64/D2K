import QtQuick 2.0
import QtQuick.Window 2.15

FocusScope {
    id: root
    focus: true

    property string navState: "boot"
    property int consoleIndex: 0
    property int gameIndex: 0
    property bool launching: false
    property var orderedCollections: []
    property var hostWindow: Window.window

    readonly property var currentCollection: orderedCollections.length > consoleIndex
                                             ? orderedCollections[consoleIndex] : null
    readonly property var games: currentCollection ? currentCollection.games : null
    readonly property int gameCount: games ? games.count : 0
    readonly property var selectedGame: games && gameCount > gameIndex ? games.get(gameIndex) : null
    readonly property int pageCount: Math.max(1, Math.ceil(gameCount / d2k.pageSize))
    readonly property int pageIndex: Math.floor(gameIndex / d2k.pageSize)

    D2KTheme { id: d2k }

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

        consoleIndex = (index + orderedCollections.length) % orderedCollections.length
        api.memory.set("d2kConsole", d2k.consoleId(currentCollection))
    }

    function openConsole() {
        if (!currentCollection || !gameCount)
            return

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

        selectGame(gameIndex + delta * d2k.pageSize)
    }

    function launchSelectedGame() {
        if (launching || !selectedGame)
            return

        launching = true
        launchGuard.restart()
    }

    function backToCollections() {
        navState = "consoles"
        api.memory.set("d2kNav", "consoles")
    }

    Timer {
        id: launchGuard
        interval: 240
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
    // Ending a game is therefore entirely scripts/windows/launch-melonds.ps1's
    // job, not this theme's: it is the only D2K code alive for the whole
    // session. The physical Home button (ESP32, not yet built) will signal it
    // directly; until then dropping a file at
    // %LOCALAPPDATA%\D2K\home-request has the same effect. When melonDS
    // exits, Pegasus rebuilds this scene and bootSequence below restores
    // navState from memory.

    Timer {
        id: bootSequence
        interval: 900
        running: true
        onTriggered: {
            root.rebuildCollections()
            root.restoreConsole()
            root.navState = "consoles"
        }
    }

    // Windows preview geometry. Both target panels are 800x480 -- a Waveshare
    // 5-inch HDMI on top and a 4-DSI-TOUCH-A rotated to landscape below -- so
    // the preview runs at native size rather than scaled down, and legibility
    // on the desktop matches the device. Qt sizes and positions the client
    // area, so no allowance is needed for the title bar itself; titleBar only
    // reserves room for the lower window's caption between the two panels.
    // scripts/windows/launch-melonds.ps1 repeats this layout so melonDS lands
    // on exactly the same rectangles.
    // previewTitleBar is the measured Windows caption plus border above a
    // client area (SM_CYCAPTION + SM_CYSIZEFRAME + SM_CXPADDEDBORDER = 58
    // here); previewHinge is the visible gap left between the two windows.
    // Adjust both together with launch-melonds.ps1 if the desktop theme
    // changes. None of this applies on the device, which has no chrome.
    readonly property int previewPanelWidth: 800
    readonly property int previewPanelHeight: 480
    readonly property int previewTitleBar: 58
    readonly property int previewHinge: 32

    Component.onCompleted: {
        if (!hostWindow)
            return

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
            selectGame(gameIndex - 1)
        }
        else if (event.key === Qt.Key_Right) {
            event.accepted = true
            selectGame(gameIndex + 1)
        }
        else if (event.key === Qt.Key_Up) {
            event.accepted = true
            selectGame(gameIndex - d2k.gridColumns)
        }
        else if (event.key === Qt.Key_Down) {
            event.accepted = true
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
            games: root.games
            gameCount: root.gameCount
            gameIndex: root.gameIndex
            pageIndex: root.pageIndex
            pageCount: root.pageCount
            launching: root.launching

            onPreviousConsole: root.selectConsole(root.consoleIndex - 1)
            onNextConsole: root.selectConsole(root.consoleIndex + 1)
            onOpenConsole: root.openConsole()
            onChooseGame: root.selectGame(index)
            onStepPage: root.stepPage(delta)
            onLaunch: root.launchSelectedGame()
            onBack: root.backToCollections()
        }
    }
}
