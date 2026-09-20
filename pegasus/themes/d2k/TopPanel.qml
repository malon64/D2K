import QtQuick 2.0

Item {
    id: panel
    width: 800
    height: 480

    property var theme
    property string navState: "boot"
    property var collection
    property var game
    property int gameCount: 0

    Loader {
        anchors.fill: parent
        sourceComponent: panel.navState === "games" ? gameView
                       : panel.navState === "consoles" ? consoleView
                       : bootView
    }

    Component {
        id: bootView
        BootScreen {
            theme: panel.theme
        }
    }

    Component {
        id: consoleView
        TopConsole {
            theme: panel.theme
            collection: panel.collection
            gameCount: panel.gameCount
        }
    }

    Component {
        id: gameView
        TopGame {
            theme: panel.theme
            collection: panel.collection
            game: panel.game
        }
    }
}
