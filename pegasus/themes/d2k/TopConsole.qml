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

    // Centred on the chrome frame rather than on Figma's slot: the frame's
    // opaque bounds measure their centre at (399.3, 221.8) in panel
    // coordinates, so a 203x203 render sits at 298, 120.
    Image {
        x: 298; y: 120; width: 203; height: 203
        source: panel.theme.consoleArtSource(panel.collection)
        visible: source != ""
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        x: 141; y: 343; width: 503; height: 168
        source: "assets/glass-button-long.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // Rubik Glitch measures wider in Qt than in Figma, so Figma's 301px box
    // truncates "NINTENDO DS". The box is widened to the glass button's inner
    // width, still centred on 404.5, and long console names shrink to fit
    // rather than elide.
    //
    // Figma puts a drop shadow under this title. QML cannot blur without
    // QtGraphicalEffects, so the shadow is a second copy of the same text drawn
    // behind and offset, which lifts the gradient off the glass button.
    Text {
        x: 174; y: 401; width: 461; height: 57
        text: panel.theme.consoleDisplayName(panel.collection).toUpperCase()
        color: "#000000"
        opacity: 0.45
        font.family: panel.theme.consoleFont
        font.pixelSize: 40
        font.letterSpacing: -1
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 22
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        x: 174; y: 398; width: 461; height: 57
        text: panel.theme.gradientMarkup(
                  panel.theme.consoleDisplayName(panel.collection).toUpperCase())
        textFormat: Text.StyledText
        style: Text.Outline
        styleColor: "#40102040"
        color: panel.theme.pearlMist
        font.family: panel.theme.consoleFont
        font.pixelSize: 40
        font.letterSpacing: -1
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 22
        horizontalAlignment: Text.AlignHCenter
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
    Text {
        x: 507; y: 80; width: 64; height: 35
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
            source: "assets/ornament-04.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    Image {
        x: 711; y: 266; width: 74; height: 179
        source: "assets/vertical-ticket.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        x: 141; y: 254; width: 100; height: 100
        source: "assets/chrome-flare.png"
        fillMode: Image.PreserveAspectFit
        opacity: 0.95
        smooth: true
    }
}
