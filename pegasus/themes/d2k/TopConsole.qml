import QtQuick 2.0

Item {
    id: panel
    width: 800
    height: 480
    clip: true

    property var theme
    property var collection
    property int gameCount: 0

    // Telemetry has no source yet: the ESP32 controller link is not built.
    // Never render a fabricated reading as if it had been measured.
    property string batteryText: "--"
    property string cpuText: "--"
    property string tempText: "--"

    function hudLine(label, value) {
        return label + ' <font color="' + panel.theme.cyanHex + '">' + value + '</font>'
    }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.topBase
    }

    // Call and response: the D2K logo beats, then the orbital ornament answers.
    // Each beat is a quick "lub-dub" (two small swells, 530 ms); the two are
    // laid out inside one 1600 ms cycle -- logo, rest, ornament, rest -- and run
    // in a single looping animation, so the ornament always answers the logo
    // and the pair can never drift out of order. Scale is about each image's own
    // centre.
    property real pulse: 1   // logo
    property real echo: 1    // ornament

    ParallelAnimation {
        running: true
        loops: Animation.Infinite

        SequentialAnimation {
            NumberAnimation { target: panel; property: "pulse"; to: 1.07; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: panel; property: "pulse"; to: 1.0;  duration: 120; easing.type: Easing.InOutQuad }
            NumberAnimation { target: panel; property: "pulse"; to: 1.05; duration: 100; easing.type: Easing.OutQuad }
            NumberAnimation { target: panel; property: "pulse"; to: 1.0;  duration: 200; easing.type: Easing.InOutQuad }
            PauseAnimation  { duration: 1070 }
        }

        SequentialAnimation {
            PauseAnimation  { duration: 800 }
            NumberAnimation { target: panel; property: "echo"; to: 1.07; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { target: panel; property: "echo"; to: 1.0;  duration: 120; easing.type: Easing.InOutQuad }
            NumberAnimation { target: panel; property: "echo"; to: 1.05; duration: 100; easing.type: Easing.OutQuad }
            NumberAnimation { target: panel; property: "echo"; to: 1.0;  duration: 200; easing.type: Easing.InOutQuad }
            PauseAnimation  { duration: 270 }
        }
    }

    Image {
        x: 0; y: 0; width: 800; height: 480
        source: "assets/background.jpg"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.88
    }

    Image {
        x: 5; y: -40; width: 215; height: 215
        source: "assets/masthead.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        scale: panel.pulse
    }

    Text {
        x: 485; y: 13; width: 275; height: 17
        text: "D2K-01  /  DUAL 800×480  /  PEGASUS"
        color: panel.theme.cyanInk
        font.family: panel.theme.bodyFont
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
    }

    Image {
        x: 258; y: 85; width: 294; height: 294
        source: "assets/console-frame-metal.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // On every console change the art shrinks to nothing, swaps, and grows back
    // (also plays on first appearance, growing in from nothing). `shownArt`
    // trails the live source so the old console is the one that shrinks.
    property url shownArt: ""

    onConsoleArtChanged: artSwap.restart()

    Component.onCompleted: {
        artSwap.restart()
        startTyping()
    }

    readonly property url consoleArt: theme.consoleArtSource(collection)

    SequentialAnimation {
        id: artSwap

        NumberAnimation {
            target: artImage; property: "scale"
            to: 0; duration: 150
            easing.type: Easing.InQuad
        }
        ScriptAction { script: panel.shownArt = panel.consoleArt }
        NumberAnimation {
            target: artImage; property: "scale"
            to: 1; duration: 260
            easing.type: Easing.OutBack
        }
    }

    // Centred on the chrome frame rather than on Figma's slot: the frame's
    // opaque bounds measure their centre at (399.3, 221.8) in panel
    // coordinates, so a 203x203 render sits at 298, 120.
    Image {
        id: artImage
        x: 298; y: 120; width: 203; height: 203
        source: panel.shownArt
        visible: source != ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        scale: 0
    }

    Image {
        x: 141; y: 343; width: 503; height: 168
        source: "assets/glass-button-long.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // Rubik Glitch measures wider in Qt than in Figma, so Figma's 301px box
    // truncates "NINTENDO DS". The title area is the glass button's inner
    // width (461, centred on 404.5) and long console names shrink to fit
    // rather than elide.
    //
    // The name is typed out letter by letter. Qt has no such effect built in,
    // so `typed` counts revealed letters and both title layers show only that
    // many, left-aligned at the x where the finished, centred name would start
    // -- centring the partial text would make it drift as letters arrive.
    // Both layers share one fixed pixel size (measured below) so the size does
    // not jump as the text lengthens either.
    readonly property string consoleName:
        theme.consoleDisplayName(collection).toUpperCase()

    property real typed: 0

    // `to` is set here rather than bound: this runs from the change handler,
    // before a `to: panel.consoleName.length` binding has re-evaluated, so a
    // binding would still hold the previous console's length and every name
    // would stop after as many letters as the one before it had.
    function startTyping() {
        typeIn.stop()
        typed = 0
        typeIn.to = consoleName.length
        typeIn.duration = Math.max(1, consoleName.length) * 70
        typeIn.start()
    }

    onConsoleNameChanged: startTyping()

    // Measures the full name once at 40px to work out the fitted size and width.
    Text {
        id: nameSizer
        visible: false
        text: panel.consoleName
        font.family: panel.theme.consoleFont
        font.pixelSize: 40
        font.letterSpacing: -1
    }

    readonly property real nameSize:
        nameSizer.contentWidth > 461 ? Math.max(22, Math.floor(40 * 461 / nameSizer.contentWidth)) : 40
    readonly property real nameWidth: nameSizer.contentWidth * nameSize / 40
    readonly property real nameX: 174 + (461 - Math.min(461, nameWidth)) / 2

    NumberAnimation {
        id: typeIn
        target: panel
        property: "typed"
        from: 0
        easing.type: Easing.Linear
    }

    // Figma puts a drop shadow under this title. QML cannot blur without
    // QtGraphicalEffects, so the shadow is a second copy of the same text drawn
    // behind and offset, which lifts the gradient off the glass button.
    Text {
        x: panel.nameX; y: 401; height: 57
        text: panel.consoleName.substring(0, Math.floor(panel.typed))
        color: "#000000"
        opacity: 0.45
        font.family: panel.theme.consoleFont
        font.pixelSize: panel.nameSize
        font.letterSpacing: -1
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: panel.nameX; y: 398; height: 57
        text: panel.theme.gradientMarkup(panel.consoleName, Math.floor(panel.typed))
        textFormat: Text.StyledText
        style: Text.Outline
        styleColor: "#40102040"
        color: panel.theme.pearlMist
        font.family: panel.theme.consoleFont
        font.pixelSize: panel.nameSize
        font.letterSpacing: -1
        verticalAlignment: Text.AlignVCenter
    }

    // Figma's "image 1" is the shared chrome frame that overlays the console
    // picture, not per-console art — it is identical across every selector
    // frame in the file.
    Image {
        x: 220; y: 44; width: 359; height: 359
        source: "assets/console-frame-chrome.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        x: 286; y: 300; width: 237; height: 79
        source: "assets/divider-angel.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        x: 0; y: 334; width: 155; height: 155
        source: "assets/metallic-orb.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        x: 0; y: 166; width: 231; height: 173
        source: "assets/hud-frame.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        x: 29; y: 212; width: 208; height: 28
        text: panel.hudLine("BATTERY:", panel.batteryText)
        textFormat: Text.StyledText
        color: panel.theme.hudInk
        font.family: panel.theme.pixelFont
        font.pixelSize: 26
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: 29; y: 242; width: 182; height: 23
        text: panel.hudLine("CPU:", panel.cpuText)
        textFormat: Text.StyledText
        color: panel.theme.hudInk
        font.family: panel.theme.pixelFont
        font.pixelSize: 26
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: 29; y: 265; width: 182; height: 31
        text: panel.hudLine("TEMP:", panel.tempText)
        textFormat: Text.StyledText
        color: panel.theme.hudInk
        font.family: panel.theme.pixelFont
        font.pixelSize: 26
        verticalAlignment: Text.AlignVCenter
    }

    Image {
        x: 574; y: 66; width: 129; height: 97
        source: "assets/games-plate.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    Text {
        x: 571; y: 101; width: 135; height: 25
        text: "GAMES"
        color: panel.theme.hudInk
        font.family: panel.theme.arcadeFont
        font.pixelSize: 20
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Image {
        x: 485; y: 44; width: 105; height: 105
        source: "assets/badge-orbital.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // Figma sizes this box for the single-digit prototype value. Keep its
    // centre on 539 but widen it so real library counts stay inside the badge.
    // Raised 2px from Figma's y 80: the count font's digits sit low in their
    // line box, so the box centre is not the glyph centre.
    Text {
        x: 507; y: 78; width: 64; height: 35
        text: panel.gameCount
        color: panel.theme.countInk
        font.family: panel.theme.countFont
        font.pixelSize: 48
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Image {
        x: 539; y: 110; width: 64; height: 64
        source: "assets/ornament-02.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Item {
        x: 542; y: 197; width: 232.887; height: 232.887

        Image {
            anchors.centerIn: parent
            width: 181.405
            height: 181.405
            rotation: 20.2
            scale: panel.echo
            source: "assets/ornament-04.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // Figma "Metallic 7" (node 297:8) -- the chevron strip that caps the
    // vertical ticket below it. Its own layer is authored pre-rotation and
    // 90deg-rotated in place, but get_design_context's post-rotation bounds
    // (left 708, top 13, 79.663x238.989) are what actually lands on screen,
    // so those are used directly rather than reproducing the rotation.
    //
    // The strip and ticket scroll down together as one banner. The pair spans
    // y 13-445, so scrolling by exactly the panel height (480) and drawing a
    // second copy one panel height above makes the loop seamless: when the
    // first copy has left through the bottom, the second is exactly where the
    // first began. At scroll 0 it is the Figma layout. The panel's own clip cuts
    // the banner at the screen edges.
    Item {
        id: banner
        width: 800; height: 480

        property real scroll: 0

        NumberAnimation on scroll {
            from: 0; to: 480
            duration: 14000
            loops: Animation.Infinite
        }

        Repeater {
            model: 2

            delegate: Item {
                y: banner.scroll - index * 480
                width: 800; height: 480

                Image {
                    x: 708; y: 13; width: 80; height: 239
                    source: "assets/metallic-strip.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Image {
                    x: 711; y: 266; width: 74; height: 179
                    source: "assets/vertical-ticket.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }
        }
    }

    Image {
        x: 141; y: 254; width: 100; height: 100
        source: "assets/chrome-flare.png"
        fillMode: Image.PreserveAspectFit
        opacity: 0.95
        smooth: true
    }
}
