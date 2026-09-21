import QtQuick 2.0

Item {
    id: art

    property var game

    // The upper screen prefers the game's title screen over its box art; the
    // grid tiles keep the box art. Falls back either way when only one exists.
    property bool preferTitle: false

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
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        sourceSize.width: Math.round(art.width * 2)
        sourceSize.height: Math.round(art.height * 2)
    }
}
