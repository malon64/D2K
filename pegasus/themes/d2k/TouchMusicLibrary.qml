import QtQuick 2.0

// Lower screen for the music collection: a scrolling track list framed by two
// registered layers of the same artwork. The rows sit between them, so they
// pass under the frame chrome as the list scrolls -- which is the whole reason
// the frame is split in two.
//
// Unlike the game grid there is no focus state here: tapping a row plays it
// outright, so the only highlighted row is the one MPD is playing.
Item {
    id: panel
    width: 800
    height: 480
    clip: true

    property var theme
    property var games
    property int trackCount: 0
    property int playingIndex: -1
    property bool paused: false

    signal playTrack(int index)
    signal togglePlayback()
    signal back()

    // Both frame layers are the same 1448x1086 canvas and are drawn at the same
    // rect, which is what keeps them registered. The rect places the artwork's
    // opaque content at 14,78 780x400 on the panel.
    readonly property real frameX: 2.47
    readonly property real frameY: 64.44
    readonly property real frameW: 795.06
    readonly property real frameH: 433.10

    // Travel available to the scrollbar handle, and to the list behind it.
    readonly property real scrollSpan: scrollTrack.height - scrollHandle.height
    readonly property real scrollMax: Math.max(0, list.contentHeight - list.height)

    function scrollToFraction(fraction) {
        list.contentY = Math.max(0, Math.min(1, fraction)) * panel.scrollMax
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

    Rectangle {
        anchors.fill: parent
        color: "#07112c"
        opacity: 0.36
    }

    Image {
        x: panel.frameX; y: panel.frameY; width: panel.frameW; height: panel.frameH
        source: "assets/music-list-back.png"
        fillMode: Image.Stretch
        smooth: true
    }

    ListView {
        id: list
        x: 64; y: 111; width: 620; height: 332
        clip: true
        spacing: 4
        model: panel.games
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 240

        delegate: Item {
            width: 620
            height: 80

            readonly property bool isPlaying: index === panel.playingIndex

            Image {
                anchors.fill: parent
                source: parent.isPlaying ? "assets/music-row-selected.png" : "assets/music-row.png"
                fillMode: Image.Stretch
                smooth: true
            }

            // Sits just inside the selected panel's hollow window, whose left
            // edge is at 0.0621 of the row width (38.5px here).
            Text {
                x: 40; y: 25; width: 30; height: 32
                text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1)
                color: parent.isPlaying ? panel.theme.cyanInk : "#91a4d2"
                font.family: panel.theme.titleFont
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                x: 84; y: 26; width: 370; height: 16
                text: model.title
                color: parent.isPlaying ? "#7ef5ff" : "#dbe7fb"
                font.family: panel.theme.titleFont
                font.pixelSize: 13
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                x: 84; y: 42; width: 370; height: 14
                text: model.developer
                color: parent.isPlaying ? "#9eeaff" : "#a8c0e4"
                font.family: panel.theme.bodyFont
                font.pixelSize: 10
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            // Playing marker. The pause bars are drawn rather than set from a
            // glyph: at this size the two strokes of U+2016 sit almost on top
            // of each other, which reads as a smudge instead of a pause icon.
            Item {
                x: 510; y: 33; width: 16; height: 16
                visible: parent.isPlaying

                Text {
                    anchors.fill: parent
                    visible: !panel.paused
                    text: "▶"
                    color: panel.theme.cyanInk
                    font.family: panel.theme.bodyBoldFont
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Row {
                    anchors.centerIn: parent
                    visible: panel.paused
                    spacing: 4

                    Rectangle { width: 3; height: 12; radius: 1; color: panel.theme.cyanInk }
                    Rectangle { width: 3; height: 12; radius: 1; color: panel.theme.cyanInk }
                }
            }

            // metadata.pegasus.txt carries the track length in summary:,
            // because Pegasus has no duration field of its own.
            Text {
                x: 480; y: 32; width: 92; height: 18
                text: model.summary
                color: parent.isPlaying ? "#d8ecff" : panel.theme.skyGlass
                font.family: panel.theme.hudFont
                font.pixelSize: 13
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: panel.playTrack(index)
            }
        }
    }

    Image {
        x: panel.frameX; y: panel.frameY; width: panel.frameW; height: panel.frameH
        source: "assets/music-list-front.png"
        fillMode: Image.Stretch
        smooth: true
    }

    Image {
        id: scrollTrack
        x: 703; y: 114; width: 20; height: 326
        source: "assets/music-scroll-track.png"
        fillMode: Image.Stretch
        smooth: true
        visible: list.contentHeight > list.height
    }

    // Tapping the rail jumps the list to that point, the way a desktop
    // scrollbar does. Wider than the 20px rail so it is reachable with a
    // finger, and declared before the handle so the handle wins the press.
    MouseArea {
        id: railArea
        x: 694; y: 110; width: 38; height: 334
        enabled: scrollTrack.visible
        onClicked: {
            if (panel.scrollSpan <= 0)
                return

            panel.scrollToFraction((railArea.y + mouse.y - scrollTrack.y - scrollHandle.height / 2)
                                   / panel.scrollSpan)
        }
    }

    // A fixed-size handle rather than a proportional thumb: the artwork is a
    // drawn capsule with an orb in the middle, and scaling it to the content
    // ratio would squash that to an unreadable sliver.
    Image {
        id: scrollHandle
        x: 699
        width: 28
        height: 116
        source: "assets/music-scroll-handle.png"
        fillMode: Image.Stretch
        smooth: true
        visible: scrollTrack.visible

        scale: handleArea.pressed ? 1.07 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        MouseArea {
            id: handleArea
            anchors.fill: parent
            anchors.margins: -8
            drag.target: scrollHandle
            drag.axis: Drag.YAxis
            drag.threshold: 0
            drag.minimumY: scrollTrack.y
            drag.maximumY: scrollTrack.y + panel.scrollSpan

            onPositionChanged: {
                if (!drag.active || panel.scrollSpan <= 0)
                    return

                panel.scrollToFraction((scrollHandle.y - scrollTrack.y) / panel.scrollSpan)
            }
        }
    }

    // The handle tracks the list, except while it is being dragged -- then the
    // drag owns its position and this binding would fight it.
    Binding {
        target: scrollHandle
        property: "y"
        when: !handleArea.drag.active
        value: scrollTrack.y + Math.max(0, Math.min(1, list.visibleArea.yPosition)) * panel.scrollSpan
    }

    ControlButton {
        x: 14; y: 10; width: 76; height: 69
        source: "assets/control-back.png"
        pressedSource: "assets/control-back-pressed.png"
        onActivated: panel.back()
    }

    Text {
        x: 98; y: 11; width: 230; height: 38
        text: "MUSIC"
        color: panel.theme.titleInk
        font.family: panel.theme.titleFont
        font.pixelSize: 26
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: 99; y: 48; width: 330; height: 18
        text: panel.trackCount + " TRACKS  •  SWIPE ↑↓  •  TAP A TRACK TO PLAY IT"
        color: "#7eebff"
        font.family: panel.theme.pixelFont
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
    }

    // The button shows the action it performs, not the current state: pause
    // while a track is playing, play once it is paused.
    //
    // Both artworks are stacked and cross-faded rather than swapped, so the
    // change reads as a transition. It starts on the tap, off the theme's own
    // optimistic state -- MPD fades its volume over ~600ms before it reports
    // the new state, and waiting for that would make the button feel dead.
    // Mirrors the back button: same box, same margins, opposite edge
    // (800 - 14 - 76). Sitting any larger or higher ran it into the list frame.
    Item {
        id: transport
        x: 710; y: 10; width: 76; height: 69

        opacity: panel.playingIndex >= 0 ? 1.0 : 0.38
        Behavior on opacity { NumberAnimation { duration: 140 } }

        scale: transportArea.pressed ? 0.93 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        Image {
            anchors.fill: parent
            source: transportArea.pressed ? "assets/control-music-pause-pressed.png"
                                          : "assets/control-music-pause.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: panel.paused ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.InOutQuad } }
        }

        Image {
            anchors.fill: parent
            source: transportArea.pressed ? "assets/control-music-play-pressed.png"
                                          : "assets/control-music-play.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: panel.paused ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.InOutQuad } }
        }

        MouseArea {
            id: transportArea
            anchors.fill: parent
            enabled: panel.playingIndex >= 0
            onClicked: panel.togglePlayback()
        }
    }
}
