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

    Timer {
        id: launchGuard
        interval: 240
        onTriggered: {
            touchWindow.visible = false
            root.selectedGame.launch()
        }
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

    Component.onCompleted: {
        if (!hostWindow)
            return

        if (Qt.platform.os === "windows") {
            hostWindow.width = 600
            hostWindow.height = 360
            hostWindow.x = 12
            hostWindow.y = 70
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
        width: 480
        height: 288
        x: 628
        y: 106
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

    Connections {
        target: root.hostWindow
        function onVisibleChanged() {
            if (!root.hostWindow)
                return

            touchWindow.visible = root.hostWindow.visible
            if (root.hostWindow.visible)
                root.launching = false
        }
    }
}
