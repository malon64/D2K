import QtQuick 2.0

Item {
    id: theme
    visible: false

    readonly property color iceBlue: "#298cc8"
    readonly property color skyGlass: "#91bde2"
    readonly property color pearlMist: "#e0e7f5"
    readonly property color candyPink: "#dabfdb"
    readonly property color pinkGlass: "#f1dcf1"
    readonly property color deepBlue: "#1d5da7"
    readonly property color chromeInk: "#6674ac"

    readonly property color cyanInk: "#00edff"
    readonly property string cyanHex: "#00edff"
    readonly property color limeInk: "#29ef54"
    readonly property color titleInk: "#f5faff"
    readonly property color metaInk: "#d1e5ff"
    readonly property color bodyInk: "#ebf2ff"
    readonly property color hudInk: "#f5fcff"
    readonly property color countInk: "#2002ff"
    readonly property color topBase: "#dde0ed"
    readonly property color touchBase: "#e0e7f5"

    readonly property int panelRadius: 24
    readonly property int pageSize: 12
    readonly property int gridColumns: 4

    readonly property var consoleOrder: ["ds", "dreamcast", "ps1", "n64", "gamecube", "3ds", "music"]

    readonly property var consoleAliases: ({
        "nds": "ds",
        "n3ds": "3ds",
        "psx": "ps1",
        "ngc": "gamecube",
        "dc": "dreamcast"
    })

    readonly property var carouselArtwork: ["ds", "3ds", "ps1", "n64", "music"]
    readonly property var consoleArtwork: ["ds"]
    readonly property var consoleRenders: ["ds"]

    readonly property string bodyFont: fontChakraMedium.status === FontLoader.Ready ? fontChakraMedium.name : "Sans"
    readonly property string bodyBoldFont: fontChakraBold.status === FontLoader.Ready ? fontChakraBold.name : "Sans"
    readonly property string hudFont: fontChakraSemiBold.status === FontLoader.Ready ? fontChakraSemiBold.name : "Sans"
    readonly property string titleFont: fontOrbitron.status === FontLoader.Ready ? fontOrbitron.name : "Sans"
    readonly property string pixelFont: fontPixelify.status === FontLoader.Ready ? fontPixelify.name : "Monospace"
    readonly property string arcadeFont: fontPressStart.status === FontLoader.Ready ? fontPressStart.name : "Monospace"
    readonly property string consoleFont: fontRubikGlitch.status === FontLoader.Ready ? fontRubikGlitch.name : "Sans"
    readonly property string badgeFont: fontBungeeShade.status === FontLoader.Ready ? fontBungeeShade.name : "Sans"
    readonly property string countFont: fontDanfo.status === FontLoader.Ready ? fontDanfo.name : "Sans"

    function consoleId(collection) {
        if (!collection || !collection.shortName)
            return ""

        var shortName = ("" + collection.shortName).toLowerCase()
        return consoleAliases[shortName] !== undefined ? consoleAliases[shortName] : shortName
    }

    function consoleAsset(collection, suffix, available) {
        var id = consoleId(collection)
        if (!id || available.indexOf(id) < 0)
            return ""

        return "assets/consoles/" + id + "-" + suffix + ".png"
    }

    function carouselSource(collection) { return consoleAsset(collection, "carousel", carouselArtwork) }
    function consoleArtSource(collection) { return consoleAsset(collection, "art", consoleArtwork) }
    function consoleRenderSource(collection) { return consoleAsset(collection, "render", consoleRenders) }

    FontLoader { id: fontChakraMedium; source: "assets/fonts/ChakraPetch-Medium.ttf" }
    FontLoader { id: fontChakraSemiBold; source: "assets/fonts/ChakraPetch-SemiBold.ttf" }
    FontLoader { id: fontChakraBold; source: "assets/fonts/ChakraPetch-Bold.ttf" }
    FontLoader { id: fontOrbitron; source: "assets/fonts/Orbitron-ExtraBold.ttf" }
    FontLoader { id: fontPixelify; source: "assets/fonts/PixelifySans-SemiBold.ttf" }
    FontLoader { id: fontPressStart; source: "assets/fonts/PressStart2P-Regular.ttf" }
    FontLoader { id: fontRubikGlitch; source: "assets/fonts/RubikGlitch-Regular.ttf" }
    FontLoader { id: fontBungeeShade; source: "assets/fonts/BungeeShade-Regular.ttf" }
    FontLoader { id: fontDanfo; source: "assets/fonts/Danfo-Regular.ttf" }
}
