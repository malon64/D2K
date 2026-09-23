import QtQuick 2.0

Item {
    id: boot
    width: 800
    height: 480
    clip: true

    property var theme
    property bool touchVariant: false
    property int loadingDots: 0

    Timer {
        interval: 260
        running: boot.touchVariant
        repeat: true
        onTriggered: boot.loadingDots = (boot.loadingDots + 1) % 4
    }

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
        opacity: 0

        NumberAnimation on opacity {
            from: 0; to: 1
            duration: 1000
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        visible: boot.touchVariant
        anchors.horizontalCenter: parent.horizontalCenter
        y: 228
        text: "LOADING " + [".", "..", "...", "...."][boot.loadingDots]
        color: boot.theme.cyanInk
        font.family: boot.theme.pixelFont
        font.pixelSize: 26
        font.letterSpacing: 2
    }
}
