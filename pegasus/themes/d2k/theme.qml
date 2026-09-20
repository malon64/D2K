import QtQuick 2.0
import QtQuick.Window 2.15

FocusScope {
    id: topScreen
    focus: true

    property int selectedIndex: 0
    property var selectedGame: api.allGames.count > selectedIndex
                               ? api.allGames.get(selectedIndex) : null
    property var accents: ["#35c8ff", "#ff9d3d", "#c77dff"]
    property var darkAccents: ["#174f78", "#783d17", "#48256e"]
    property color accent: accents[selectedIndex % accents.length]
    property color darkAccent: darkAccents[selectedIndex % darkAccents.length]
    property var hostWindow: Window.window

    function selectGame(index) {
        if (!api.allGames.count)
            return

        selectedIndex = (index + api.allGames.count) % api.allGames.count
        api.memory.set("d2kSelectedGame", selectedIndex)
    }

    function launchSelectedGame() {
        if (!selectedGame)
            return

        api.memory.set("d2kSelectedGame", selectedIndex)
        bottomScreen.visible = false
        selectedGame.launch()
    }

    Component.onCompleted: {
        var savedIndex = api.memory.get("d2kSelectedGame")
        if (typeof savedIndex === "number" && savedIndex >= 0 && savedIndex < api.allGames.count)
            selectedIndex = savedIndex

        if (hostWindow) {
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
                bottomScreen.screen = lower
                bottomScreen.x = lower.virtualX
                bottomScreen.y = lower.virtualY
                bottomScreen.width = lower.width
                bottomScreen.height = lower.height
            }
        }
    }

    Keys.onPressed: {
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
            event.accepted = true
            selectGame(selectedIndex - 1)
        }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
            event.accepted = true
            selectGame(selectedIndex + 1)
        }
        else if (api.keys.isAccept(event)) {
            event.accepted = true
            launchSelectedGame()
        }
    }

    TopPanel {
        scale: topScreen.width / 800
        transformOrigin: Item.TopLeft
        game: topScreen.selectedGame
        gameNumber: topScreen.selectedIndex + 1
        accent: topScreen.accent
        darkAccent: topScreen.darkAccent
    }

    Window {
        id: bottomScreen
        title: "D2K Touch"
        width: 480
        height: 288
        x: 628
        y: 106
        visible: true
        transientParent: null
        color: "#07111f"

        TouchPanel {
            scale: bottomScreen.width / 800
            transformOrigin: Item.TopLeft
            games: api.allGames
            selectedIndex: topScreen.selectedIndex
            accent: topScreen.accent
            darkAccent: topScreen.darkAccent
            onChoose: topScreen.selectGame(index)
            onPlay: topScreen.launchSelectedGame()
        }
    }

    Connections {
        target: topScreen.hostWindow
        function onVisibleChanged() {
            if (topScreen.hostWindow)
                bottomScreen.visible = topScreen.hostWindow.visible
        }
    }
}
