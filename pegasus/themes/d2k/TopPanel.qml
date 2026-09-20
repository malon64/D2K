import QtQuick 2.0

Item {
    id: panel
    width: 800
    height: 480

    property var game
    property int gameNumber: 1
    property color accent
    property color darkAccent

    Rectangle {
        anchors.fill: parent
        color: "#0b1730"
    }

    Rectangle {
        x: 28
        y: 28
        width: 744
        height: 424
        radius: 24
        color: "#101f3d"
        border.width: 2
        border.color: panel.accent
    }

    Text {
        x: 58
        y: 52
        text: "D2K / TOP SCREEN"
        color: panel.accent
        font.pixelSize: 18
        font.bold: true
        font.letterSpacing: 2
    }

    Rectangle {
        x: 58
        y: 104
        width: 282
        height: 282
        radius: 16
        color: panel.darkAccent
        border.width: 3
        border.color: panel.accent

        Rectangle {
            anchors.centerIn: parent
            width: 174
            height: 174
            radius: width / 2
            color: "#0b1730"
            border.width: 2
            border.color: panel.accent
        }

        Text {
            anchors.centerIn: parent
            text: panel.gameNumber
            color: panel.accent
            font.pixelSize: 112
            font.bold: true
        }
    }

    Column {
        x: 382
        y: 128
        width: 342
        spacing: 18

        Text {
            text: "NOW SELECTED"
            color: "#91a7c6"
            font.pixelSize: 16
            font.letterSpacing: 2
        }

        Text {
            width: parent.width
            text: panel.game ? panel.game.title : "No Nintendo DS games found"
            color: "#f7fbff"
            font.pixelSize: 38
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 3
        }

        Text {
            width: parent.width
            text: panel.game ? "Choose it on the touch screen below." : "Add ROM metadata, then reload with F5."
            color: "#bfd0e8"
            font.pixelSize: 20
            wrapMode: Text.WordWrap
        }
    }

    Text {
        x: 58
        y: 406
        text: "800 × 480  •  VISUAL PANEL"
        color: "#91a7c6"
        font.pixelSize: 16
        font.letterSpacing: 1
    }
}
