import QtQuick 2.0

Item {
    id: control

    property url source
    property url pressedSource
    property bool mirrored: false
    property bool active: true
    property bool held: false

    signal activated()

    opacity: active ? 1.0 : 0.38

    Image {
        anchors.fill: parent
        source: (touchArea.pressed || control.held) && control.pressedSource != ""
                ? control.pressedSource : control.source
        fillMode: Image.PreserveAspectFit
        mirror: control.mirrored
        smooth: true
        sourceSize.width: Math.round(control.width * 2)
        sourceSize.height: Math.round(control.height * 2)
    }

    MouseArea {
        id: touchArea
        anchors.fill: parent
        enabled: control.active
        onClicked: control.activated()
    }
}
