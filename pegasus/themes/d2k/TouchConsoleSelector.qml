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
    // so a 189x189 tile centres at x = 400 - 94.5 and y = 205 - 94.5. The tiles
    // are re-centred on their own artwork at build time, so this lands the
    // console in the middle of the ring.
    Image {
        x: 305.5; y: 110.5; width: 189; height: 189
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

    ControlButton {
        x: 175; y: 330; width: 450; height: 150
        source: "assets/control-select-console.png"
        pressedSource: "assets/control-select-console-pressed.png"
        onActivated: panel.open()
    }
}
