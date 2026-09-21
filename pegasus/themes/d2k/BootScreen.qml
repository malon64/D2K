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
        color: boot.touchVariant ? boot.theme.touchBase : boot.theme.topBase
    }

    Image {
        anchors.fill: parent
        source: "assets/background.jpg"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.88
    }

    Image {
        id: masthead
        visible: !boot.touchVariant
        anchors.centerIn: parent
        width: 430
        height: 430
        source: "assets/masthead.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        Component.onCompleted: {
            if (status === Image.Ready)
                api.memory.set("d2kMusicReady", true)
        }
        onStatusChanged: {
            if (status === Image.Ready)
                api.memory.set("d2kMusicReady", true)
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: boot.touchVariant ? 228 : 392
        text: boot.touchVariant ? "LOADING" : "D2K  /  PEGASUS"
        color: boot.theme.cyanInk
        font.family: boot.touchVariant ? boot.theme.pixelFont : boot.theme.bodyFont
        font.pixelSize: boot.touchVariant ? 26 : 16
        font.letterSpacing: 2
    }
}
