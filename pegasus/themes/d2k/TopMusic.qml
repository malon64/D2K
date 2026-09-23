import QtQuick 2.0

// Upper screen for the music collection. Showcase only -- there is nothing
// interactive here, matching the rest of the menu: every choice lives on the
// touch panel.
Item {
    id: panel
    width: 800
    height: 480
    clip: true

    property var theme
    property var game
    property int trackIndex: -1
    property int trackCount: 0
    property bool paused: false

    // Playback position, fed from MPD's status. Both are milliseconds; -1 means
    // "not known yet", which is the state before the first status arrives.
    property int positionMs: -1
    property int durationMs: -1

    // metadata.pegasus.txt stores the track length in summary: as m:ss. It is
    // the fallback for the total time whenever MPD has not reported one, so the
    // readout is never blank for a track we do have a length for.
    readonly property int summaryMs: {
        if (!game || !game.summary)
            return -1

        var parts = ("" + game.summary).split(":")
        if (parts.length !== 2)
            return -1

        var minutes = parseInt(parts[0], 10)
        var seconds = parseInt(parts[1], 10)
        if (isNaN(minutes) || isNaN(seconds))
            return -1

        return (minutes * 60 + seconds) * 1000
    }

    readonly property int totalMs: durationMs > 0 ? durationMs : summaryMs
    readonly property real elapsedRatio: (positionMs > 0 && totalMs > 0)
                                         ? Math.max(0, Math.min(1, positionMs / totalMs)) : 0

    readonly property real railX: 329
    readonly property real railW: 330

    function clockText(milliseconds) {
        if (milliseconds < 0)
            return "--:--"

        var total = Math.floor(milliseconds / 1000)
        var minutes = Math.floor(total / 60)
        var seconds = total % 60
        return minutes + ":" + (seconds < 10 ? "0" + seconds : "" + seconds)
    }

    // Heartbeat on the three ornaments, one at a time: earbuds, crystal, planet.
    // Same lub-dub as the console screen's logo and ornament (1.07, 1.0, 1.05,
    // 1.0 over 530 ms), and the same 800 ms between beats, so the three take
    // turns in a 2400 ms cycle. One looping sequence drives all three so they
    // can never drift out of order. Scale is about each image's own centre.
    property real beatEarbuds: 1
    property real beatCrystal: 1
    property real beatPlanet: 1

    SequentialAnimation {
        running: true
        loops: Animation.Infinite

        NumberAnimation { target: panel; property: "beatEarbuds"; to: 1.07; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "beatEarbuds"; to: 1.0;  duration: 120; easing.type: Easing.InOutQuad }
        NumberAnimation { target: panel; property: "beatEarbuds"; to: 1.05; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "beatEarbuds"; to: 1.0;  duration: 200; easing.type: Easing.InOutQuad }
        PauseAnimation  { duration: 270 }

        NumberAnimation { target: panel; property: "beatCrystal"; to: 1.07; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "beatCrystal"; to: 1.0;  duration: 120; easing.type: Easing.InOutQuad }
        NumberAnimation { target: panel; property: "beatCrystal"; to: 1.05; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "beatCrystal"; to: 1.0;  duration: 200; easing.type: Easing.InOutQuad }
        PauseAnimation  { duration: 270 }

        NumberAnimation { target: panel; property: "beatPlanet"; to: 1.07; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "beatPlanet"; to: 1.0;  duration: 120; easing.type: Easing.InOutQuad }
        NumberAnimation { target: panel; property: "beatPlanet"; to: 1.05; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: panel; property: "beatPlanet"; to: 1.0;  duration: 200; easing.type: Easing.InOutQuad }
        PauseAnimation  { duration: 270 }
    }

    // Each image is already tilted about 13 degrees. Straighten it first, then
    // rotate and move the complete black/glass chain. That keeps the visible
    // artwork, its gaps, and its movement on the same diagonal.
    readonly property real bannerBlackWidth: 339
    readonly property real bannerBlackHeight: 111
    readonly property real bannerGlassWidth: 349
    readonly property real bannerGlassHeight: 113
    readonly property real bannerBlackCorrection: 12.47
    readonly property real bannerGlassCorrection: 13.02
    readonly property real bannerBlackAxisX: 169.28
    readonly property real bannerBlackAxisY: 56.51
    readonly property real bannerGlassAxisX: 173.93
    readonly property real bannerGlassAxisY: 58.97
    readonly property real bannerGap: 15
    readonly property real bannerGlassCenter: bannerBlackWidth / 2 + bannerGap
                                             + bannerGlassWidth / 2
    readonly property real bannerPeriod: bannerBlackWidth + bannerGlassWidth
                                         + 2 * bannerGap
    readonly property int bannerDuration: Math.round(bannerPeriod * 14000 / 480)
    property real bannerPhase: 0
    readonly property var bannerStreams: [
        { "anchorX": 373.11, "anchorY": 44.06, "rotation": 23.65, "direction": 1 },
        { "anchorX": 3.74, "anchorY": 269.00, "rotation": -37.42, "direction": -1 }
    ]

    function bannerCopyX(copyIndex, direction) {
        return (copyIndex - 2 + direction * bannerPhase) * bannerPeriod
    }

    // Kept here so the regression harness checks the same positions used by
    // the delegates below.
    function bannerSegmentCentre(streamIndex, copyIndex, glass) {
        var stream = bannerStreams[streamIndex]
        var localX = bannerCopyX(copyIndex, stream.direction)
                   + (glass ? bannerGlassCenter : 0)
        var radians = stream.rotation * Math.PI / 180
        return {
            "x": stream.anchorX + localX * Math.cos(radians),
            "y": stream.anchorY + localX * Math.sin(radians)
        }
    }

    NumberAnimation on bannerPhase {
        from: 0; to: 1
        duration: panel.bannerDuration
        loops: Animation.Infinite
        running: panel.visible
        easing.type: Easing.Linear
    }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.topBase
    }

    Image {
        x: 0; y: 0; width: 800; height: 480
        source: "assets/background.jpg"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.88
    }

    Rectangle {
        anchors.fill: parent
        color: "#06122c"
        opacity: 0.28
    }

    // Ornaments are the unrotated source artwork, placed at the node's own box
    // with any Figma rotation reapplied here. Where a node is rotated, the box
    // is centred on its bounding box so the two agree.
    //
    // This one sits under the card; the rest are drawn over everything, at the
    // end of the file, matching the Figma layer order.
    Image {
        x: 49; y: 44; width: 73; height: 73
        source: "assets/chrome-flare.png"
        fillMode: Image.Stretch
        smooth: true
    }

    // Drawn before the card, so it shows through the card's square window. The
    // window is cut out of the artwork itself (x 105..551, y 112..528 of the
    // 1623x673 image) and this runs ~2px under the border on every side, so
    // the frame's edge is always what closes the picture off.
    CoverArt {
        x: 111; y: 158; width: 185; height: 173
        game: panel.game
        fillCrop: true
    }

    // The card artwork is cropped to its opaque content, so it stretches
    // straight into place without a clipping wrapper.
    Image {
        x: 70; y: 114; width: 660; height: 274
        source: "assets/music-nowplaying.png"
        fillMode: Image.Stretch
        smooth: true
    }

    Text {
        x: 344; y: 142; width: 316; height: 16
        text: panel.game ? (panel.paused ? "PAUSED" : "NOW PLAYING") : "NOTHING PLAYING"
        color: "#7ef5ff"
        font.family: panel.theme.pixelFont
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: 344; y: 170; width: 316; height: 33
        text: panel.game ? panel.game.title : "—"
        color: "#f8fbff"
        font.family: panel.theme.titleFont
        font.pixelSize: 24
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: 344; y: 207; width: 316; height: 24
        text: panel.game ? panel.game.developer : ""
        color: "#d3e4ff"
        font.family: panel.theme.bodyBoldFont
        font.pixelSize: 14
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: 344; y: 234; width: 316; height: 18
        text: "MP3  •  320 KBPS  •  LOCAL STORAGE"
        color: panel.theme.skyGlass
        font.family: panel.theme.pixelFont
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
    }

    // |------.-------|  the rail the card artwork leaves room for.
    Rectangle {
        x: panel.railX; y: 284; width: panel.railW; height: 7
        radius: 3.5
        color: panel.theme.chromeInk
        opacity: 0.55
    }

    Rectangle {
        x: panel.railX; y: 284
        width: panel.railW * panel.elapsedRatio
        height: 7
        radius: 3.5
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#298cc8" }
            GradientStop { position: 1.0; color: "#7ef5ff" }
        }
    }

    Rectangle {
        x: panel.railX + panel.railW * panel.elapsedRatio - 3.5
        y: 278; width: 7; height: 19
        radius: 3.5
        color: "#bffcff"
        visible: panel.positionMs >= 0
    }

    Rectangle {
        x: panel.railX - 6; y: 278; width: 3; height: 19
        radius: 1.5
        color: panel.theme.pearlMist
        opacity: 0.8
    }

    Rectangle {
        x: panel.railX + panel.railW + 3; y: 278; width: 3; height: 19
        radius: 1.5
        color: panel.theme.pearlMist
        opacity: 0.8
    }

    Text {
        x: 331; y: 296; width: 90; height: 18
        text: panel.clockText(panel.positionMs)
        color: "#e3efff"
        font.family: panel.theme.bodyBoldFont
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: 567; y: 296; width: 90; height: 18
        text: panel.clockText(panel.totalMs)
        color: "#e3efff"
        font.family: panel.theme.bodyBoldFont
        font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: 28; y: 447; width: 744; height: 18
        text: "D2K AUDIO CORE // LOCAL-FIRST // PLAYBACK BY MPD"
        color: "#bceaff"
        font.family: panel.theme.pixelFont
        font.pixelSize: 10
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Foreground ornaments. In Figma these sit above every other layer on the
    // frame, including the footer, and the banners deliberately run off the
    // edges -- the panel clips them.
    // Rotated -0.87 deg in Figma; box centred on its 226.2px bounding box.
    Image {
        x: 565.7; y: 2.7; width: 222.8; height: 222.8
        source: "assets/music-orn-earbuds.png"
        fillMode: Image.Stretch
        smooth: true
        rotation: -0.87
        scale: panel.beatEarbuds
    }

    // Rotated -12.83 deg. Same artwork the game screen uses, so it reuses
    // ornament-05 rather than shipping a second copy of it.
    Image {
        x: 566.7; y: 299.7; width: 220; height: 220
        source: "assets/ornament-05.png"
        fillMode: Image.Stretch
        smooth: true
        rotation: -12.83
        opacity: 0.92
        scale: panel.beatPlanet
    }

    Image {
        x: 11; y: 3; width: 222; height: 222
        source: "assets/music-orn-butterfly.png"
        fillMode: Image.Stretch
        smooth: true
    }

    Image {
        x: -6; y: 361; width: 120; height: 119
        source: "assets/music-orn-crystal.png"
        fillMode: Image.Stretch
        smooth: true
        scale: panel.beatCrystal
    }

    // The anchor of copy 2 is the Figma centre of its black segment. Five copies
    // cover both sides of the screen while opposite streams wrap in opposite
    // directions.
    Repeater {
        model: panel.bannerStreams

        delegate: Item {
            id: strip
            property var stream: modelData
            x: stream.anchorX
            y: stream.anchorY
            width: 1
            height: 1
            transformOrigin: Item.TopLeft
            rotation: stream.rotation

            Repeater {
                model: 5

                delegate: Item {
                    property real copyX: panel.bannerCopyX(index, strip.stream.direction)

                    Image {
                        x: parent.copyX - panel.bannerBlackAxisX
                        y: -panel.bannerBlackAxisY
                        width: panel.bannerBlackWidth
                        height: panel.bannerBlackHeight
                        source: "assets/music-banner-black.png"
                        transformOrigin: Item.Center
                        rotation: panel.bannerBlackCorrection
                        smooth: true
                    }

                    Image {
                        x: parent.copyX + panel.bannerGlassCenter - panel.bannerGlassAxisX
                        y: -panel.bannerGlassAxisY
                        width: panel.bannerGlassWidth
                        height: panel.bannerGlassHeight
                        source: "assets/music-banner-glass.png"
                        transformOrigin: Item.Center
                        rotation: panel.bannerGlassCorrection
                        smooth: true
                    }
                }
            }
        }
    }
}
