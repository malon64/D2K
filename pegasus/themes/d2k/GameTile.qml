import QtQuick 2.0

Item {
    id: tile
    width: 108
    height: 108

    property var theme
    property var game
    property bool selected: false

    signal chosen()

    CoverArt {
        x: 10; y: 17; width: 89; height: 76
        game: tile.game
    }

    Image {
        anchors.fill: parent
        source: tile.selected ? "assets/tile-frame-selected.png" : "assets/tile-frame.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        sourceSize.width: 216
        sourceSize.height: 216
    }

    MouseArea {
        anchors.fill: parent
        onClicked: tile.chosen()
    }
}
