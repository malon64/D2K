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

    // Both preview windows' remembered position, restored once the game ends.
    // Off-screen coordinates back up the visible:false hide below -- on this
    // desktop preview, Window.visible = false does not reliably take the
    // native window off screen even though the QML property itself does
    // change (confirmed by tracing touchWindow.onVisibleChanged and by
    // screenshot: the property read back false while the window stayed drawn).
    // Moving it off-screen is a second, independent mechanism that cannot
    // have that failure mode, so hiding relies on both rather than trusting
    // either alone. None of this applies on the device, which has no window
    // manager to disagree with.
    property int hostWindowX: 0
    property int hostWindowY: 0
    property int touchWindowX: 0
    property int touchWindowY: 0

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
    }

    // Hides a preview window. Window.visible = false alone is not reliable in
    // the Windows desktop preview: tracing touchWindow.onVisibleChanged
    // confirmed the QML property does flip to false and stays there, yet a
    // screenshot taken moments later still showed the window fully drawn on
    // screen -- a Qt/Windows quirk, not something visible in the QML layer to
    // detect or work around directly. Moving the window off-screen there is a
    // second, independent mechanism that cannot fail the same way. On the
    // device this is skipped: the windows are fullscreen kiosk outputs on a
    // real compositor, where visible = false is the correct mechanism and an
    // off-screen reposition would only risk its own display glitch.
    function hidePreviewWindow(window) {
        window.visible = false
        if (Qt.platform.os === "windows") {
            window.x = -10000
            window.y = -10000
        }
    }

    function restorePreviewWindow(window, x, y) {
        if (Qt.platform.os === "windows") {
            window.x = x
            window.y = y
        }
        window.visible = true
    }

    Timer {
        id: launchGuard
        interval: 240
        onTriggered: {
            root.hidePreviewWindow(touchWindow)
            root.hidePreviewWindow(root.hostWindow)
            root.selectedGame.launch()
        }
    }

    // By design, there is no automatic "game finished" detection. Pegasus does
    // not hide its own window while a launched game runs, does not signal the
    // theme when that external process exits (api.onGameProcessFinished, the
    // signal that looks purpose-built for this, does not fire for a game
    // launched this way -- confirmed: a control signal on the same api
    // object, onMemoryChanged, does fire for our own calls, so the target is
    // valid; the launch-specific signals simply never arrive), and no such
    // detection is wanted even where it might be made to work. Returning to
    // the menu is only ever a deliberate action: the physical Home button
    // (ESP32 controls, not yet built) calling restoreFromGame() directly, or
    // power-cycling the console, which restarts Pegasus with a clean slate
    // and needs no code path here at all.
    //
    // isMenu is bound now, ahead of that hardware, because Pegasus already
    // exposes it as a standard api.keys predicate alongside isAccept/isCancel
    // and a physical Home button is expected to surface as a gamepad "Guide"-
    // style input. Pegasus polls those via SDL at the process level, so
    // unlike a keyboard key they are not gated on hostWindow being the OS
    // foreground window -- which it deliberately is not while hidden.
    function restoreFromGame() {
        restorePreviewWindow(hostWindow, hostWindowX, hostWindowY)
        restorePreviewWindow(touchWindow, touchWindowX, touchWindowY)
        launching = false
    }

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

        hostWindowX = hostWindow.x
        hostWindowY = hostWindow.y
        touchWindowX = touchWindow.x
        touchWindowY = touchWindow.y
    }

    Keys.onPressed: {
        // The physical Home button (planned, not yet built) reaches here as a
        // gamepad "Guide"-style input regardless of navState, since it is the
        // only way back to the menu while a game is running -- see
        // restoreFromGame() above for why nothing else attempts this.
        if (launching && api.keys.isMenu(event)) {
            event.accepted = true
            restoreFromGame()
            return
        }

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
