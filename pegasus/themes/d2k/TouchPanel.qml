import QtQuick 2.0

Item {
    id: panel
    width: 800
    height: 480

    property var theme
    property string navState: "boot"
    property var collection
    property var games
    property int gameCount: 0
    property int gameIndex: 0
    property int pageIndex: 0
    property int pageCount: 1
    property bool launching: false

    signal previousConsole()
    signal nextConsole()
    signal openConsole()
    signal chooseGame(int index)
    signal stepPage(int delta)
    signal launch()
    signal back()

    Loader {
        anchors.fill: parent
        sourceComponent: panel.navState === "games" ? libraryView
                       : panel.navState === "consoles" ? selectorView
                       : bootView
    }

    Component {
        id: bootView
        BootScreen {
            theme: panel.theme
            touchVariant: true
        }
    }

    Component {
        id: selectorView
        TouchConsoleSelector {
            theme: panel.theme
            collection: panel.collection

            onPrevious: panel.previousConsole()
            onNext: panel.nextConsole()
            onOpen: panel.openConsole()
        }
    }

    Component {
        id: libraryView
        TouchGameLibrary {
            theme: panel.theme
            games: panel.games
            gameCount: panel.gameCount
            gameIndex: panel.gameIndex
            pageIndex: panel.pageIndex
            pageCount: panel.pageCount
            launching: panel.launching

            onChooseGame: panel.chooseGame(index)
            onStepPage: panel.stepPage(delta)
            onLaunch: panel.launch()
            onBack: panel.back()
        }
    }
}
