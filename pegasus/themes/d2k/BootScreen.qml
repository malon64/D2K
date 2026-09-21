import QtQuick 2.0

Item {
    id: boot
    width: 800
    height: 480
    clip: true

    property var theme
    property bool touchVariant: false

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Image {
        visible: !boot.touchVariant
        anchors.centerIn: parent
        width: 430
        height: 430
        source: "assets/masthead.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        visible: boot.touchVariant
        anchors.horizontalCenter: parent.horizontalCenter
        y: 228
        text: "LOADING"
        color: boot.theme.cyanInk
        font.family: boot.theme.pixelFont
        font.pixelSize: 26
        font.letterSpacing: 2
    }
}
