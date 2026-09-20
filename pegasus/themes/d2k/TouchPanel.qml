import QtQuick 2.0

Item {
    id: panel
    width: 800
    height: 480

    property var games
    property int selectedIndex: 0
    property color accent
    property color darkAccent
    signal choose(int index)
    signal play()

    Rectangle {
        anchors.fill: parent
        color: "#07111f"
    }

    Text {
        x: 40
        y: 34
        text: "D2K / TOUCH SELECT"
        color: panel.accent
        font.pixelSize: 24
        font.bold: true
        font.letterSpacing: 2
    }

    Text {
        x: 40
        y: 72
        text: "800 × 480 LOGICAL • 4-INCH PANEL PREVIEW"
        color: "#91a7c6"
        font.pixelSize: 15
        font.letterSpacing: 1
    }

    Column {
        x: 40
        y: 118
        width: 720
        spacing: 13

        Repeater {
            model: panel.games

            delegate: Rectangle {
                property var game: modelData
                width: 720
                height: 62
                radius: 10
                color: index === panel.selectedIndex ? panel.darkAccent : "#11233f"
                border.width: index === panel.selectedIndex ? 3 : 1
                border.color: index === panel.selectedIndex ? panel.accent : "#2d4261"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: game.title
                    color: "#f7fbff"
                    font.pixelSize: 22
                    font.bold: index === panel.selectedIndex
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: panel.choose(index)
                }
            }
        }
    }

    Rectangle {
        x: 520
        y: 388
        width: 240
        height: 58
        radius: 12
        color: panel.accent

        Text {
            anchors.centerIn: parent
            text: "PLAY"
            color: "#07111f"
            font.pixelSize: 24
            font.bold: true
            font.letterSpacing: 2
        }

        MouseArea {
            anchors.fill: parent
            enabled: panel.games && panel.games.count > 0
            onClicked: panel.play()
        }
    }
}
