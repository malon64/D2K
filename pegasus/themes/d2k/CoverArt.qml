import QtQuick 2.0

Item {
    id: art

    property var game

    // The upper screen prefers the game's title screen over its box art; the
    // grid tiles keep the box art. Falls back either way when only one exists.
    property bool preferTitle: false

    // Fill the whole box, cropping the overflowing edges evenly, instead of
    // letterboxing. Used by the grid tiles so covers reach the frame.
    property bool fillCrop: false

    readonly property url coverSource: {
        if (!game || !game.assets)
            return ""

        if (preferTitle && game.assets.logo)
            return game.assets.logo

        return game.assets.boxFront ? game.assets.boxFront : ""
    }

    Image {
        anchors.fill: parent
        source: art.coverSource
        fillMode: art.fillCrop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        clip: art.fillCrop
        asynchronous: true
        smooth: true
        sourceSize.width: Math.round(art.width * (art.fillCrop ? 4 : 2))
        sourceSize.height: art.fillCrop ? 0 : Math.round(art.height * 2)
    }
}
