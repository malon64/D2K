import QtQuick 2.0

Item {
    id: art

    property var game

    readonly property url coverSource: game && game.assets && game.assets.boxFront
                                       ? game.assets.boxFront : ""

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
