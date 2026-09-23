import QtQuick 2.0

// Run with qmlscene TopMusicBannerCheck.qml when Qt Quick tools are available.
Item {
    width: 800
    height: 480

    QtObject {
        id: testTheme
        property color topBase: "#000000"
        property color skyGlass: "#91bde2"
        property color pearlMist: "#e0e7f5"
        property color chromeInk: "#6674ac"
        property string bodyBoldFont: "Sans"
        property string titleFont: "Sans"
        property string pixelFont: "Monospace"
    }

    TopMusic {
        id: music
        visible: false // Stops its phase animation so every check is deterministic.
        theme: testTheme
    }

    function close(a, b) {
        return Math.abs(a - b) < 0.001
    }

    function require(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function distance(a, b) {
        var dx = b.x - a.x
        var dy = b.y - a.y
        return Math.sqrt(dx * dx + dy * dy)
    }

    function checkPhase(phase) {
        music.bannerPhase = phase

        for (var stream = 0; stream < music.bannerStreams.length; ++stream) {
            var black = music.bannerSegmentCentre(stream, 2, false)
            var glass = music.bannerSegmentCentre(stream, 2, true)
            var nextBlack = music.bannerSegmentCentre(stream, 3, false)
            var previousBlack = music.bannerSegmentCentre(stream, 1, false)
            var expectedCentreDistance = music.bannerBlackWidth / 2 + music.bannerGap
                                       + music.bannerGlassWidth / 2

            require(close(distance(black, glass), expectedCentreDistance),
                    "black/glass gap changed at phase " + phase)
            require(close(distance(black, nextBlack), music.bannerPeriod),
                    "repeat length changed at phase " + phase)
            require(close(distance(previousBlack, black), music.bannerPeriod),
                    "copies left the shared line at phase " + phase)
            var glassX = glass.x - black.x
            var glassY = glass.y - black.y
            var nextX = nextBlack.x - black.x
            var nextY = nextBlack.y - black.y
            require(close(glassX * nextY - glassY * nextX, 0),
                    "segments diverged from the shared line at phase " + phase)
        }
    }

    Component.onCompleted: {
        var phases = [0, 0.25, 0.5, 0.75]
        for (var i = 0; i < phases.length; ++i)
            checkPhase(phases[i])

        for (var stream = 0; stream < music.bannerStreams.length; ++stream) {
            music.bannerPhase = 0.999999
            var before = music.bannerSegmentCentre(stream, 2, false)
            var direction = music.bannerStreams[stream].direction
            music.bannerPhase = 0
            var after = music.bannerSegmentCentre(stream, 2 + direction, false)
            require(close(before.x, after.x) && close(before.y, after.y),
                    "stream jumped at wrap " + stream)
        }

        console.log("TopMusic banner geometry check passed.")
        Qt.quit()
    }
}
