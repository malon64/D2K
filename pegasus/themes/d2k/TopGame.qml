import QtQuick 2.0

Item {
    id: panel
    width: 800
    height: 480
    clip: true

    property var theme
    property var collection
    property var game

    readonly property string metaLine: {
        var parts = []
        if (game && game.genre)
            parts.push(("" + game.genre).toUpperCase())
        if (game && game.releaseYear > 0)
            parts.push("" + game.releaseYear)
        if (collection)
            parts.push(("" + collection.name).toUpperCase())
        return parts.join("  •  ")
    }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.topBase
    }

    Image {
        x: 0; y: 0; width: 800; height: 480
        source: "assets/background.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    Item {
        x: 84; y: 54; width: 607; height: 367
        clip: true

        Image {
            x: 0
            y: -35.42
            width: 607
            height: 455.30
            source: "assets/hud-frame.png"
            fillMode: Image.Stretch
            smooth: true
        }
    }

    Text {
        x: 318; y: 112; width: 400
        text: panel.game ? ("" + panel.game.title).toUpperCase() : ""
        color: panel.theme.titleInk
        font.family: panel.theme.titleFont
        font.pixelSize: 18
        lineHeight: 22
        lineHeightMode: Text.FixedHeight
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }

    Text {
        x: 318; y: 165; width: 400
        text: panel.metaLine
        color: panel.theme.metaInk
        font.family: panel.theme.bodyFont
        font.pixelSize: 13
        lineHeight: 18
        lineHeightMode: Text.FixedHeight
        elide: Text.ElideRight
    }

    Text {
        x: 318; y: 204; width: 330
        text: panel.game ? panel.game.description : ""
        color: panel.theme.bodyInk
        font.family: panel.theme.bodyFont
        font.pixelSize: 14
        lineHeight: 20
        lineHeightMode: Text.FixedHeight
        wrapMode: Text.WordWrap
        maximumLineCount: 5
        elide: Text.ElideRight
    }

    CoverArt {
        x: 157; y: 121; width: 142; height: 142
        game: panel.game
    }

    Image {
        x: -26; y: 319; width: 220; height: 220
        source: "assets/ornament-05.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        x: 5; y: -5; width: 214; height: 214
        source: "assets/cherub-corner.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        x: 603; y: -26; width: 220; height: 220
        source: "assets/ornament-12.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Image {
        x: 340; y: -17; width: 120; height: 120
        source: "assets/ornament-07.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
