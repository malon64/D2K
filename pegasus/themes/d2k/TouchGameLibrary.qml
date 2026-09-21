import QtQuick 2.0

Item {
    id: panel
    width: 800
    height: 480
    clip: true

    property var theme
    property var games
    property int gameCount: 0
    property int gameIndex: 0
    property int pageIndex: 0
    property int pageCount: 1
    property bool launching: false

    signal chooseGame(int index)
    signal stepPage(int delta)
    signal launch()
    signal back()

    function pad(value) {
        return value < 10 ? "0" + value : "" + value
    }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.touchBase
    }

    Image {
        x: 0; y: 0; width: 800; height: 480
        source: "assets/background.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    ControlButton {
        x: 9; y: 165; width: 102; height: 150
        source: "assets/control-arrow.png"
        pressedSource: "assets/control-arrow-pressed.png"
        active: panel.pageIndex > 0
        onActivated: panel.stepPage(-1)
    }

    ControlButton {
        x: 684; y: 172; width: 116; height: 150
        source: "assets/control-arrow.png"
        pressedSource: "assets/control-arrow-pressed.png"
        mirrored: true
        active: panel.pageIndex < panel.pageCount - 1
        onActivated: panel.stepPage(1)
    }

    Text {
        x: 654; y: 19; width: 146; height: 41
        text: panel.pad(panel.pageIndex + 1) + " / " + panel.pad(panel.pageCount)
        color: panel.theme.cyanInk
        font.family: panel.theme.bodyBoldFont
        font.pixelSize: 36
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Repeater {
        model: panel.theme.pageSize

        delegate: GameTile {
            readonly property int slot: index
            readonly property int gameSlot: panel.pageIndex * panel.theme.pageSize + slot

            x: 165 + (slot % panel.theme.gridColumns) * 118
            y: 64 + Math.floor(slot / panel.theme.gridColumns) * 110

            theme: panel.theme
            visible: gameSlot < panel.gameCount
            game: visible && panel.games ? panel.games.get(gameSlot) : null
            selected: gameSlot === panel.gameIndex

            onChosen: panel.chooseGame(gameSlot)
        }
    }

    ControlButton {
        x: 299; y: 369; width: 201; height: 138
        source: "assets/control-launch.png"
        pressedSource: "assets/control-launch-pressed.png"
        // Body of the pressed art sits ~6x12 source px up-left of the normal
        // art (402px wide source drawn at 201).
        pressedOffsetX: 3
        pressedOffsetY: 6
        active: panel.gameCount > 0
        held: panel.launching
        onActivated: panel.launch()
    }

    ControlButton {
        x: 12; y: 19; width: 99; height: 90
        source: "assets/control-back.png"
        pressedSource: "assets/control-back-pressed.png"
        onActivated: panel.back()
    }
}
