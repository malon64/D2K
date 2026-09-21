import QtQuick 2.0

Item {
    id: tile
    width: 108
    height: 108

    property var theme
    property var game
    property bool selected: false

    signal chosen()

    // Fills the frame's transparent window (x 21.5-98, y 24-86.5 at 108px;
    // the selected frame's is slightly smaller). Drawn under the frame, so a
    // small overscan hides any seam against the frame border.
    CoverArt {
        x: 20; y: 23; width: 80; height: 65
        game: tile.game
        fillCrop: true
    }

    Image {
        anchors.fill: parent
        source: "assets/tile-frame.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        sourceSize.width: 216
        sourceSize.height: 216
    }

    // The selected frame pulses over the normal one. It never fades out
    // entirely: the art direction requires the focus to stay readable without
    // depending on animation, so the selected artwork is always at least
    // partly on screen.
    Image {
        id: selectedFrame
        anchors.fill: parent
        source: "assets/tile-frame-selected.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        sourceSize.width: 216
        sourceSize.height: 216
        visible: tile.selected
        opacity: 1

        onVisibleChanged: if (!visible) opacity = 1

        SequentialAnimation {
            running: tile.selected
            loops: Animation.Infinite

            NumberAnimation {
                target: selectedFrame
                property: "opacity"
                to: 0.3
                duration: 260
                easing.type: Easing.InOutQuad
            }

            NumberAnimation {
                target: selectedFrame
                property: "opacity"
                to: 1.0
                duration: 260
                easing.type: Easing.InOutQuad
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: tile.chosen()
    }
}
