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
    property var playingTrack
    property int playingIndex: -1
    property bool paused: false
    property int positionMs: -1
    property int durationMs: -1

    Loader {
        anchors.fill: parent
        sourceComponent: panel.navState === "music" ? musicView
                       : panel.navState === "games" ? gameView
                       : panel.navState === "consoles" ? consoleView
                       : bootView
    }

    Component {
        id: musicView
        TopMusic {
            theme: panel.theme
            game: panel.playingTrack
            paused: panel.paused
            positionMs: panel.positionMs
            durationMs: panel.durationMs
        }
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
