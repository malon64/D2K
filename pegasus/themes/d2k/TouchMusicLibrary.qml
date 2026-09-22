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

            Text {
                x: 48; y: 25; width: 32; height: 32
                text: (index + 1) < 10 ? "0" + (index + 1) : "" + (index + 1)
                color: parent.isPlaying ? panel.theme.cyanInk : "#91a4d2"
                font.family: panel.theme.titleFont
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            CoverArt {
                x: 92; y: 24; width: 36; height: 36
                game: panel.games ? panel.games.get(index) : null
                fillCrop: true
            }

            Text {
                x: 140; y: 26; width: 280; height: 16
                text: model.title
                color: parent.isPlaying ? "#7ef5ff" : "#dbe7fb"
                font.family: panel.theme.titleFont
                font.pixelSize: 13
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                x: 140; y: 42; width: 280; height: 14
                text: model.developer
                color: parent.isPlaying ? "#9eeaff" : "#a8c0e4"
                font.family: panel.theme.bodyFont
                font.pixelSize: 10
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                x: 430; y: 33; width: 16; height: 16
                visible: parent.isPlaying
                text: panel.paused ? "‖" : "▶"
                color: panel.theme.cyanInk
                font.family: panel.theme.bodyBoldFont
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            // metadata.pegasus.txt carries the track length in summary:,
            // because Pegasus has no duration field of its own.
            Text {
                x: 456; y: 32; width: 116; height: 18
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

    // A fixed-size handle rather than a proportional thumb: the artwork is a
    // drawn capsule with an orb in the middle, and scaling it to the content
    // ratio would squash that to an unreadable sliver.
    Image {
        id: scrollHandle
        width: 28
        height: 116
        x: 699
        y: scrollTrack.y + Math.max(0, Math.min(1, list.visibleArea.yPosition))
               * (scrollTrack.height - height)
        source: "assets/music-scroll-handle.png"
        fillMode: Image.Stretch
        smooth: true
        visible: scrollTrack.visible
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

    // There is no dedicated transport artwork in the theme, so this reuses the
    // square tile frame the game grid already uses and carries the state in the
    // glyph rather than in two more PNGs.
    Item {
        id: transport
        x: 716; y: 14; width: 62; height: 59
        opacity: panel.playingIndex >= 0 ? 1.0 : 0.38

        Image {
            anchors.fill: parent
            source: transportArea.pressed ? "assets/tile-frame-selected.png" : "assets/tile-frame.png"
            fillMode: Image.Stretch
            smooth: true
        }

        Text {
            anchors.fill: parent
            text: panel.paused ? "▶" : "‖"
            color: panel.theme.cyanInk
            font.family: panel.theme.bodyBoldFont
            font.pixelSize: 22
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: transportArea
            anchors.fill: parent
            enabled: panel.playingIndex >= 0
            onClicked: panel.togglePlayback()
        }
    }
}
