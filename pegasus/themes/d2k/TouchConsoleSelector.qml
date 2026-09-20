import QtQuick 2.0

Item {
    id: panel
    width: 800
    height: 480
    clip: true

    property var theme
    property var collection

    signal previous()
    signal next()
    signal open()

    Rectangle {
        anchors.fill: parent
        color: panel.theme.touchBase
    }

    Image {
        x: 0; y: 0; width: 800; height: 480
        source: "assets/background.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    ControlButton {
        x: 10; y: 86; width: 189; height: 242
        source: "assets/control-arrow.png"
        pressedSource: "assets/control-arrow-pressed.png"
        onActivated: panel.previous()
    }

    ControlButton {
        x: 600; y: 86; width: 189; height: 242
        source: "assets/control-arrow.png"
        pressedSource: "assets/control-arrow-pressed.png"
        mirrored: true
        onActivated: panel.next()
    }

    Image {
        x: 240; y: 47; width: 319; height: 319
        source: "assets/console-frame-back.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // Both ring assets measure their centre at (400, 205) in panel coordinates,
    // so a 189x189 tile centres at y = 205 - 94.5. Figma's own frames drift
    // between y 86 and 126 across the selector states.
    Image {
        x: 305; y: 110; width: 189; height: 189
        source: panel.theme.carouselSource(panel.collection)
        visible: source != ""
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        x: 193; y: 0; width: 413; height: 413
        source: "assets/console-frame-front.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // Figma only ever shows short ids here ("DS"), which sit inside the ring's
    // clear centre and below the chrome overlay. DREAMCAST and GAMECUBE are
    // wide enough to reach the ring, so the box is widened (still centred on
    // 400 as in the design) and the label is drawn above the chrome.
    Text {
        x: 190; y: 300; width: 420; height: 24
        text: panel.theme.consoleId(panel.collection).toUpperCase()
        color: panel.theme.limeInk
        font.family: panel.theme.badgeFont
        font.pixelSize: 29
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    ControlButton {
        x: 175; y: 330; width: 450; height: 150
        source: "assets/control-select-console.png"
        pressedSource: "assets/control-select-console-pressed.png"
        onActivated: panel.open()
    }
}
