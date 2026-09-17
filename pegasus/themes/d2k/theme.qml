import QtQuick 2.0

FocusScope {
    focus: true

    Rectangle {
        anchors.fill: parent
        color: "#0b1020"
    }

    Column {
        anchors.centerIn: parent
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "D2K"
            color: "#f5f7ff"
            font.pixelSize: 64
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "PEGASUS DEV"
            color: "#93c5fd"
            font.pixelSize: 26
            font.letterSpacing: 2
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "800 × 480"
            color: "#cbd5e1"
            font.pixelSize: 22
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: api.allGames.count ? api.allGames.get(0).title : "No game found"
            color: "#f5f7ff"
            font.pixelSize: 24
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "PRESS ENTER TO LAUNCH"
            color: "#93c5fd"
            font.pixelSize: 18
        }
    }

    Keys.onPressed: {
        if (api.keys.isAccept(event) && api.allGames.count) {
            event.accepted = true
            api.allGames.get(0).launch()
        }
    }
}
