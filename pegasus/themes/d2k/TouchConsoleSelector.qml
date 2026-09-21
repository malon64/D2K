import QtQuick 2.0
import QtGraphicalEffects 1.0

Item {
    id: panel
    width: 800
    height: 480
    clip: true

    property var theme
    property var collection

    // Direction of the last console change: +1 for next, -1 for previous.
    property int consoleStep: 1

    signal previous()
    signal next()
    signal open()

    readonly property url carouselSource: theme.carouselSource(collection)

    // The art that was on screen before the current selection. Assigned only
    // from onCarouselSourceChanged, so it always trails the live source by one
    // step -- reading the old value off the image instead would race the
    // binding that has already replaced it.
    property url departingSource: ""

    onCarouselSourceChanged: {
        if (departingSource != "" && departingSource != carouselSource) {
            departingArt.source = departingSource
            slide.restart()
        }

        departingSource = carouselSource
    }

    Component.onCompleted: departingSource = carouselSource

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
        id: ringBack
        x: 240; y: 47; width: 319; height: 319
        source: "assets/console-frame-back.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    // The console art scrolls sideways through the ring on every selection
    // change. It is drawn into this off-screen item and masked by the back
    // disc below, so art that has not reached the middle yet is cut off at the
    // rim rather than sliding across the rest of the panel -- the ring reads as
    // a window with the carousel running behind it.
    Item {
        id: carousel
        x: ringBack.x; y: ringBack.y
        width: ringBack.width; height: ringBack.height
        visible: false

        // One step moves the art just far enough to clear the rim: half the
        // disc plus half a tile. Travelling further only buys an empty ring in
        // the middle of the slide.
        readonly property real slot: width / 2 + artSize / 2
        readonly property real artSize: 189

        // 1 when a slide starts, 0 once it has settled.
        property real phase: 0

        // Both ring assets measure their centre at (400, 205) in panel
        // coordinates, so a 189x189 tile centres at x = 400 - 94.5 and
        // y = 205 - 94.5, which is (65.5, 63.5) inside this item. The tiles are
        // re-centred on their own artwork at build time, so this lands the
        // console in the middle of the ring.
        // Neither tile carries the `visible: source != ""` guard used elsewhere
        // in the theme. Inside the masked item above, an image that starts out
        // invisible -- which the departing one does, having no source until the
        // first slide -- is never drawn again once the guard turns true. An
        // image with no source draws nothing anyway, so the guard is dropped.
        //
        // Once a slide ends, the departing tile rests a full step off-centre,
        // where the mask hides it.
        Image {
            id: departingArt
            x: 65.5 + carousel.slot * panel.consoleStep * (carousel.phase - 1)
            y: 63.5; width: carousel.artSize; height: carousel.artSize
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Image {
            id: arrivingArt
            x: 65.5 + carousel.slot * panel.consoleStep * carousel.phase
            y: 63.5; width: carousel.artSize; height: carousel.artSize
            source: panel.carouselSource
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        NumberAnimation {
            id: slide
            target: carousel
            property: "phase"
            from: 1; to: 0
            duration: 340
            easing.type: Easing.InOutQuad
        }
    }

    // The disc doubles as the carousel's mask: its own alpha is the exact
    // circle the art may show through, which a rectangular clip cannot give.
    Image {
        id: carouselMask
        x: ringBack.x; y: ringBack.y
        width: ringBack.width; height: ringBack.height
        source: "assets/console-frame-back.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    OpacityMask {
        x: ringBack.x; y: ringBack.y
        width: ringBack.width; height: ringBack.height
        source: carousel
        maskSource: carouselMask
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
