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

    readonly property var consoleOrder: ["ds", "dreamcast", "psp", "ps1", "n64", "gamecube", "3ds", "music"]

    readonly property var consoleAliases: ({
        "nds": "ds",
        "n3ds": "3ds",
        "psx": "ps1",
        "gc": "gamecube",
        "ngc": "gamecube",
        "dc": "dreamcast"
    })

    // Which consoles have artwork in the Figma file. Listing them avoids asking
    // Qt to load images that do not exist, which would log a warning per frame.
    readonly property var carouselArtwork: ["ds", "dreamcast", "psp", "ps1", "n64", "gamecube", "3ds", "music"]
    readonly property var consoleArtwork: ["ds", "dreamcast", "psp", "ps1", "n64", "gamecube", "3ds", "music"]

    // Vertical nudge for carousel art, in the 189px art space. The renders are
    // not all balanced the same way: music's alpha box is centred, but its
    // trailing earbud drags the visible mass 5px low, so it reads as sitting
    // below the middle of the ring without this.
    readonly property var carouselOffsets: ({ "music": -5 })

    // Keyed off the art URL rather than the collection, because the carousel
    // also has to nudge the departing tile and only keeps its source.
    function carouselOffsetFor(source) {
        var text = "" + source
        for (var id in carouselOffsets) {
            if (text.indexOf("/" + id + "-carousel.png") >= 0)
                return carouselOffsets[id]
        }
        return 0
    }

    // Shorter names for the upper screen, where the full collection name runs
    // past the glass button. Anything not listed keeps its collection name.
    readonly property var consoleDisplayNames: ({
        "dreamcast": "Dreamcast",
        "gamecube": "Gamecube",
        "ps1": "Playstation 1"
    })

    readonly property string bodyFont: fontChakraMedium.status === FontLoader.Ready ? fontChakraMedium.name : "Sans"
    readonly property string bodyBoldFont: fontChakraBold.status === FontLoader.Ready ? fontChakraBold.name : "Sans"
    readonly property string hudFont: fontChakraSemiBold.status === FontLoader.Ready ? fontChakraSemiBold.name : "Sans"
    readonly property string titleFont: fontOrbitron.status === FontLoader.Ready ? fontOrbitron.name : "Sans"
    readonly property string pixelFont: fontPixelify.status === FontLoader.Ready ? fontPixelify.name : "Monospace"
    readonly property string arcadeFont: fontPressStart.status === FontLoader.Ready ? fontPressStart.name : "Monospace"
    readonly property string consoleFont: fontRubikGlitch.status === FontLoader.Ready ? fontRubikGlitch.name : "Sans"
    readonly property string badgeFont: fontBungeeShade.status === FontLoader.Ready ? fontBungeeShade.name : "Sans"
    readonly property string countFont: fontDanfo.status === FontLoader.Ready ? fontDanfo.name : "Sans"

    // Figma fills the console name with a left-to-right rainbow. QML Text
    // cannot gradient-fill a string, but the Figma render steps the colour per
    // letter, so StyledText markup reproduces it faithfully without a shader
    // and without pulling QtGraphicalEffects into the ARM64 build. Stops were
    // sampled from an export of the Figma text node.
    readonly property var nameGradient: [
        [0.00, 0xfd, 0xe7, 0x9e],
        [0.33, 0x9e, 0x97, 0xf8],
        [0.55, 0x82, 0x7a, 0xfe],
        [0.78, 0xc0, 0x5f, 0xd0],
        [1.00, 0xfe, 0x06, 0x9c]
    ]

    function hexByte(value) {
        var text = Math.max(0, Math.min(255, Math.round(value))).toString(16)
        return text.length < 2 ? "0" + text : text
    }

    function gradientHex(position) {
        var stops = nameGradient
        var last = stops.length - 1

        if (position <= stops[0][0])
            return "#" + hexByte(stops[0][1]) + hexByte(stops[0][2]) + hexByte(stops[0][3])

        for (var i = 1; i <= last; i++) {
            if (position > stops[i][0])
                continue

            var from = stops[i - 1]
            var to = stops[i]
            var span = to[0] - from[0]
            var k = span > 0 ? (position - from[0]) / span : 0
            return "#" + hexByte(from[1] + (to[1] - from[1]) * k)
                       + hexByte(from[2] + (to[2] - from[2]) * k)
                       + hexByte(from[3] + (to[3] - from[3]) * k)
        }

        return "#" + hexByte(stops[last][1]) + hexByte(stops[last][2]) + hexByte(stops[last][3])
    }

    // `visibleCount` reveals only the first N letters (all when omitted) while
    // each letter keeps the colour it has in the complete string, so a typewriter
    // reveal does not shift the gradient as it grows.
    function gradientMarkup(value, visibleCount) {
        var text = "" + (value === undefined || value === null ? "" : value)
        if (!text.length)
            return ""

        var shown = visibleCount === undefined ? text.length : Math.min(text.length, visibleCount)
        var markup = ""
        for (var i = 0; i < shown; i++) {
            var character = text.charAt(i)
            var glyph = character === "&" ? "&amp;"
                      : character === "<" ? "&lt;"
                      : character === ">" ? "&gt;"
                      : character === " " ? "&nbsp;"
                      : character
            var position = text.length > 1 ? i / (text.length - 1) : 0
            markup += '<font color="' + gradientHex(position) + '">' + glyph + '</font>'
        }
        return markup
    }

    function consoleId(collection) {
        if (!collection || !collection.shortName)
            return ""

        var shortName = ("" + collection.shortName).toLowerCase()
        return consoleAliases[shortName] !== undefined ? consoleAliases[shortName] : shortName
    }

    function consoleDisplayName(collection) {
        if (!collection)
            return ""

        var id = consoleId(collection)
        return consoleDisplayNames[id] !== undefined
               ? consoleDisplayNames[id] : ("" + collection.name)
    }

    function consoleAsset(collection, suffix, available) {
        var id = consoleId(collection)
        if (!id || available.indexOf(id) < 0)
            return ""

        var filename = id + "-" + suffix + ".png"
        if (id === "psp" && suffix === "carousel")
            filename = "psp-pixel.png"
        return "assets/consoles/" + filename
    }

    function carouselSource(collection) { return consoleAsset(collection, "carousel", carouselArtwork) }
    function consoleArtSource(collection) { return consoleAsset(collection, "art", consoleArtwork) }

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
