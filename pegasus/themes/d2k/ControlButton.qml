import QtQuick 2.0

Item {
    id: control

    property url source
    property url pressedSource
    property bool mirrored: false
    property bool active: true
    property bool held: false

    // Nudge applied to the pressed artwork so its body lines up with the
    // normal artwork (the two PNGs are not authored on the same centre).
    property real pressedOffsetX: 0
    property real pressedOffsetY: 0
    readonly property bool showPressed: (touchArea.pressed || held) && pressedSource != ""

    signal activated()

    opacity: active ? 1.0 : 0.38

    Image {
        id: art
        width: parent.width
        height: parent.height
        x: control.showPressed ? control.pressedOffsetX : 0
        y: control.showPressed ? control.pressedOffsetY : 0
        source: control.showPressed ? control.pressedSource : control.source
        fillMode: Image.PreserveAspectFit
        mirror: control.mirrored
        smooth: true
        sourceSize.width: Math.round(control.width * 2)
        sourceSize.height: Math.round(control.height * 2)
    }

    // Blink fast while the control is held (the Launch button stays held for
    // the whole launch effect).
    SequentialAnimation {
        running: control.held
        loops: Animation.Infinite

        NumberAnimation { target: art; property: "opacity"; to: 0.3; duration: 90 }
        NumberAnimation { target: art; property: "opacity"; to: 1.0; duration: 90 }

        onRunningChanged: if (!running) art.opacity = 1
    }

    MouseArea {
        id: touchArea
        anchors.fill: parent
        enabled: control.active
        onClicked: control.activated()
    }
}
