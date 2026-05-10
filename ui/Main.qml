pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtMultimedia
import Qt5Compat.GraphicalEffects
import "HelpCatalog.js" as HelpCatalog

ApplicationWindow {
    id: win
    width: 1200
    height: 720
    visible: true
    title: "ENIGMA TOUCH"

    property bool isFullscreen: false
    property string page: "boot" // disclaimer -> soundtrack -> boot -> intro -> home -> machine -> story
    property int bootMs: 10000
    property int bootHoldMs: 2000
    property int bootPause48Ms: 1000
    property int bootPause60Ms: 3000
    property int bootPause98Ms: 1000
    property int bootTravelMs: Math.max(500, win.bootMs - win.bootHoldMs - win.bootPause48Ms - win.bootPause60Ms - win.bootPause98Ms)
    property real bootProgress: 0.0
    property bool pageTransitionsReady: false
    property bool disruptionEnabled: true
    property bool disruptionOccurred: false
    property bool disruptionActive: false
    property bool disruptionBlackPhase: false
    property int disruptionDisplayMs: 18000
    property string disruptionTitle: ""
    property string disruptionText: ""
    property bool disruptionResumeStoryAudio: false
    property bool disruptionResumeStoryVideo: false
    property real emergencyMusicFactor: 1.0

    property color accent: "#c58d4d"
    property color bgTint: "#1a120c"
    property color glassFill: "#2a1f18"
    property color glassStroke: "#5a4738"
    property color textMain: "#f3efe9"
    property color textSub: "#d8cabc"
    property int fsTitle: 40
    property int fsSection: 30
    property int fsLabel: 14
    property real bodyLine: 1.28

    property var galleryAssetUrls: []
    property var simController: null
    property var gpioBridge: null
    property url sfondoAssetUrl: ""
    property url audioAssetUrl: ""
    property url storyVideoAssetUrl: ""
    property string storyAssetText: ""
    property string initialPage: "boot"
    property bool startFullscreen: false
    property string soundtrackMode: "classic" // classic | war
    property real bgMusicVolume: 0.50
    property bool bgMusicEnabled: true
    property real bgStartupFade: 0.0
    property bool bgMusicFadePending: false
    property real storyDuckingFactor: 0.20
    property bool storyAudioPlaying: false
    property real uiBrightness: 1.0
    property real uiBrightnessBoost: Math.max(0.0, (win.uiBrightness - 0.75) / 0.25)
    property url sottofondoAssetUrl: Qt.resolvedUrl("assets/sottofondo.mp3")
    property url sottofondoSpariAssetUrl: Qt.resolvedUrl("assets/sottofondospari.mp3")
    property url bgMusicSourceUrl: soundtrackMode === "war" ? sottofondoSpariAssetUrl : sottofondoAssetUrl
    property bool galleryExpanded: false
    property url galleryExpandedSource: ""
    property int gpioSelectedRotor: 0

    function disruptionSecretWord() {
        if (!win.disruptionTitle || win.disruptionTitle.length === 0) {
            return ""
        }
        var parts = win.disruptionTitle.split(" ")
        return parts.length > 0 ? parts[0] : win.disruptionTitle
    }

    function disruptionTitleRest() {
        var first = win.disruptionSecretWord()
        if (!first || win.disruptionTitle.length <= first.length) {
            return ""
        }
        return win.disruptionTitle.substring(first.length + 1)
    }

    function centerWindow() {
        try {
            var sx = Screen.width
            var sy = Screen.height
            win.x = Math.max(0, (sx - win.width) / 2)
            win.y = Math.max(0, (sy - win.height) / 2)
        } catch (e) {}
    }

    function formatAudioTime(ms) {
        if (!isFinite(ms) || ms <= 0) {
            return "00:00"
        }
        var total = Math.floor(ms / 1000)
        var minutes = Math.floor(total / 60)
        var seconds = total % 60
        return minutes + ":" + (seconds < 10 ? "0" + seconds : seconds)
    }

    function syncStoryVideo(force) {
        if (!(win.storyVideoAssetUrl && win.storyVideoAssetUrl.toString().length > 0)) {
            return
        }
        if (story.videoPriming || storyPlayer.playbackState !== MediaPlayer.PlayingState) {
            return
        }

        var target = storyPlayer.position
        var drift = Math.abs(storyVideoPlayer.position - target)
        var tolerance = force ? 120 : story.syncToleranceMs

        if (storyVideoPlayer.playbackState !== MediaPlayer.PlayingState) {
            storyVideoPlayer.position = target
            storyVideoPlayer.play()
            return
        }

        if (drift > tolerance) {
            storyVideoPlayer.position = target
        }
    }

    function gpioToggleStoryPlayback() {
        if (win.page !== "story") {
            return
        }
        if (storyPlayer.playbackState === MediaPlayer.PlayingState) {
            storyPlayer.pause()
            if (win.storyVideoAssetUrl && win.storyVideoAssetUrl.toString().length > 0) {
                storyVideoPlayer.pause()
            }
        } else {
            storyPlayer.play()
            if (win.storyVideoAssetUrl && win.storyVideoAssetUrl.toString().length > 0) {
                storyVideoPlayer.position = storyPlayer.position
                storyVideoPlayer.play()
            }
        }
    }

    function stopStoryPlayback() {
        win.storyAudioPlaying = false
        storyPlayer.stop()
        storyVideoPlayer.stop()
    }

    function gpioEncoderPress() {
        if (win.page === "machine") {
            win.gpioSelectedRotor = (win.gpioSelectedRotor + 1) % 3
            return
        }
        if (win.page === "story") {
            win.gpioToggleStoryPlayback()
            return
        }
        win.gpioPrimaryAction()
    }

    function gpioPrimaryAction() {
        if (win.page === "disclaimer") {
            win.page = "soundtrack"
            return
        }
        if (win.page === "soundtrack") {
            win.beginWithSoundtrack("classic")
            return
        }
        if (win.page === "intro") {
            win.page = "home"
            return
        }
        if (win.page === "home") {
            win.page = "machine"
            return
        }
        if (win.page === "machine") {
            if (win.simController) {
                win.simController.resetMachine()
            }
            return
        }
        if (win.page === "story") {
            win.gpioToggleStoryPlayback()
        }
    }

    function gpioSecondaryAction() {
        if (win.page === "disclaimer") {
            win.page = "soundtrack"
            return
        }
        if (win.page === "soundtrack") {
            win.beginWithSoundtrack("war")
            return
        }
        if (win.page === "intro") {
            win.page = "home"
            return
        }
        if (win.page === "home") {
            win.page = "story"
            return
        }
        if (win.page === "machine") {
            win.page = "home"
            return
        }
        if (win.page === "story") {
            win.storyAudioPlaying = false
            storyPlayer.stop()
            storyVideoPlayer.stop()
            win.page = "home"
        }
    }

    function bootStatusText() {
        if (bootProgress < 0.20) {
            return "Inizializzazione interfaccia..."
        }
        if (bootProgress < 0.45) {
            return "Caricamento risorse grafiche..."
        }
        if (bootProgress < 0.70) {
            return "Sincronizzazione moduli Enigma..."
        }
        if (bootProgress < 0.92) {
            return "Ottimizzazione esperienza..."
        }
        return "Pronto."
    }

    function randomInt(minValue, maxValue) {
        return Math.floor(Math.random() * (maxValue - minValue + 1)) + minValue
    }

    function pickOne(values) {
        if (!values || values.length === 0) {
            return ""
        }
        return values[randomInt(0, values.length - 1)]
    }

    function pickDistinct(values, count) {
        var pool = []
        for (var i = 0; i < values.length; i++) {
            pool.push(values[i])
        }
        var result = []
        while (pool.length > 0 && result.length < count) {
            var idx = randomInt(0, pool.length - 1)
            result.push(pool[idx])
            pool.splice(idx, 1)
        }
        return result
    }

    function formatList(values) {
        if (!values || values.length === 0) {
            return ""
        }
        if (values.length === 1) {
            return values[0]
        }
        if (values.length === 2) {
            return values[0] + " e " + values[1]
        }
        var head = values.slice(0, values.length - 1).join(", ")
        return head + " e " + values[values.length - 1]
    }

    function isDisruptionEligiblePage() {
        return win.page === "intro" || win.page === "home" || win.page === "machine" || win.page === "story"
    }

    function scheduleDisruption(initialWindow) {
        if (!win.disruptionEnabled || win.disruptionOccurred || win.disruptionActive || disruptionTriggerTimer.running) {
            return
        }
        var minDelay = initialWindow ? 55000 : 25000
        var maxDelay = initialWindow ? 90000 : 60000
        disruptionTriggerTimer.interval = win.randomInt(minDelay, maxDelay)
        disruptionTriggerTimer.restart()
    }

    function buildDisruptionMessage() {
        var localita = win.pickDistinct([
            "Wolverton",
            "Stony Stratford",
            "Fenny Stratford",
            "Woburn Sands",
            "Newport Pagnell",
            "Buckingham",
            "Leighton Buzzard",
            "Bicester"
        ], win.randomInt(3, 4))
        var attore = win.pickOne([
            "Luftwaffe tedesca",
            "forze dell'Asse",
            "squadriglie tedesche d'attacco"
        ])
        var azione = win.pickOne([
            "azioni offensive coordinate",
            "una nuova ondata di incursioni",
            "un attacco mirato alle infrastrutture"
        ])
        var velivolo = win.pickOne([
            "Heinkel He 111",
            "Junkers Ju 88",
            "Dornier Do 17",
            "Messerschmitt Bf 110"
        ])
        var ordigno = win.pickOne(["V-1", "V-2"])

        win.disruptionDisplayMs = win.randomInt(14000, 26000)
        win.disruptionTitle = "ALLERTA OPERATIVA: BLACKOUT TEMPORANEO"
        win.disruptionText =
            "Rapporto da Bletchley Park: detonazioni segnalate nell'area di "
            + win.formatList(localita)
            + ".\n\nIntelligence: "
            + attore
            + " in "
            + azione
            + ", possibile impiego di "
            + velivolo
            + " e ordigni "
            + ordigno
            + ".\n\nInterruzione di corrente confermata. I generatori di emergenza entreranno in funzione tra pochi istanti."
    }

    function triggerDisruption() {
        if (!win.disruptionEnabled || win.disruptionOccurred || win.disruptionActive) {
            return
        }
        if (!win.isDisruptionEligiblePage()) {
            win.scheduleDisruption(false)
            return
        }

        win.buildDisruptionMessage()
        win.disruptionOccurred = true
        win.disruptionActive = true
        win.disruptionBlackPhase = true

        win.disruptionResumeStoryAudio = storyPlayer.playbackState === MediaPlayer.PlayingState
        win.disruptionResumeStoryVideo = storyVideoPlayer.playbackState === MediaPlayer.PlayingState
        if (win.disruptionResumeStoryAudio) {
            storyPlayer.pause()
        }
        if (win.disruptionResumeStoryVideo) {
            storyVideoPlayer.pause()
        }
        win.storyAudioPlaying = false

        disruptionMusicFadeDown.stop()
        disruptionMusicFadeDown.from = win.emergencyMusicFactor
        disruptionMusicFadeDown.to = 0.0
        disruptionMusicFadeDown.start()
        disruptionBlackTimer.restart()
    }

    function finishDisruption() {
        win.disruptionActive = false
        win.disruptionBlackPhase = false

        disruptionMusicFadeUp.stop()
        disruptionMusicFadeUp.from = win.emergencyMusicFactor
        disruptionMusicFadeUp.to = 1.0
        disruptionMusicFadeUp.start()

        if (win.page === "story" && win.disruptionResumeStoryAudio) {
            storyPlayer.play()
            if (win.disruptionResumeStoryVideo) {
                storyVideoPlayer.play()
            }
        }
        win.disruptionResumeStoryAudio = false
        win.disruptionResumeStoryVideo = false
    }

    function dismissDisruptionQuick() {
        if (!win.disruptionActive) {
            return
        }
        disruptionBlackTimer.stop()
        disruptionMessageTimer.stop()
        win.finishDisruption()
    }

    function setSoundtrack(mode, restartPlayback) {
        var m = mode
        if (m !== "classic" && m !== "war") {
            m = "classic"
        }
        win.soundtrackMode = m
        if (restartPlayback && win.bgMusicEnabled) {
            win.restartBackgroundMusic(false)
        }
    }

    function restartBackgroundMusic(withFadeIn) {
        bgMusicFadeIn.stop()
        win.bgMusicFadePending = withFadeIn
        win.bgStartupFade = withFadeIn ? 0.0 : 1.0
        bgMusicPlayer.stop()
        bgMusicPlayer.play()
    }

    function beginWithSoundtrack(mode) {
        win.setSoundtrack(mode, false)
        win.bgMusicEnabled = true
        win.restartBackgroundMusic(true)
        win.page = "boot"
    }

    function startBootSequence() {
        win.bootProgress = 0.0
        bootProgressAnim.stop()
        bootProgressAnim.start()
    }

    onPageChanged: {
        if (win.pageTransitionsReady) {
            pageFadeAnim.restart()
        } else {
            win.pageTransitionsReady = true
        }

        if (win.page === "boot") {
            win.startBootSequence()
        } else {
            bootProgressAnim.stop()
        }
    }

    Component.onCompleted: {
        if (startFullscreen === true) {
            win.isFullscreen = true
            win.visibility = Window.FullScreen
        } else {
            win.centerWindow()
        }
        win.page = "disclaimer"
        win.scheduleDisruption(true)
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: win.disruptionActive
        context: Qt.ApplicationShortcut
        onActivated: win.dismissDisruptionQuick()
    }

    Connections {
        target: win.gpioBridge
        ignoreUnknownSignals: true

        function onRotate(delta) {
            if (win.page === "machine" && win.simController) {
                win.simController.rotateRotor(win.gpioSelectedRotor, delta)
            }
        }
    }

    NumberAnimation {
        id: bgMusicFadeIn
        target: win
        property: "bgStartupFade"
        from: 0.0
        to: 1.0
        duration: 4000
        easing.type: Easing.InOutCubic
    }

    AudioOutput {
        id: bgMusicOut
        volume: Math.max(
                    0.0,
                    Math.min(
                        1.0,
                        (win.bgMusicEnabled ? win.bgMusicVolume : 0.0)
                        * win.bgStartupFade
                        * (win.storyAudioPlaying ? win.storyDuckingFactor : 1.0)
                        * win.emergencyMusicFactor
                    )
                )
    }

    MediaPlayer {
        id: bgMusicPlayer
        source: win.bgMusicSourceUrl
        audioOutput: bgMusicOut
        loops: MediaPlayer.Infinite
    }

    Connections {
        target: bgMusicPlayer

        function onPlaybackStateChanged() {
            if (win.bgMusicFadePending && bgMusicPlayer.playbackState === MediaPlayer.PlayingState) {
                win.bgMusicFadePending = false
                bgMusicFadeIn.restart()
            }
        }
    }

    SequentialAnimation {
        id: pageFadeAnim
        running: false
        NumberAnimation {
            target: pageFadeLayer
            property: "opacity"
            from: 0.0
            to: 0.55
            duration: 140
            easing.type: Easing.OutCubic
        }
        PauseAnimation { duration: 40 }
        NumberAnimation {
            target: pageFadeLayer
            property: "opacity"
            from: 0.55
            to: 0.0
            duration: 260
            easing.type: Easing.InOutCubic
        }
    }

    NumberAnimation {
        id: disruptionMusicFadeDown
        target: win
        property: "emergencyMusicFactor"
        duration: 700
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: disruptionMusicFadeUp
        target: win
        property: "emergencyMusicFactor"
        duration: 900
        easing.type: Easing.InOutCubic
    }

    Timer {
        id: disruptionTriggerTimer
        interval: 70000
        repeat: false
        running: false
        onTriggered: win.triggerDisruption()
    }

    Timer {
        id: disruptionBlackTimer
        interval: 2000
        repeat: false
        running: false
        onTriggered: {
            if (!win.disruptionActive) {
                return
            }
            win.disruptionBlackPhase = false
            disruptionMessageTimer.interval = win.disruptionDisplayMs
            disruptionMessageTimer.restart()
        }
    }

    Timer {
        id: disruptionMessageTimer
        interval: 7000
        repeat: false
        running: false
        onTriggered: win.finishDisruption()
    }

    component GlassCard : Rectangle {
        radius: 26
        color: Qt.rgba(win.glassFill.r, win.glassFill.g, win.glassFill.b, 0.55)
        border.color: Qt.rgba(win.glassStroke.r, win.glassStroke.g, win.glassStroke.b, 0.65)
        border.width: 1
        antialiasing: true
    }

    component RoundedImagePanel : Rectangle {
        id: imagePanel
        property alias source: image.source
        property string emptyLabel: "Immagine non disponibile"
        radius: 22
        color: Qt.rgba(0.14, 0.11, 0.09, 0.88)
        border.width: 1
        border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.26)
        antialiasing: true

        Item {
            id: imageClip
            anchors.fill: parent
            anchors.margins: 1
            layer.enabled: true
            layer.smooth: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: imageClip.width
                    height: imageClip.height
                    radius: imagePanel.radius - 1
                    color: "black"
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.08, 0.06, 0.05, 0.94)
            }

            Image {
                id: image
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.05, 0.04, 0.03, 0.22)
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 30
                visible: image.status !== Image.Ready
                text: imagePanel.emptyLabel
                color: win.textSub
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    component GlassButton : Item {
        id: b
        property bool primary: false
        property int h: 50
        property int w: 220
        property int textSize: 16
        property alias text: label.text
        signal clicked
        width: w
        height: h

        Rectangle {
            anchors.fill: parent
            radius: 18
            border.width: 1
            border.color: Qt.rgba(win.glassStroke.r, win.glassStroke.g, win.glassStroke.b, 0.85)
            antialiasing: true
            color: b.primary
                   ? (mouse.pressed ? Qt.darker(win.accent, 1.25)
                      : (mouse.containsMouse ? Qt.lighter(win.accent, 1.08) : win.accent))
                   : (mouse.pressed ? Qt.rgba(0.20, 0.16, 0.13, 0.78)
                      : (mouse.containsMouse ? Qt.rgba(0.22, 0.18, 0.15, 0.72) : Qt.rgba(0.18, 0.14, 0.12, 0.62)))
        }

        Text {
            id: label
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: win.textMain
            font.pixelSize: b.textSize
            font.bold: true
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }

    component InfoChip : Item {
        id: chip
        signal clicked
        property int size: 22
        width: size
        height: size

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            antialiasing: true
            border.width: 1
            border.color: m.containsMouse
                          ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.55)
                          : Qt.rgba(1.0, 1.0, 1.0, 0.20)
            color: m.pressed
                   ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.26)
                   : (m.containsMouse ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.20)
                                      : Qt.rgba(1.0, 1.0, 1.0, 0.10))
        }

        Text {
            anchors.centerIn: parent
            text: "i"
            color: win.textMain
            font.pixelSize: 13
            font.bold: true
            renderType: Text.NativeRendering
        }

        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component GlassTextField : TextField {
        id: tf
        color: win.textMain
        selectionColor: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.45)
        selectedTextColor: win.textMain
        placeholderTextColor: Qt.rgba(win.textSub.r, win.textSub.g, win.textSub.b, 0.82)
        font.pixelSize: 14

        background: Rectangle {
            radius: 12
            antialiasing: true
            color: tf.enabled
                   ? (tf.hovered ? Qt.rgba(0.14, 0.11, 0.09, 0.24) : Qt.rgba(0.13, 0.10, 0.08, 0.20))
                   : Qt.rgba(0.10, 0.08, 0.07, 0.16)
            border.width: 1
            border.color: tf.activeFocus
                          ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.45)
                          : Qt.rgba(1.0, 1.0, 1.0, 0.13)

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: 14
                color: "transparent"
                border.width: tf.activeFocus ? 1 : 0
                border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22)
            }
        }
    }

    component GlassComboBox : ComboBox {
        id: cb
        font.pixelSize: 14
        implicitHeight: 40
        leftPadding: 12
        rightPadding: 34
        topPadding: 8
        bottomPadding: 8

        function itemLabel(value) {
            if (value === undefined || value === null) {
                return ""
            }
            if (typeof value === "object") {
                if (cb.textRole && value[cb.textRole] !== undefined) {
                    return value[cb.textRole]
                }
                if (value.label !== undefined) {
                    return value.label
                }
                if (value.text !== undefined) {
                    return value.text
                }
            }
            return String(value)
        }

        delegate: ItemDelegate {
            id: comboDelegate
            required property int index
            required property var modelData
            width: cb.width
            text: cb.itemLabel(modelData)
            highlighted: cb.highlightedIndex === comboDelegate.index
            height: 38
            contentItem: Text {
                text: comboDelegate.text
                color: win.textMain
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                color: comboDelegate.highlighted ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22) : Qt.rgba(0.11, 0.09, 0.08, 0.92)
                radius: 10
            }
        }

        indicator: Canvas {
            x: cb.width - width - cb.rightPadding
            y: cb.topPadding + (cb.availableHeight - height) / 2
            width: 12
            height: 8
            contextType: "2d"
            onPaint: {
                context.reset()
                context.moveTo(0, 0)
                context.lineTo(width, 0)
                context.lineTo(width / 2, height)
                context.closePath()
                context.fillStyle = Qt.rgba(win.textSub.r, win.textSub.g, win.textSub.b, 0.90)
                context.fill()
            }
        }

        contentItem: Text {
            leftPadding: 10
            rightPadding: cb.indicator.width + cb.spacing
            text: cb.displayText
            font.pixelSize: 14
            color: win.textMain
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 12
            antialiasing: true
            color: cb.hovered ? Qt.rgba(0.14, 0.11, 0.09, 0.24) : Qt.rgba(0.13, 0.10, 0.08, 0.20)
            border.width: 1
            border.color: cb.visualFocus
                          ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.45)
                          : Qt.rgba(1.0, 1.0, 1.0, 0.13)

            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: 14
                color: "transparent"
                border.width: cb.visualFocus ? 1 : 0
                border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22)
            }
        }

        popup: Popup {
            parent: Overlay.overlay
            x: cb.mapToItem(Overlay.overlay, 0, 0).x
            y: cb.mapToItem(Overlay.overlay, 0, cb.height + 6).y
            width: cb.width
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
            padding: 4
            contentItem: ListView {
                id: comboList
                clip: true
                implicitHeight: contentHeight
                model: cb.delegateModel
                currentIndex: cb.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds
            }
            background: Rectangle {
                radius: 12
                color: Qt.rgba(0.09, 0.08, 0.07, 0.94)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
            }
        }
    }

    component ThemeScrollBar : ScrollBar {
        id: bar
        policy: ScrollBar.AsNeeded
        interactive: true
        implicitWidth: 10
        implicitHeight: 10
        padding: 2

        contentItem: Rectangle {
            implicitWidth: 7
            implicitHeight: 7
            radius: 4
            color: bar.pressed
                   ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.92)
                   : Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.58)
        }

        background: Rectangle {
            radius: 5
            color: Qt.rgba(0.0, 0.0, 0.0, 0.20)
            border.width: 1
            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.06)
        }
    }

    component GlassSlider : Slider {
        id: gs
        implicitHeight: 32

        background: Rectangle {
            x: gs.leftPadding
            y: gs.topPadding + gs.availableHeight / 2 - height / 2
            width: gs.availableWidth
            height: 8
            radius: 4
            color: Qt.rgba(1.0, 1.0, 1.0, 0.12)

            Rectangle {
                width: gs.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.90)
            }
        }

        handle: Rectangle {
            x: gs.leftPadding + gs.visualPosition * (gs.availableWidth - width)
            y: gs.topPadding + gs.availableHeight / 2 - height / 2
            implicitWidth: 18
            implicitHeight: 18
            radius: 9
            color: gs.pressed ? Qt.darker(win.accent, 1.12) : Qt.lighter(win.accent, 1.04)
            border.width: 1
            border.color: Qt.rgba(0.0, 0.0, 0.0, 0.35)
        }
    }

    Image {
        anchors.fill: parent
        source: (win.sfondoAssetUrl && win.sfondoAssetUrl.toString().length > 0) ? win.sfondoAssetUrl : ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(win.bgTint.r, win.bgTint.g, win.bgTint.b, 0.25 - (win.uiBrightnessBoost * 0.13))
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Math.max(0.0, (1.0 - win.uiBrightness) * 0.70)
    }

    Rectangle {
        anchors.fill: parent
        color: "white"
        opacity: win.uiBrightnessBoost * 0.18
    }

    Column {
        id: topBtns
        spacing: 10
        z: 250
        visible: win.page !== "disclaimer" && win.page !== "soundtrack"
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.topMargin: 14

        GlassButton {
            w: 170
            h: 40
            text: win.isFullscreen ? "WINDOW" : "FULLSCREEN"
            onClicked: {
                win.isFullscreen = !win.isFullscreen
                win.visibility = win.isFullscreen ? Window.FullScreen : Window.Windowed
                if (!win.isFullscreen) {
                    win.centerWindow()
                }
            }
        }

        GlassButton {
            w: 170
            h: 40
            text: "CREDITS"
            onClicked: creditsPopup.open()
        }

        GlassButton {
            w: 170
            h: 40
            text: "SETTINGS"
            onClicked: settingsPopup.open()
        }
    }

    Popup {
        id: creditsPopup
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: (win.width - width) / 2
        y: (win.height - height) / 2
        width: Math.min(980, win.width - 48)
        height: Math.min(720, win.height - 48)
        Overlay.modal: Rectangle { color: Qt.rgba(0.0, 0.0, 0.0, 0.24) }
        background: Rectangle {
            radius: 26
            color: Qt.rgba(0.20, 0.16, 0.13, 0.98)
            border.width: 1
            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.30)
            antialiasing: true
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            Text {
                text: "CREDITS"
                color: win.textMain
                font.pixelSize: 34
                font.bold: true
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: creditsBody.implicitHeight
                ScrollBar.vertical: ThemeScrollBar {}

                Text {
                    id: creditsBody
                    width: parent.width
                    text:
                        "ENIGMA TOUCH è un progetto didattico e di design ispirato alla macchina Enigma e alla crittoanalisi del periodo 1930-1945.\n"
                        + "Obiettivo: rendere tangibili i concetti di cifratura a rotori, configurazione e procedura operativa, attraverso un'interfaccia moderna.\n\n"
                        + "Sviluppo & Concept: Nicolò Carestiato\n"
                        + "UI/UX: Nicolò Carestiato\n"
                        + "Ricerca e adattamento storico-divulgativo: Nicolò Carestiato\n"
                        + "Tecnologia: Python · PySide6 (Qt/QML)\n\n"
                        + "Versione: v__ · Build __ · © 2026\n\n"
                        + "Nota: Enigma Touch è una ricostruzione didattica. Alcune componenti e procedure sono semplificate per chiarezza e fruibilità; non intende sostituire testi e fonti storiche specialistiche.\n\n"
                        + "Contatti / progetto: nico.carestiato@gmail.com"
                    color: win.textSub
                    wrapMode: Text.WordWrap
                    font.pixelSize: 24
                    lineHeight: 1.20
                    Component.onCompleted: {
                        text =
                            "ENIGMA TOUCH e un progetto didattico e divulgativo ispirato alla macchina Enigma e alla crittoanalisi del periodo 1930-1945.\n"
                            + "L'obiettivo e rendere tangibili configurazione, cifratura, reset e procedura operativa attraverso un'esperienza fisica e digitale unica.\n\n"
                            + "Architettura software: Python con PySide6 / Qt Quick QML, logica di simulazione dedicata e sincronizzazione di audio, video e contenuti storici.\n"
                            + "Piattaforma hardware: Raspberry Pi 5 con avvio diretto dell'applicazione, uscita HDMI e gestione nativa della postazione espositiva.\n"
                            + "Controlli fisici: Raspberry Pi Pico RP2040 via USB, tre encoder rotativi indipendenti e pulsanti dedicati per navigazione, reset operativo e gestione power.\n"
                            + "Componentistica: encoder incrementali, pulsanti momentanei, interfaccia touch / mouse, tastiera fisica per il testo e cablaggio pensato per demo continue.\n\n"
                            + "Nota: Enigma Touch e una ricostruzione didattica. Alcune componenti e procedure sono semplificate per chiarezza espositiva e fluidita d'uso, senza sostituire fonti storiche specialistiche.\n\n"
                            + "Contatti / progetto: nico.carestiato@gmail.com"
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                GlassButton {
                    w: 190
                    h: 58
                    textSize: 20
                    text: "CHIUDI"
                    onClicked: creditsPopup.close()
                }
            }
        }
    }

    Popup {
        id: settingsPopup
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: (win.width - width) / 2
        y: (win.height - height) / 2
        width: Math.min(980, win.width - 48)
        height: Math.min(720, win.height - 48)
        Overlay.modal: Rectangle { color: Qt.rgba(0.0, 0.0, 0.0, 0.24) }
        background: Rectangle {
            radius: 26
            color: Qt.rgba(0.20, 0.16, 0.13, 0.98)
            border.width: 1
            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.28)
            antialiasing: true
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            Text {
                text: "SETTINGS"
                color: win.textMain
                font.pixelSize: 34
                font.bold: true
            }

            Text {
                text: "Audio, atmosfera e display"
                color: win.textSub
                font.pixelSize: 24
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 16
                rowSpacing: 16

            Rectangle {
                Layout.fillWidth: true
                    Layout.columnSpan: 2
                    Layout.preferredHeight: 224
                radius: 16
                color: Qt.rgba(0.08, 0.07, 0.06, 0.94)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)

                Column {
                    anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                    RowLayout {
                        width: parent.width
                            spacing: 12

                        Text {
                            text: "Musica sottofondo"
                            color: win.textMain
                                font.pixelSize: 24
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Switch {
                            checked: win.bgMusicEnabled
                            onToggled: win.bgMusicEnabled = checked
                        }
                    }

                    Row {
                        id: settingsThemeRow
                        width: parent.width
                            spacing: 12

                        GlassButton {
                                w: Math.max(220, Math.floor((settingsThemeRow.width - settingsThemeRow.spacing) / 2))
                                h: 54
                                textSize: 18
                            text: "TEMA CLASSICO"
                            primary: win.soundtrackMode === "classic"
                            onClicked: win.setSoundtrack("classic", true)
                        }

                        GlassButton {
                                w: Math.max(220, Math.floor((settingsThemeRow.width - settingsThemeRow.spacing) / 2))
                                h: 54
                                textSize: 18
                            text: "TEMA IMMERSIVO"
                            primary: win.soundtrackMode === "war"
                            onClicked: win.setSoundtrack("war", true)
                        }
                    }

                    Text {
                        text: "Volume base: " + Math.round(win.bgMusicVolume * 100) + "%"
                        color: win.textSub
                            font.pixelSize: 20
                    }

                    GlassSlider {
                        width: parent.width
                        from: 0.0
                        to: 1.0
                        value: win.bgMusicVolume
                        onValueChanged: win.bgMusicVolume = value
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                    Layout.preferredHeight: 152
                radius: 16
                color: Qt.rgba(0.08, 0.07, 0.06, 0.94)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)

                Column {
                    anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                    Text {
                        text: "Riduzione in Storia: " + Math.round((1 - win.storyDuckingFactor) * 100) + "%"
                        color: win.textMain
                            font.pixelSize: 22
                        font.bold: true
                            wrapMode: Text.WordWrap
                            width: parent.width
                    }

                    GlassSlider {
                        width: parent.width
                        from: 0.15
                        to: 1.0
                        value: win.storyDuckingFactor
                        onValueChanged: win.storyDuckingFactor = value
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                    Layout.preferredHeight: 152
                radius: 16
                color: Qt.rgba(0.08, 0.07, 0.06, 0.94)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)

                Column {
                    anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                    Text {
                        text: "Luminosita interfaccia: " + Math.round(win.uiBrightness * 100) + "%"
                        color: win.textMain
                            font.pixelSize: 22
                        font.bold: true
                            wrapMode: Text.WordWrap
                            width: parent.width
                    }

                    GlassSlider {
                        width: parent.width
                        from: 0.45
                        to: 1.0
                        value: win.uiBrightness
                        onValueChanged: win.uiBrightness = value
                    }

                }
            }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                GlassButton {
                    w: 260
                    h: 58
                    textSize: 18
                    text: "RIPRISTINA DEFAULT"
                    onClicked: {
                        win.bgMusicVolume = 0.50
                        win.bgMusicEnabled = true
                        win.storyDuckingFactor = 0.20
                        win.uiBrightness = 1.0
                        win.setSoundtrack("classic", true)
                    }
                }

                Item { Layout.fillWidth: true }

                GlassButton {
                    w: 190
                    h: 58
                    textSize: 20
                    text: "CHIUDI"
                    onClicked: settingsPopup.close()
                }
            }
        }
    }

    Text {
        visible: win.page !== "intro" && win.page !== "machine" && win.page !== "disclaimer" && win.page !== "soundtrack"
        text: "by Nicolò Carestiato"
        color: Qt.rgba(win.textSub.r, win.textSub.g, win.textSub.b, 0.85)
        font.pixelSize: 17
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
    }

    Rectangle {
        id: pageFadeLayer
        anchors.fill: parent
        color: "black"
        opacity: 0.0
        visible: opacity > 0.001
        z: 980
    }

    Item {
        id: disruptionOverlay
        anchors.fill: parent
        visible: win.disruptionActive
        z: 1300

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: win.disruptionBlackPhase ? 1.0 : 0.96
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(1160, win.width - 56)
            spacing: 24
            visible: !win.disruptionBlackPhase

            Text {
                text: win.disruptionTitle
                color: Qt.rgba(1.0, 0.94, 0.86, 0.98)
                font.pixelSize: Math.min(52, Math.max(38, win.width * 0.036))
                font.bold: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: win.dismissDisruptionQuick()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.55)
            }

            Text {
                text: win.disruptionText
                color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
                font.pixelSize: Math.min(34, Math.max(26, win.width * 0.023))
                lineHeight: 1.30
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            Row {
                spacing: 14
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: 3
                    Rectangle {
                        id: pulseDot
                        required property int index
                        width: 14
                        height: 14
                        radius: 7
                        color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.92)

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: disruptionOverlay.visible && !win.disruptionBlackPhase
                            PauseAnimation { duration: pulseDot.index * 120 }
                            NumberAnimation { to: 0.30; duration: 220; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 260; easing.type: Easing.InOutQuad }
                            PauseAnimation { duration: 120 }
                        }
                    }
                }
            }

            Text {
                text: "Ripristino rete in corso..."
                color: Qt.rgba(win.textSub.r, win.textSub.g, win.textSub.b, 0.92)
                font.pixelSize: 21
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onPressed: function(mouse) { mouse.accepted = true }
            onWheel: function(wheel) { wheel.accepted = true }
        }
    }

    Item {
        id: disclaimerPage
        anchors.fill: parent
        visible: win.page === "disclaimer"
        z: 400

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(1060, win.width - 120)
            spacing: 22

            Text {
                text: "DISCLAIMER"
                color: Qt.rgba(1.0, 1.0, 1.0, 0.96)
                font.pixelSize: 44
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            Text {
                text: "Questo applicativo non si propone come ricostruzione storica perfetta.\n\nEnigma Touch e' una ricostruzione didattica e divulgativa: alcune parti sono semplificate per facilitare comprensione, utilizzo e apprendimento.\n\nLe configurazioni, i tempi operativi e alcune dinamiche narrative sono adattate per finalita formative.\n\nIl progetto non intende glorificare eventi bellici: l'obiettivo e' spiegare principi storici e crittografici in modo accessibile.\n\nEssendo una ricostruzione indipendente a scopo didattico, possono verificarsi occasionali malfunzionamenti o comportamenti non previsti."
                color: Qt.rgba(1.0, 1.0, 1.0, 0.85)
                font.pixelSize: 24
                lineHeight: 1.18
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            GlassButton {
                text: "CONTINUA"
                primary: true
                w: 270
                h: 64
                textSize: 22
                Layout.alignment: Qt.AlignHCenter
                onClicked: win.page = "soundtrack"
            }
        }
    }

    Item {
        id: soundtrackPage
        anchors.fill: parent
        visible: win.page === "soundtrack"
        z: 390

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.70)
        }

        GlassCard {
            width: Math.min(1040, win.width - 96)
            height: Math.min(540, win.height - 96)
            anchors.centerIn: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 16

                Text {
                    text: "SCEGLI ATMOSFERA SONORA"
                    color: win.textMain
                    font.pixelSize: 38
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: "Seleziona la colonna sonora con cui vuoi vivere l'esperienza."
                    color: win.textSub
                    font.pixelSize: 19
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Qt.rgba(0, 0, 0, 0.20)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12

                            Text {
                                text: "IMMERSIVA"
                                color: win.textMain
                                font.pixelSize: 24
                                font.bold: true
                            }

                            Text {
                                text: "Scenario bellico: ambiente piu intenso e drammatico."
                                color: win.textSub
                                font.pixelSize: 18
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item { Layout.fillHeight: true }

                            GlassButton {
                                text: "TRACCIA IMMERSIVA"
                                primary: true
                                w: 280
                                h: 58
                                textSize: 18
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: win.beginWithSoundtrack("war")
                            }
                        }
                    }

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Qt.rgba(0, 0, 0, 0.20)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12

                            Text {
                                text: "CLASSICA"
                                color: win.textMain
                                font.pixelSize: 24
                                font.bold: true
                            }

                            Text {
                                text: "Rivisitazione avventura piu generica, meno impattante."
                                color: win.textSub
                                font.pixelSize: 18
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item { Layout.fillHeight: true }

                            GlassButton {
                                text: "TRACCIA CLASSICA"
                                primary: true
                                w: 260
                                h: 58
                                textSize: 18
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: win.beginWithSoundtrack("classic")
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Item {
        id: bootPage
        anchors.fill: parent
        visible: win.page === "boot"

        GlassCard {
            id: bootCard
            width: Math.min(1140, win.width - 56)
            height: Math.min(455, win.height - 72)
            anchors.centerIn: parent

            Column {
                anchors.centerIn: parent
                width: bootCard.width - 120
                spacing: 22

                Text {
                    text: "ENIGMA TOUCH"
                    color: win.textMain
                    font.pixelSize: Math.min(86, Math.max(64, bootCard.width * 0.072))
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 1.03; duration: 850; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.03; to: 1.0; duration: 850; easing.type: Easing.InOutQuad }
                    }
                }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 280
                    height: 112

                    Repeater {
                        model: 3
                        Rectangle {
                            id: ring
                            required property int index
                            width: 92 + (index * 40)
                            height: width
                            radius: width / 2
                            anchors.centerIn: parent
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.35 - (index * 0.08))
                            antialiasing: true
                            opacity: 0.92 - (index * 0.20)

                            RotationAnimator on rotation {
                                from: 0
                                to: (ring.index % 2 === 0) ? 360 : -360
                                duration: 2200 + (ring.index * 900)
                                loops: Animation.Infinite
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Repeater {
                        model: 5
                        Rectangle {
                            id: dot
                            required property int index
                            width: 14
                            height: 14
                            radius: 7
                            color: win.textSub

                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                PauseAnimation { duration: dot.index * 110 }
                                NumberAnimation { to: -13; duration: 260; easing.type: Easing.OutCubic }
                                NumberAnimation { to: 0; duration: 300; easing.type: Easing.InCubic }
                                PauseAnimation { duration: 180 }
                            }
                        }
                    }
                }

                Rectangle {
                    width: Math.min(880, parent.width - 70)
                    height: 22
                    radius: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
                    clip: true

                    Rectangle {
                        width: parent.width * win.bootProgress
                        height: parent.height
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.85) }
                            GradientStop { position: 1.0; color: Qt.rgba(1.0, 0.92, 0.75, 0.95) }
                        }
                    }

                    Rectangle {
                        width: 104
                        height: parent.height
                        radius: parent.radius
                        x: (parent.width + width) * win.bootProgress - width
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.20)
                    }
                }

                Text {
                    text: win.bootStatusText()
                    color: win.textSub
                    font.pixelSize: 19
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: Math.round(win.bootProgress * 100) + "%"
                    color: Qt.rgba(win.textMain.r, win.textMain.g, win.textMain.b, 0.92)
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        SequentialAnimation {
            id: bootProgressAnim
            running: false

            PauseAnimation { duration: win.bootHoldMs }

            NumberAnimation {
                target: win
                property: "bootProgress"
                to: 0.48
                duration: Math.max(1, Math.round(win.bootTravelMs * 0.48))
                easing.type: Easing.Linear
            }
            PauseAnimation { duration: win.bootPause48Ms }

            NumberAnimation {
                target: win
                property: "bootProgress"
                to: 0.60
                duration: Math.max(1, Math.round(win.bootTravelMs * 0.12))
                easing.type: Easing.Linear
            }
            PauseAnimation { duration: win.bootPause60Ms }

            NumberAnimation {
                target: win
                property: "bootProgress"
                to: 0.98
                duration: Math.max(1, Math.round(win.bootTravelMs * 0.38))
                easing.type: Easing.Linear
            }
            PauseAnimation { duration: win.bootPause98Ms }

            NumberAnimation {
                target: win
                property: "bootProgress"
                to: 1.0
                duration: Math.max(1, win.bootTravelMs - Math.round(win.bootTravelMs * 0.48) - Math.round(win.bootTravelMs * 0.12) - Math.round(win.bootTravelMs * 0.38))
                easing.type: Easing.Linear
            }

            ScriptAction { script: win.page = "intro" }
        }
    }

    Item {
        id: introPage
        anchors.fill: parent
        visible: win.page === "intro"
        onVisibleChanged: {
            if (!visible) {
                win.galleryExpanded = false
            }
        }

        GlassCard {
            id: introCard
            width: Math.min(1120, win.width - 72)
            height: Math.min(660, win.height - 72)
            anchors.centerIn: parent
            property int galleryHeight: Math.max(260, Math.min(340, Math.floor(height * 0.50)))
            property int galleryCardSize: galleryHeight
            property int galleryGap: 16
            property int galleryViewportWidth: Math.min(width - 48, Math.max(760, Math.floor(width * 0.92)))

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 12

                Column {
                    width: parent.width
                    spacing: 12
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "ENIGMA TOUCH"
                        color: win.textMain
                        font.pixelSize: Math.min(70, Math.max(52, introCard.width * 0.058))
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Una reinterpretazione contemporanea della macchina Enigma.\nInterfaccia moderna, principio crittografico autentico."
                        color: win.textSub
                        font.pixelSize: 18
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: win.bodyLine
                        width: Math.min(parent.width, 900)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Item { height: 4; width: 1 }

                Item {
                    id: galleryViewport
                    width: introCard.galleryViewportWidth
                    height: introCard.galleryHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    clip: true
                    property real maxShift: Math.max(0, galleryTrack.width - width)

                    Row {
                        id: galleryTrack
                        spacing: introCard.galleryGap

                        Repeater {
                            model: win.galleryAssetUrls.length

                            delegate: Item {
                                id: galleryCard
                                required property int index
                                width: introCard.galleryCardSize
                                height: introCard.galleryCardSize
                                property url cardSource: win.galleryAssetUrls[index]
                                property int frameRadius: 28

                                Rectangle {
                                    anchors.fill: parent
                                    radius: galleryCard.frameRadius
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(0.0, 0.0, 0.0, 0.42)
                                    antialiasing: true
                                }

                                Rectangle {
                                    id: cardClip
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: galleryCard.frameRadius - 1
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                    antialiasing: true

                                    Image {
                                        id: cardImageRaw
                                        anchors.fill: parent
                                        source: galleryCard.cardSource
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                        visible: false
                                    }

                                    Rectangle {
                                        id: cardMask
                                        anchors.fill: parent
                                        radius: cardClip.radius
                                        color: "black"
                                        visible: false
                                        antialiasing: true
                                    }

                                    OpacityMask {
                                        anchors.fill: cardImageRaw
                                        source: cardImageRaw
                                        maskSource: cardMask
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        win.galleryExpandedSource = galleryCard.cardSource
                                        win.galleryExpanded = true
                                    }
                                }
                            }
                        }

                        SequentialAnimation on x {
                            loops: Animation.Infinite
                            running: win.page === "intro" && galleryViewport.maxShift > 0 && win.galleryAssetUrls.length > 1
                            paused: win.galleryExpanded
                            NumberAnimation {
                                from: 0
                                to: -galleryViewport.maxShift
                                duration: 26000
                                easing.type: Easing.InOutSine
                            }
                            PauseAnimation { duration: 700 }
                            NumberAnimation {
                                from: -galleryViewport.maxShift
                                to: 0
                                duration: 26000
                                easing.type: Easing.InOutSine
                            }
                            PauseAnimation { duration: 700 }
                        }
                    }

                    Text {
                        visible: win.galleryAssetUrls.length === 0
                        anchors.centerIn: parent
                        text: "Nessuna immagine in ui/assets/gallery"
                        color: win.textSub
                        font.pixelSize: 15
                    }
                }

                Item { height: 4; width: 1 }

                GlassButton {
                    text: "INIZIA ESPERIENZA"
                    primary: true
                    w: galleryViewport.width
                    h: 70
                    textSize: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: {
                        win.galleryExpanded = false
                        win.page = "home"
                    }
                }
            }
        }

        Rectangle {
            id: galleryOverlay
            anchors.fill: parent
            z: 60
            visible: win.galleryExpanded
            color: Qt.rgba(0.0, 0.0, 0.0, 0.62)

            MouseArea {
                anchors.fill: parent
                onClicked: win.galleryExpanded = false
            }

            Item {
                id: zoomCard
                width: Math.min(win.width - 180, win.height - 140)
                height: width
                anchors.centerIn: parent

                Rectangle {
                    anchors.fill: parent
                    radius: 28
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0.0, 0.0, 0.0, 0.46)
                    antialiasing: true
                }

                Rectangle {
                    id: zoomClip
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: 26
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
                    antialiasing: true

                    Image {
                        id: zoomImageRaw
                        anchors.fill: parent
                        source: win.galleryExpandedSource
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        visible: false
                    }

                    Rectangle {
                        id: zoomMask
                        anchors.fill: parent
                        radius: zoomClip.radius
                        color: "black"
                        visible: false
                        antialiasing: true
                    }

                    OpacityMask {
                        anchors.fill: zoomImageRaw
                        source: zoomImageRaw
                        maskSource: zoomMask
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.galleryExpanded = false
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: win.page === "home"

        GlassCard {
            width: Math.min(1100, win.width - 120)
            height: Math.min(640, win.height - 140)
            anchors.centerIn: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 18

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "ENIGMA TOUCH"
                        color: win.textMain
                        font.pixelSize: win.fsTitle
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "HOME"
                        color: win.textSub
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 18

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 26

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 22
                            spacing: 12

                            Text {
                                text: "MACCHINA"
                                color: win.textMain
                                font.pixelSize: win.fsSection
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            RoundedImagePanel {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 152
                                source: Qt.resolvedUrl("assets/help/configurazione-photo.jpg")
                                emptyLabel: "Vista macchina"
                            }

                            Text {
                                text: "Entra nella macchina: rotori, plugboard, cifratura."
                                color: win.textSub
                                font.pixelSize: win.fsLabel
                                wrapMode: Text.WordWrap
                                lineHeight: win.bodyLine
                                Layout.fillWidth: true
                            }

                            Item { Layout.fillHeight: true }

                            GlassButton {
                                text: "APRI"
                                primary: true
                                w: 260
                                h: 54
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: win.page = "machine"
                            }
                        }
                    }

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 26

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 22
                            spacing: 12

                            Text {
                                text: "STORIA"
                                color: win.textMain
                                font.pixelSize: win.fsSection
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            RoundedImagePanel {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 152
                                source: Qt.resolvedUrl("assets/gallery/1.png")
                                emptyLabel: "Contesto storico"
                            }

                            Text {
                                text: "Scopri il contesto storico di Enigma, la decifrazione e l'impatto sul conflitto."
                                color: win.textSub
                                font.pixelSize: win.fsLabel
                                wrapMode: Text.WordWrap
                                lineHeight: win.bodyLine
                                Layout.fillWidth: true
                            }

                            Item { Layout.fillHeight: true }

                            GlassButton {
                                text: "SCOPRI LA STORIA"
                                primary: true
                                w: 300
                                h: 54
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: win.page = "story"
                            }
                        }
                    }

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 26
                        color: Qt.rgba(0.24, 0.18, 0.13, 0.42)
                        border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.24)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 22
                            spacing: 12

                            Text {
                                text: "MISSIONE"
                                color: win.textMain
                                font.pixelSize: win.fsSection
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            RoundedImagePanel {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 152
                                source: Qt.resolvedUrl("assets/help/plugboard-photo.jpg")
                                emptyLabel: "Sfida operativa"
                            }

                            Text {
                                text: "Sfida guidata: imposta la macchina, produci il cifrato target e valida il risultato."
                                color: win.textSub
                                font.pixelSize: win.fsLabel
                                wrapMode: Text.WordWrap
                                lineHeight: win.bodyLine
                                Layout.fillWidth: true
                            }

                            Item { Layout.fillHeight: true }

                            GlassButton {
                                text: "AVVIA MISSIONE"
                                primary: true
                                w: 260
                                h: 54
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: machine.startMission()
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: machine
        anchors.fill: parent
        visible: win.page === "machine"
        focus: visible
        property var rotorOptions: ["I", "II", "III", "IV", "V"]
        property var reflectorOptions: ["B", "C"]
        property var rotorLabels: ["SINISTRA", "CENTRO", "DESTRA"]
        property string helpTitle: ""
        property string helpLeadHtml: ""
        property string helpBodyHtml: ""
        property string helpImagePath: ""
        property string helpImageSide: "right"
        property string helpImageCaption: ""
        property var helpChecklistItems: []
        property var helpChecklistStates: []
        property var helpChecklistMemory: ({})
        property var helpScenarioMemory: ({})
        property var helpEntry: ({})
        property var helpScenarioItems: []
        property int helpScenarioIndex: 0
        property bool helpScenarioMenuOpen: false
        property string helpScenarioLabel: ""
        property string helpCurrentKey: ""
        property url helpImageSource: ""
        property string helpChecklistAlert: ""

        function rotorIndex(name) {
            var idx = rotorOptions.indexOf(name)
            return idx >= 0 ? idx : 0
        }

        function reflectorIndex(name) {
            var idx = reflectorOptions.indexOf(name)
            return idx >= 0 ? idx : 0
        }

        function rotorChar(index) {
            if (!win.simController || !win.simController.currentPositions || win.simController.currentPositions.length < 3) {
                return "-"
            }
            return win.simController.currentPositions.charAt(index)
        }

        function alphaIndex(letter) {
            var c = (letter || "").toUpperCase()
            if (c.length === 0) {
                return 0
            }
            var idx = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".indexOf(c.charAt(0))
            return idx >= 0 ? idx : 0
        }

        function alphabetCharAt(index) {
            var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            var i = ((index % letters.length) + letters.length) % letters.length
            return letters.charAt(i)
        }

        function syncFromController() {
            if (!win.simController) {
                return
            }
            rotorLeftBox.currentIndex = rotorIndex(win.simController.rotorLeft)
            rotorMiddleBox.currentIndex = rotorIndex(win.simController.rotorMiddle)
            rotorRightBox.currentIndex = rotorIndex(win.simController.rotorRight)
            reflectorBox.currentIndex = reflectorIndex(win.simController.reflector)
            positionsField.text = win.simController.startPositions
        }

        function applyRotorConfig() {
            if (!win.simController) {
                return
            }
            win.simController.setRotorOrder(
                rotorLeftBox.currentText,
                rotorMiddleBox.currentText,
                rotorRightBox.currentText
            )
        }

        function wheelRotor(index, deltaY) {
            if (!win.simController || deltaY === 0) {
                return
            }
            win.simController.rotateRotor(index, deltaY > 0 ? 1 : -1)
            positionsField.text = win.simController.startPositions
        }

        function startMission() {
            if (!win.simController) {
                return
            }
            win.simController.startChallenge()
            win.page = "machine"
            missionPopup.open()
            machine.forceActiveFocus()
        }

        function openMission() {
            if (!win.simController) {
                return
            }
            if (!win.simController.challengeActive && !win.simController.challengeSolved) {
                win.simController.startChallenge()
            }
            missionPopup.open()
            machine.forceActiveFocus()
        }

        function submitMission() {
            if (!win.simController) {
                return
            }
            win.simController.submitChallenge()
            machine.forceActiveFocus()
        }

        function revealMissionSolution() {
            if (!win.simController) {
                return
            }
            var solution = win.simController.revealChallengeSolution()
            if (solution && solution !== "---") {
                positionsField.text = solution
            }
            machine.forceActiveFocus()
        }

        function cancelMission() {
            if (win.simController) {
                win.simController.cancelChallenge()
            }
            missionPopup.close()
            machine.forceActiveFocus()
        }

        function resetHelpChecklist() {
            var states = []
            for (var i = 0; i < machine.helpChecklistItems.length; i++) {
                states.push(false)
            }
            machine.helpChecklistStates = states
            if (machine.currentHelpStateKey().length > 0) {
                var memory = machine.helpChecklistMemory
                memory[machine.currentHelpStateKey()] = states.slice(0)
                machine.helpChecklistMemory = memory
            }
        }

        function currentHelpStateKey() {
            if (machine.helpCurrentKey.length === 0) {
                return ""
            }
            return machine.helpCurrentKey + "::" + machine.helpScenarioIndex
        }

        function helpChecklistCheckedCount() {
            var count = 0
            for (var i = 0; i < machine.helpChecklistStates.length; i++) {
                if (machine.helpChecklistStates[i]) {
                    count += 1
                }
            }
            return count
        }

        function setHelpChecklistState(index, checked) {
            var nextStates = machine.helpChecklistStates.slice(0)
            while (nextStates.length < machine.helpChecklistItems.length) {
                nextStates.push(false)
            }
            var targetChecked = checked
            if (index < nextStates.length && nextStates[index] === checked) {
                targetChecked = !checked
            }
            if (targetChecked) {
                for (var p = 0; p < index; p++) {
                    if (!nextStates[p]) {
                        machine.helpChecklistAlert = "Completa prima il punto " + (p + 1) + ". La checklist va seguita in ordine."
                        helpChecklistAlertTimer.restart()
                        return
                    }
                }
            }
            nextStates[index] = targetChecked
            if (!targetChecked) {
                for (var n = index + 1; n < nextStates.length; n++) {
                    nextStates[n] = false
                }
            }
            machine.helpChecklistStates = nextStates

            if (machine.currentHelpStateKey().length > 0) {
                var memory = machine.helpChecklistMemory
                memory[machine.currentHelpStateKey()] = nextStates.slice(0)
                machine.helpChecklistMemory = memory
            }
        }

        function applyHelpScenario(index) {
            var source = machine.helpEntry
            if (machine.helpScenarioItems.length > 0) {
                var clamped = Math.max(0, Math.min(machine.helpScenarioItems.length - 1, index))
                machine.helpScenarioIndex = clamped
                if (machine.helpCurrentKey.length > 0) {
                    var scenarioMemory = machine.helpScenarioMemory
                    scenarioMemory[machine.helpCurrentKey] = clamped
                    machine.helpScenarioMemory = scenarioMemory
                }
                source = machine.helpScenarioItems[clamped]
            } else {
                machine.helpScenarioIndex = 0
            }
            machine.helpScenarioMenuOpen = false

            machine.helpTitle = machine.helpEntry.title ? machine.helpEntry.title : ""
            machine.helpLeadHtml = source.leadHtml ? source.leadHtml : ""
            machine.helpBodyHtml = source.bodyHtml ? source.bodyHtml : ""
            machine.helpImagePath = source.imagePath ? source.imagePath : ""
            machine.helpImageSide = source.imageSide ? source.imageSide : "right"
            machine.helpImageCaption = source.imageCaption ? source.imageCaption : ""
            machine.helpScenarioLabel = source.label ? source.label : ""
            machine.helpChecklistItems = source.checklist ? source.checklist.slice(0) : []
            machine.helpImageSource = machine.helpImagePath.length > 0
                                     ? Qt.resolvedUrl(machine.helpImagePath)
                                     : ""

            if (machine.helpChecklistItems.length > 0) {
                var memory = machine.helpChecklistMemory
                var key = machine.currentHelpStateKey()
                if (memory[key] && memory[key].length === machine.helpChecklistItems.length) {
                    machine.helpChecklistStates = memory[key].slice(0)
                } else {
                    machine.resetHelpChecklist()
                }
            } else {
                machine.helpChecklistStates = []
            }
        }

        function openHelpKey(helpKey) {
            var entry = HelpCatalog.getEntry(helpKey)
            machine.helpCurrentKey = helpKey ? helpKey : ""
            machine.helpEntry = entry
            machine.helpScenarioItems = entry.scenarios ? entry.scenarios.slice(0) : []
            var rememberedScenario = 0
            if (machine.helpCurrentKey.length > 0 && machine.helpScenarioMemory[machine.helpCurrentKey] !== undefined) {
                rememberedScenario = machine.helpScenarioMemory[machine.helpCurrentKey]
            }
            machine.helpScenarioMenuOpen = false
            machine.applyHelpScenario(rememberedScenario)
            helpPopup.open()
        }

        onVisibleChanged: {
            if (visible) {
                syncFromController()
                machine.forceActiveFocus()
            }
        }

        Connections {
            target: win.simController

            function onStateChanged() {
                if (machine.visible) {
                    positionsField.text = win.simController.startPositions
                }
            }
        }

        Keys.onPressed: function(event) {
            if (!machine.visible || !win.simController) {
                return
            }
            if (plugA.activeFocus || plugB.activeFocus || unplugLetter.activeFocus || positionsField.activeFocus) {
                return
            }
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) {
                return
            }

            if (event.key === Qt.Key_Escape) {
                win.page = "home"
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Backspace) {
                win.simController.backspaceInputStream()
                machine.forceActiveFocus()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Delete || event.key === Qt.Key_Tab) {
                event.accepted = true
                return
            }

            if (event.text && event.text.length === 1) {
                win.simController.stepChar(event.text)
                event.accepted = true
            }
        }

        Timer {
            id: missionHeartbeatTimer
            interval: 1000
            repeat: true
            running: win.simController && win.simController.challengeActive
            onTriggered: win.simController.challengeHeartbeat()
        }

        Timer {
            id: helpChecklistAlertTimer
            interval: 2400
            repeat: false
            onTriggered: machine.helpChecklistAlert = ""
        }

        Popup {
            id: missionPopup
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            x: (win.width - width) / 2
            y: (win.height - height) / 2
            width: Math.min(860, win.width - 80)
            height: Math.min(640, win.height - 70)
            padding: 0
            Overlay.modal: Rectangle {
                color: Qt.rgba(0.0, 0.0, 0.0, 0.50)
            }
            background: Rectangle {
                radius: 28
                antialiasing: true
                color: Qt.rgba(0.20, 0.15, 0.11, 0.98)
                border.width: 1
                border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.34)
            }

            contentItem: ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "MISSIONE ENIGMA"
                            color: win.textMain
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Text {
                            text: "Usa la simulazione per produrre il cifrato target con la configurazione richiesta."
                            color: win.textSub
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    GlassButton {
                        w: 116
                        h: 36
                        textSize: 13
                        text: "CHIUDI"
                        onClicked: missionPopup.close()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 160
                        Layout.preferredHeight: 40
                        radius: 14
                        color: win.simController && win.simController.challengeActive
                               ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22)
                               : Qt.rgba(1.0, 1.0, 1.0, 0.07)
                        border.width: 1
                        border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.25)

                        Text {
                            anchors.centerIn: parent
                            text: win.simController && win.simController.challengeSolved ? "COMPLETATA"
                                  : (win.simController && win.simController.challengeActive ? "ATTIVA" : "NON ATTIVA")
                            color: win.textMain
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 40
                        radius: 14
                        color: Qt.rgba(0.0, 0.0, 0.0, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                        Text {
                            anchors.centerIn: parent
                            text: "TENTATIVI: " + (win.simController ? win.simController.challengeAttempts : 0)
                            color: win.textMain
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 40
                        radius: 14
                        color: Qt.rgba(0.0, 0.0, 0.0, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                        Text {
                            anchors.centerIn: parent
                            text: "TEMPO: " + (win.simController ? win.simController.challengeElapsed : 0) + "s"
                            color: win.textMain
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 40
                        radius: 14
                        color: Qt.rgba(0.0, 0.0, 0.0, 0.16)
                        border.width: 1
                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                        Text {
                            anchors.centerIn: parent
                            text: "SCORE: " + (win.simController ? win.simController.challengeScore : 0)
                            color: win.textMain
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                ScrollView {
                    id: missionScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.vertical: ThemeScrollBar {}

                    Column {
                        width: missionScroll.availableWidth - 4
                        spacing: 14

                        Row {
                            width: parent.width
                            spacing: 14

                            Rectangle {
                                width: (parent.width - 14) / 2
                                implicitHeight: plainTargetText.implicitHeight + 46
                                radius: 22
                                color: Qt.rgba(0.38, 0.29, 0.22, 0.42)
                                border.width: 1
                                border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.24)

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 8

                                    Text {
                                        text: "PLAINTEXT DA DIGITARE"
                                        color: win.textSub
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    Text {
                                        id: plainTargetText
                                        width: parent.width
                                        text: win.simController && win.simController.challengePlain.length > 0
                                              ? win.simController.challengePlain
                                              : "Premi NUOVA MISSIONE"
                                        color: win.textMain
                                        font.pixelSize: 30
                                        font.bold: true
                                        wrapMode: Text.WrapAnywhere
                                    }
                                }
                            }

                            Rectangle {
                                width: (parent.width - 14) / 2
                                implicitHeight: cipherTargetText.implicitHeight + 46
                                radius: 22
                                color: Qt.rgba(0.38, 0.29, 0.22, 0.42)
                                border.width: 1
                                border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.24)

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 8

                                    Text {
                                        text: "CIFRATO TARGET"
                                        color: win.textSub
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    Text {
                                        id: cipherTargetText
                                        width: parent.width
                                        text: win.simController && win.simController.challengeCipher.length > 0
                                              ? win.simController.challengeCipher
                                              : "---"
                                        color: win.accent
                                        font.pixelSize: 30
                                        font.bold: true
                                        wrapMode: Text.WrapAnywhere
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            implicitHeight: missionConfigText.implicitHeight + 42
                            radius: 22
                            color: Qt.rgba(0.0, 0.0, 0.0, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8

                                Text {
                                    text: "CONFIGURAZIONE BLOCCATA"
                                    color: win.textSub
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Text {
                                    id: missionConfigText
                                    width: parent.width
                                    text: win.simController ? win.simController.challengeConfig : "Controller non disponibile."
                                    color: win.textMain
                                    font.pixelSize: 15
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.28
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            implicitHeight: missionRulesText.implicitHeight + 42
                            radius: 22
                            color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.10)
                            border.width: 1
                            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.18)

                            Text {
                                id: missionRulesText
                                anchors.fill: parent
                                anchors.margins: 16
                                text:
                                    "<b>Come si gioca:</b><br>"
                                    + "1. Imposta una posizione iniziale e premi APPLICA.<br>"
                                    + "2. Digita esattamente il plaintext indicato.<br>"
                                    + "3. Premi VALIDA: se l'output coincide con il cifrato target, la missione e completata.<br>"
                                    + "4. Se vuoi fare una prova veloce, MOSTRA SOLUZIONE inserisce la posizione corretta nel campo posizioni."
                                textFormat: Text.RichText
                                color: win.textMain
                                font.pixelSize: 15
                                wrapMode: Text.WordWrap
                                lineHeight: 1.30
                            }
                        }

                        Rectangle {
                            width: parent.width
                            implicitHeight: missionStatusText.implicitHeight + 34
                            radius: 18
                            color: Qt.rgba(0.13, 0.10, 0.08, 0.62)
                            border.width: 1
                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                            Text {
                                id: missionStatusText
                                anchors.fill: parent
                                anchors.margins: 14
                                text: win.simController ? win.simController.challengeStatus : "Controller non disponibile."
                                color: win.textMain
                                font.pixelSize: 15
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    GlassButton {
                        w: 170
                        h: 42
                        text: "NUOVA MISSIONE"
                        primary: true
                        onClicked: machine.startMission()
                    }

                    GlassButton {
                        w: 130
                        h: 42
                        text: "VALIDA"
                        onClicked: machine.submitMission()
                    }

                    GlassButton {
                        w: 170
                        h: 42
                        text: "MOSTRA SOL."
                        onClicked: machine.revealMissionSolution()
                    }

                    Item { Layout.fillWidth: true }

                    GlassButton {
                        w: 120
                        h: 42
                        text: "ANNULLA"
                        onClicked: machine.cancelMission()
                    }
                }
            }
        }

        Popup {
            id: helpPopup
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            x: (win.width - width) / 2
            y: (win.height - height) / 2
            width: Math.min(1000, win.width - 70)
            height: Math.min(720, win.height - 60)
            padding: 0
            Overlay.modal: Rectangle {
                color: Qt.rgba(0.0, 0.0, 0.0, 0.52)
            }
            background: Rectangle {
                radius: 26
                antialiasing: true
                color: Qt.rgba(0.20, 0.16, 0.13, 0.98)
                border.width: 1
                border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.30)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 25
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.06)
                }
            }

            contentItem: ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: machine.helpTitle
                        color: win.textMain
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    GlassButton {
                        w: 110
                        h: 34
                        textSize: 13
                        text: "CHIUDI"
                        onClicked: helpPopup.close()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: machine.helpScenarioItems.length > 0
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "SCENARIO DI TEST"
                            color: win.textSub
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 420
                            Layout.preferredHeight: 42
                            radius: 14
                            color: Qt.rgba(0.15, 0.11, 0.09, 0.74)
                            border.width: 1
                            border.color: machine.helpScenarioMenuOpen
                                          ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.42)
                                          : Qt.rgba(1.0, 1.0, 1.0, 0.13)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Text {
                                    Layout.fillWidth: true
                                    text: machine.helpScenarioLabel.length > 0
                                          ? machine.helpScenarioLabel
                                          : "Scegli una prova"
                                    color: win.textMain
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    text: machine.helpScenarioMenuOpen ? "^" : "v"
                                    color: win.textSub
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: machine.helpScenarioMenuOpen = !machine.helpScenarioMenuOpen
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            radius: 12
                            color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.18)
                            border.width: 1
                            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.30)
                            Layout.preferredWidth: 170
                            Layout.preferredHeight: 34

                            Text {
                                anchors.centerIn: parent
                                text: (machine.helpScenarioIndex + 1) + " / " + machine.helpScenarioItems.length
                                color: win.textMain
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 420
                        Layout.fillWidth: false
                        visible: machine.helpScenarioMenuOpen
                        implicitHeight: Math.min(helpScenarioMenuColumn.implicitHeight + 10, 270)
                        radius: 18
                        color: Qt.rgba(0.11, 0.09, 0.08, 0.96)
                        border.width: 1
                        border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22)

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 5
                            clip: true
                            contentWidth: width
                            contentHeight: helpScenarioMenuColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: helpScenarioMenuColumn
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: machine.helpScenarioItems

                                    delegate: Rectangle {
                                        id: scenarioItem
                                        required property int index
                                        required property var modelData
                                        width: parent.width
                                        height: helpScenarioRow.implicitHeight + 18
                                        radius: 12
                                        color: scenarioItem.index === machine.helpScenarioIndex
                                               ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22)
                                               : "transparent"
                                        border.width: scenarioItem.index === machine.helpScenarioIndex ? 1 : 0
                                        border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.28)

                                        RowLayout {
                                            id: helpScenarioRow
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 10

                                            Rectangle {
                                                Layout.preferredWidth: 26
                                                Layout.preferredHeight: 26
                                                radius: 13
                                                color: scenarioItem.index === machine.helpScenarioIndex
                                                       ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.92)
                                                       : Qt.rgba(1.0, 1.0, 1.0, 0.08)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: scenarioItem.index + 1
                                                    color: scenarioItem.index === machine.helpScenarioIndex
                                                           ? Qt.rgba(0.15, 0.11, 0.08, 0.98)
                                                           : win.textMain
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: scenarioItem.modelData && scenarioItem.modelData.label ? scenarioItem.modelData.label : ("Scenario " + (scenarioItem.index + 1))
                                                color: win.textMain
                                                font.pixelSize: 14
                                                font.bold: scenarioItem.index === machine.helpScenarioIndex
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: machine.applyHelpScenario(scenarioItem.index)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: machine.helpScenarioLabel.length > 0
                    implicitHeight: scenarioLabelRow.implicitHeight + 22
                    radius: 18
                    color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.28)

                    RowLayout {
                        id: scenarioLabelRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 84
                            Layout.preferredHeight: 28
                            radius: 12
                            color: Qt.rgba(0.14, 0.10, 0.08, 0.68)
                            border.width: 1
                            border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                            Text {
                                anchors.centerIn: parent
                                text: "PROVA"
                                color: win.textMain
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: machine.helpScenarioLabel
                            color: win.textMain
                            font.pixelSize: 16
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                ScrollView {
                    id: helpScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical: ThemeScrollBar {}

                    contentWidth: availableWidth

                    Column {
                        width: helpScroll.availableWidth - 4
                        spacing: 16

                        Rectangle {
                            id: helpIntroCard
                            width: parent.width
                            implicitHeight: helpIntroLayout.implicitHeight + 36
                            radius: 24
                            color: Qt.rgba(0.31, 0.25, 0.20, 0.44)
                            border.width: 1
                            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22)

                            ColumnLayout {
                                id: helpIntroLayout
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 14

                                RowLayout {
                                    id: helpIntroRow
                                    Layout.fillWidth: true
                                    spacing: 18

                                    Rectangle {
                                        Layout.preferredWidth: machine.helpImagePath.length > 0 && machine.helpImageSide === "left" ? 334 : 0
                                        Layout.preferredHeight: machine.helpImagePath.length > 0 && machine.helpImageSide === "left" ? 280 : 0
                                        visible: machine.helpImagePath.length > 0 && machine.helpImageSide === "left"
                                        radius: 22
                                        color: Qt.rgba(0.14, 0.11, 0.09, 0.88)
                                        border.width: 1
                                        border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.30)

                                        Item {
                                            id: helpImageLeftClip
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            layer.enabled: true
                                            layer.smooth: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: helpImageLeftClip.width
                                                    height: helpImageLeftClip.height
                                                    radius: 21
                                                    color: "black"
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.rgba(0.08, 0.06, 0.05, 0.94)
                                            }

                                            Image {
                                                id: helpImageLeftRaw
                                                anchors.fill: parent
                                                source: machine.helpImageSource
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: true
                                                mipmap: true
                                                asynchronous: true
                                                visible: status === Image.Ready
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                height: parent.height * 0.42
                                                color: Qt.rgba(0.04, 0.03, 0.02, 0.18)
                                            }

                                            Column {
                                                anchors.centerIn: parent
                                                width: parent.width - 32
                                                spacing: 8
                                                visible: machine.helpImagePath.length > 0 && helpImageLeftRaw.status !== Image.Ready

                                                Text {
                                                    width: parent.width
                                                    text: "Immagine non disponibile"
                                                    color: win.textMain
                                                    font.pixelSize: 18
                                                    font.bold: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: machine.helpImagePath
                                                    color: win.textSub
                                                    font.pixelSize: 13
                                                    wrapMode: Text.WordWrap
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                anchors.margins: 12
                                                radius: 16
                                                visible: machine.helpImageCaption.length > 0
                                                color: Qt.rgba(0.10, 0.08, 0.06, 0.84)
                                                border.width: 1
                                                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                                                Text {
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    text: machine.helpImageCaption
                                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.88)
                                                    font.pixelSize: 12
                                                    wrapMode: Text.WordWrap
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: machine.helpImagePath.length > 0
                                        Layout.minimumHeight: machine.helpImagePath.length > 0 ? 220 : 0
                                        Layout.preferredHeight: machine.helpImagePath.length > 0
                                                                ? 280
                                                                : helpLeadText.implicitHeight + 36
                                        radius: 20
                                        color: Qt.rgba(0.92, 0.87, 0.79, 0.08)
                                        border.width: 1
                                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                                        Text {
                                            id: helpLeadText
                                            anchors.fill: parent
                                            anchors.margins: 18
                                            text: machine.helpLeadHtml
                                            textFormat: Text.RichText
                                            color: Qt.rgba(1.0, 1.0, 1.0, 0.96)
                                            font.pixelSize: 18
                                            wrapMode: Text.WordWrap
                                            lineHeight: 1.38
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: machine.helpImagePath.length > 0 && machine.helpImageSide === "right" ? 334 : 0
                                        Layout.preferredHeight: machine.helpImagePath.length > 0 && machine.helpImageSide === "right" ? 280 : 0
                                        visible: machine.helpImagePath.length > 0 && machine.helpImageSide === "right"
                                        radius: 22
                                        color: Qt.rgba(0.14, 0.11, 0.09, 0.88)
                                        border.width: 1
                                        border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.30)

                                        Item {
                                            id: helpImageRightClip
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            layer.enabled: true
                                            layer.smooth: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: helpImageRightClip.width
                                                    height: helpImageRightClip.height
                                                    radius: 21
                                                    color: "black"
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.rgba(0.08, 0.06, 0.05, 0.94)
                                            }

                                            Image {
                                                id: helpImageRightRaw
                                                anchors.fill: parent
                                                source: machine.helpImageSource
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: true
                                                mipmap: true
                                                asynchronous: true
                                                visible: status === Image.Ready
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                height: parent.height * 0.42
                                                color: Qt.rgba(0.04, 0.03, 0.02, 0.18)
                                            }

                                            Column {
                                                anchors.centerIn: parent
                                                width: parent.width - 32
                                                spacing: 8
                                                visible: machine.helpImagePath.length > 0 && helpImageRightRaw.status !== Image.Ready

                                                Text {
                                                    width: parent.width
                                                    text: "Immagine non disponibile"
                                                    color: win.textMain
                                                    font.pixelSize: 18
                                                    font.bold: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: machine.helpImagePath
                                                    color: win.textSub
                                                    font.pixelSize: 13
                                                    wrapMode: Text.WordWrap
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                anchors.margins: 12
                                                radius: 16
                                                visible: machine.helpImageCaption.length > 0
                                                color: Qt.rgba(0.10, 0.08, 0.06, 0.84)
                                                border.width: 1
                                                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)

                                                Text {
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    text: machine.helpImageCaption
                                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.88)
                                                    font.pixelSize: 12
                                                    wrapMode: Text.WordWrap
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: helpBodyCard
                            width: parent.width
                            visible: machine.helpBodyHtml.length > 0
                            implicitHeight: helpBodyColumn.implicitHeight + 40
                            radius: 24
                            color: Qt.rgba(0.34, 0.27, 0.22, 0.48)
                            border.width: 1
                            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.18)

                            Column {
                                id: helpBodyColumn
                                anchors.fill: parent
                                anchors.margins: 20

                                Text {
                                    id: helpBodyText
                                    width: parent.width
                                    text: machine.helpBodyHtml
                                    textFormat: Text.RichText
                                    color: Qt.rgba(1.0, 1.0, 1.0, 0.95)
                                    font.pixelSize: 17
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.42
                                }
                            }
                        }

                        Rectangle {
                            id: helpChecklistCard
                            width: parent.width
                            visible: machine.helpChecklistItems.length > 0
                            implicitHeight: helpChecklistColumn.implicitHeight + 40
                            radius: 24
                            color: Qt.rgba(0.45, 0.35, 0.27, 0.30)
                            border.width: 1
                            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.26)

                            ColumnLayout {
                                id: helpChecklistColumn
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 14

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "CHECKLIST OPERATIVA"
                                        color: win.textMain
                                        font.pixelSize: 18
                                        font.bold: true
                                    }

                                    Rectangle {
                                        radius: 12
                                        color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.18)
                                        border.width: 1
                                        border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.30)
                                        Layout.preferredWidth: 140
                                        Layout.preferredHeight: 34

                                        Text {
                                            anchors.centerIn: parent
                                            text: machine.helpChecklistCheckedCount() + " / " + machine.helpChecklistItems.length + " completati"
                                            color: win.textMain
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    GlassButton {
                                        w: 130
                                        h: 34
                                        textSize: 12
                                        text: "AZZERA"
                                        onClicked: machine.resetHelpChecklist()
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: machine.helpChecklistAlert.length > 0
                                    implicitHeight: helpChecklistAlertText.implicitHeight + 18
                                    radius: 14
                                    color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.16)
                                    border.width: 1
                                    border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.28)

                                    Text {
                                        id: helpChecklistAlertText
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        text: machine.helpChecklistAlert
                                        color: win.textMain
                                        font.pixelSize: 13
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                Repeater {
                                    model: machine.helpChecklistItems

                                    delegate: CheckBox {
                                        id: helpCheck
                                        required property int index
                                        required property string modelData
                                        Layout.fillWidth: true
                                        checked: index < machine.helpChecklistStates.length ? machine.helpChecklistStates[index] : false
                                        opacity: (index === 0 || checked || (index - 1 < machine.helpChecklistStates.length && machine.helpChecklistStates[index - 1])) ? 1.0 : 0.42
                                        hoverEnabled: false

                                        onToggled: {
                                            machine.setHelpChecklistState(index, checked)
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: machine.setHelpChecklistState(helpCheck.index, helpCheck.checked)
                                        }

                                        indicator: Rectangle {
                                            implicitWidth: 28
                                            implicitHeight: 28
                                            radius: 9
                                            y: helpCheck.topPadding + 2
                                            color: helpCheck.checked
                                                   ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.92)
                                                   : Qt.rgba(1.0, 1.0, 1.0, 0.05)
                                            border.width: 1
                                            border.color: helpCheck.checked
                                                          ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.95)
                                                          : Qt.rgba(1.0, 1.0, 1.0, 0.16)

                                            Text {
                                                anchors.centerIn: parent
                                                visible: helpCheck.checked
                                                text: "✓"
                                                color: Qt.rgba(0.16, 0.11, 0.08, 0.98)
                                                font.pixelSize: 17
                                                font.bold: true
                                            }
                                        }

                                        contentItem: Text {
                                            text: (helpCheck.index + 1) + ". " + helpCheck.modelData
                                            color: win.textMain
                                            font.pixelSize: 16
                                            wrapMode: Text.WordWrap
                                            leftPadding: helpCheck.indicator.width + 14
                                            rightPadding: 4
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        

        GlassCard {
            id: machineCard
            width: Math.min(1140, win.width - 90)
            height: Math.min(700, win.height - 36)
            anchors.centerIn: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "SIMULAZIONE ENIGMA"
                        color: win.textMain
                        font.pixelSize: win.fsTitle - 2
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    GlassButton {
                        w: 160
                        h: 44
                        text: "MISSIONE"
                        primary: win.simController && (win.simController.challengeActive || win.simController.challengeSolved)
                        onClicked: machine.openMission()
                    }

                    GlassButton {
                        w: 220
                        h: 44
                        text: "PROVA GUIDATA"
                        onClicked: machine.openHelpKey("simulationWalkthrough")
                    }

                    GlassButton {
                        w: 160
                        h: 44
                        text: "HOME"
                        onClicked: win.page = "home"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    GlassCard {
                        Layout.preferredWidth: 360
                        Layout.fillHeight: true
                        radius: 22
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "CONFIGURAZIONE"
                                    color: win.textMain
                                    font.pixelSize: win.fsSection - 8
                                    font.bold: true
                                }

                                InfoChip {
                                    onClicked: machine.openHelpKey("configuration")
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                            }

                            Text {
                                text: "ROTORI (SINISTRA - CENTRO - DESTRA)"
                                color: win.textSub
                                font.pixelSize: 12
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                GlassComboBox {
                                    id: rotorLeftBox
                                    model: machine.rotorOptions
                                    Layout.fillWidth: true
                                    onActivated: machine.applyRotorConfig()
                                }
                                GlassComboBox {
                                    id: rotorMiddleBox
                                    model: machine.rotorOptions
                                    Layout.fillWidth: true
                                    onActivated: machine.applyRotorConfig()
                                }
                                GlassComboBox {
                                    id: rotorRightBox
                                    model: machine.rotorOptions
                                    Layout.fillWidth: true
                                    onActivated: machine.applyRotorConfig()
                                }
                            }

                            Text {
                                text: "REFLECTOR"
                                color: win.textSub
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Item {
                                id: reflectorBox
                                Layout.fillWidth: true
                                implicitHeight: 40
                                property int currentIndex: 0
                                property string currentText: machine.reflectorOptions[currentIndex]

                                onCurrentIndexChanged: {
                                    if (win.simController && win.simController.reflector !== currentText) {
                                        win.simController.setReflector(currentText)
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 8

                                    Repeater {
                                        model: machine.reflectorOptions

                                        delegate: GlassButton {
                                            required property int index
                                            required property var modelData
                                            Layout.fillWidth: true
                                            h: 38
                                            text: modelData
                                            primary: reflectorBox.currentIndex === index
                                            onClicked: reflectorBox.currentIndex = index
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "POSIZIONI INIZIALI (ES. DDA)"
                                color: win.textSub
                                font.pixelSize: 12
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                GlassTextField {
                                    id: positionsField
                                    Layout.fillWidth: true
                                    placeholderText: "AAA"
                                    maximumLength: 3
                                }

                                GlassButton {
                                    w: 124
                                    h: 38
                                    text: "APPLICA"
                                    onClicked: {
                                        if (win.simController) {
                                            win.simController.setPositions(positionsField.text)
                                            positionsField.text = win.simController.startPositions
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: "PLUGBOARD"
                                    color: win.textSub
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                InfoChip {
                                    onClicked: machine.openHelpKey("plugboard")
                                }

                                Item { Layout.fillWidth: true }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                GlassTextField {
                                    id: plugA
                                    Layout.preferredWidth: 52
                                    maximumLength: 1
                                    horizontalAlignment: Text.AlignHCenter
                                    placeholderText: "A"
                                }
                                GlassTextField {
                                    id: plugB
                                    Layout.preferredWidth: 52
                                    maximumLength: 1
                                    horizontalAlignment: Text.AlignHCenter
                                    placeholderText: "B"
                                }
                                GlassButton {
                                    w: 126
                                    h: 36
                                    text: "COLLEGA"
                                    onClicked: {
                                        if (win.simController) {
                                            win.simController.addPlugPair(plugA.text, plugB.text)
                                            plugA.text = ""
                                            plugB.text = ""
                                            machine.forceActiveFocus()
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                GlassTextField {
                                    id: unplugLetter
                                    Layout.fillWidth: true
                                    maximumLength: 1
                                    horizontalAlignment: Text.AlignHCenter
                                    placeholderText: "Lettera da scollegare"
                                }

                                GlassButton {
                                    w: 126
                                    h: 36
                                    text: "RIMUOVI"
                                    onClicked: {
                                        if (win.simController) {
                                            win.simController.removePlugByLetter(unplugLetter.text)
                                            unplugLetter.text = ""
                                            machine.forceActiveFocus()
                                        }
                                    }
                                }
                            }

                            GlassButton {
                                w: 166
                                h: 34
                                text: "AZZERA PLUG"
                                onClicked: {
                                    if (win.simController) {
                                        win.simController.clearPlugboard()
                                        machine.forceActiveFocus()
                                    }
                                }
                            }

                            Text {
                                text: win.simController ? ("Connessioni: " + win.simController.plugboardPairs) : "Connessioni: -"
                                color: win.textMain
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pixelSize: 13
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                            }

                            Text {
                                text: "AZIONI RAPIDE"
                                color: win.textSub
                                font.pixelSize: 12
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                GlassButton {
                                    w: 156
                                    h: 38
                                    text: "RESET MACCHINA"
                                    onClicked: {
                                        if (win.simController) {
                                            win.simController.resetMachine()
                                            positionsField.text = win.simController.startPositions
                                            machine.forceActiveFocus()
                                        }
                                    }
                                }

                                GlassButton {
                                    w: 148
                                    h: 38
                                    text: "PULISCI STREAM"
                                    onClicked: {
                                        if (win.simController) {
                                            win.simController.clearStreams()
                                            machine.forceActiveFocus()
                                        }
                                    }
                                }
                            }

                        }
                    }

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 22
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: win.simController ? ("Posizioni: " + win.simController.currentPositions) : "Posizioni: ---"
                                    color: win.textMain
                                    font.pixelSize: 18
                                    font.bold: true
                                }

                                InfoChip {
                                    onClicked: machine.openHelpKey("liveState")
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: win.simController ? ("Reflector: " + win.simController.reflector) : "Reflector: -"
                                    color: win.textSub
                                    font.pixelSize: 14
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                spacing: 8

                                Text {
                                    text: "Passa col mouse sui rotori e usa la rotellina per cambiare lettera. Digita con la tastiera fisica."
                                    color: win.textSub
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                InfoChip {
                                    onClicked: machine.openHelpKey("controls")
                                }
                            }

                            GlassCard {
                                Layout.fillWidth: true
                                Layout.minimumHeight: 238
                                Layout.preferredHeight: 232
                                radius: 18
                                color: Qt.rgba(0.18, 0.14, 0.12, 0.28)
                                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 17
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.12)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    Repeater {
                                        model: 3

                                        delegate: Item {
                                            id: rotorDial
                                            required property int index
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Column {
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    text: machine.rotorLabels[rotorDial.index]
                                                    color: win.textSub
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }

                                                Rectangle {
                                                    id: rotorDisc
                                                    width: 176
                                                    height: 176
                                                    radius: width / 2
                                                    scale: rotorMouse.containsMouse ? 1.03 : 1.0
                                                    border.width: rotorMouse.containsMouse ? 2 : 1
                                                    border.color: rotorMouse.containsMouse
                                                                  ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.65)
                                                                  : Qt.rgba(1.0, 1.0, 1.0, 0.20)
                                                    antialiasing: true
                                                    gradient: Gradient {
                                                        GradientStop { position: 0.0; color: Qt.rgba(0.22, 0.18, 0.15, 0.94) }
                                                        GradientStop { position: 0.40; color: Qt.rgba(0.15, 0.12, 0.10, 0.95) }
                                                        GradientStop { position: 1.0; color: Qt.rgba(0.07, 0.06, 0.05, 0.98) }
                                                    }

                                                    Behavior on scale {
                                                        NumberAnimation {
                                                            duration: 140
                                                            easing.type: Easing.OutCubic
                                                        }
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        anchors.margins: -10
                                                        radius: width / 2
                                                        visible: rotorMouse.containsMouse
                                                        color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.10)
                                                        border.width: 1
                                                        border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22)
                                                        antialiasing: true
                                                    }

                                                    Item {
                                                        id: rotorRing
                                                        anchors.fill: parent
                                                        anchors.margins: 10
                                                        transformOrigin: Item.Center
                                                        rotation: -machine.alphaIndex(machine.rotorChar(rotorDial.index)) * (360 / 26)

                                                        Behavior on rotation {
                                                            NumberAnimation {
                                                                duration: 180
                                                                easing.type: Easing.OutCubic
                                                            }
                                                        }

                                                        Repeater {
                                                            model: 26

                                                            delegate: Item {
                                                                id: ringMark
                                                                required property int index
                                                                width: rotorRing.width
                                                                height: rotorRing.height
                                                                rotation: index * (360 / 26)

                                                                Rectangle {
                                                                    width: ringMark.index % 13 === 0 ? 3 : 2
                                                                    height: ringMark.index % 13 === 0 ? 12 : 7
                                                                    radius: width / 2
                                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                                    anchors.top: parent.top
                                                                    anchors.topMargin: 2
                                                                    color: ringMark.index === 0
                                                                           ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.95)
                                                                           : Qt.rgba(1.0, 1.0, 1.0, 0.40)
                                                                }

                                                                Text {
                                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                                    anchors.top: parent.top
                                                                    anchors.topMargin: 16
                                                                    text: machine.alphabetCharAt(ringMark.index)
                                                                    color: ringMark.index % 13 === 0
                                                                           ? Qt.rgba(win.textMain.r, win.textMain.g, win.textMain.b, 0.95)
                                                                           : Qt.rgba(win.textSub.r, win.textSub.g, win.textSub.b, 0.74)
                                                                    font.pixelSize: ringMark.index % 13 === 0 ? 11 : 9
                                                                    font.bold: ringMark.index % 13 === 0
                                                                    renderType: Text.NativeRendering
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        width: 24
                                                        height: 6
                                                        radius: 3
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        anchors.top: parent.top
                                                        anchors.topMargin: 7
                                                        color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.86)
                                                    }

                                                    Rectangle {
                                                        width: 24
                                                        height: 4
                                                        radius: 2
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        anchors.bottom: parent.bottom
                                                        anchors.bottomMargin: 9
                                                        color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.42)
                                                    }

                                                    Rectangle {
                                                        width: 100
                                                        height: 100
                                                        radius: 50
                                                        anchors.centerIn: parent
                                                        border.width: 1
                                                        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.17)
                                                        antialiasing: true
                                                        gradient: Gradient {
                                                            GradientStop { position: 0.0; color: Qt.rgba(0.32, 0.26, 0.21, 0.96) }
                                                            GradientStop { position: 1.0; color: Qt.rgba(0.14, 0.11, 0.09, 0.98) }
                                                        }

                                                        Rectangle {
                                                            width: 74
                                                            height: 56
                                                            radius: 12
                                                            anchors.centerIn: parent
                                                            border.width: 1
                                                            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.42)
                                                            antialiasing: true
                                                            gradient: Gradient {
                                                                GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.05, 0.05, 0.98) }
                                                                GradientStop { position: 1.0; color: Qt.rgba(0.13, 0.10, 0.08, 0.96) }
                                                            }

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: machine.rotorChar(rotorDial.index)
                                                                color: Qt.rgba(win.textMain.r, win.textMain.g, win.textMain.b, 0.98)
                                                                font.pixelSize: 46
                                                                font.bold: true
                                                                renderType: Text.NativeRendering
                                                            }
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: rotorMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        acceptedButtons: Qt.LeftButton
                                                        cursorShape: Qt.SizeVerCursor

                                                        onClicked: function(mouse) {
                                                            machine.wheelRotor(rotorDial.index, mouse.y <= (height / 2) ? 120 : -120)
                                                        }

                                                        onWheel: function(wheel) {
                                                            machine.wheelRotor(rotorDial.index, wheel.angleDelta.y)
                                                            wheel.accepted = true
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: "Encoder attivo"
                                                    color: win.accent
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 116
                                Layout.preferredHeight: 124
                                spacing: 10

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: Qt.rgba(0, 0, 0, 0.16)
                                    clip: true

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        RowLayout {
                                            width: parent.width

                                            Text {
                                                text: "INPUT STREAM"
                                                color: win.textSub
                                                font.pixelSize: 12
                                            }

                                            InfoChip {
                                                size: 20
                                                onClicked: machine.openHelpKey("inputStream")
                                            }

                                            Item { Layout.fillWidth: true }

                                            GlassButton {
                                                w: 76
                                                h: 28
                                                textSize: 11
                                                text: "SVUOTA"
                                                onClicked: {
                                                    if (win.simController) {
                                                        win.simController.clearInputStream()
                                                        machine.forceActiveFocus()
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            visible: !win.simController || win.simController.inputBuffer.length === 0
                                            text: "In attesa di input da tastiera fisica..."
                                            color: Qt.rgba(win.textSub.r, win.textSub.g, win.textSub.b, 0.85)
                                            font.italic: true
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }

                                        Text {
                                            visible: win.simController && win.simController.inputBuffer.length > 0
                                            text: win.simController ? win.simController.inputBuffer : ""
                                            color: win.textMain
                                            wrapMode: Text.WrapAnywhere
                                            width: parent.width
                                        }
                                    }
                                }

                                GlassCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: Qt.rgba(0, 0, 0, 0.16)
                                    clip: true

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        RowLayout {
                                            width: parent.width

                                            Text {
                                                text: "OUTPUT STREAM"
                                                color: win.textSub
                                                font.pixelSize: 12
                                            }

                                            InfoChip {
                                                size: 20
                                                onClicked: machine.openHelpKey("outputStream")
                                            }

                                            Item { Layout.fillWidth: true }

                                            GlassButton {
                                                w: 64
                                                h: 28
                                                textSize: 11
                                                text: "COPIA"
                                                onClicked: {
                                                    if (win.simController) {
                                                        win.simController.copyOutputToClipboard()
                                                        machine.forceActiveFocus()
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            visible: !win.simController || win.simController.outputBuffer.length === 0
                                            text: "Output non ancora generato."
                                            color: Qt.rgba(win.textSub.r, win.textSub.g, win.textSub.b, 0.85)
                                            font.italic: true
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                        }

                                        Text {
                                            visible: win.simController && win.simController.outputBuffer.length > 0
                                            text: win.simController ? win.simController.outputBuffer : ""
                                            color: win.textMain
                                            wrapMode: Text.WrapAnywhere
                                            width: parent.width
                                        }
                                    }
                                }
                            }

                            GlassCard {
                                Layout.fillWidth: true
                                Layout.fillHeight: false
                                Layout.minimumHeight: 98
                                Layout.preferredHeight: 108
                                Layout.maximumHeight: 128
                                radius: 14
                                color: Qt.rgba(0, 0, 0, 0.22)
                                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                                clip: true

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: "TRACCIA"
                                            color: win.textSub
                                            font.pixelSize: 12
                                            font.bold: true
                                        }

                                        InfoChip {
                                            size: 20
                                            onClicked: machine.openHelpKey("trace")
                                        }

                                        Item { Layout.fillWidth: true }
                                    }

                                    Text {
                                        text: win.simController ? ("Ultimo step: " + win.simController.lastStep) : "Ultimo step: -"
                                        color: win.textSub
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        font.pixelSize: 13
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                                    }

                                    Flickable {
                                        id: traceFlick
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        contentWidth: width
                                        contentHeight: traceText.implicitHeight
                                        ScrollBar.vertical: ThemeScrollBar {}

                                        function scrollToLatest() {
                                            contentY = Math.max(0, contentHeight - height)
                                        }

                                        Component.onCompleted: Qt.callLater(scrollToLatest)
                                        onContentHeightChanged: Qt.callLater(scrollToLatest)

                                        Text {
                                            id: traceText
                                            width: parent.width
                                            text: win.simController ? win.simController.traceLog : ""
                                            color: win.textMain
                                            font.pixelSize: 12
                                            wrapMode: Text.WordWrap
                                            onTextChanged: Qt.callLater(traceFlick.scrollToLatest)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: story
        anchors.fill: parent
        visible: win.page === "story"
        property bool manualSeek: false
        property bool videoPriming: false
        property int syncToleranceMs: 900
        property real pendingSeekPosition: 0

        function updateTextScroll(position) {
            if (storyPlayer.duration <= 0 || !flick) {
                return
            }
            var maxScroll = Math.max(0, flick.contentHeight - flick.height)
            var t = Math.max(0.0, Math.min(1.0, position / storyPlayer.duration))
            flick.contentY = maxScroll * t
        }

        function seekTo(position) {
            var target = Math.max(0, Math.min(position, storyPlayer.duration > 0 ? storyPlayer.duration : position))
            var wasPlaying = storyPlayer.playbackState === MediaPlayer.PlayingState
            storyPlayer.position = target
            storySeek.value = target
            story.updateTextScroll(target)
            if (win.storyVideoAssetUrl && win.storyVideoAssetUrl.toString().length > 0) {
                story.videoPriming = false
                storyVideoPlayer.position = target
                if (wasPlaying) {
                    storyVideoPlayer.play()
                } else {
                    storyVideoPlayer.pause()
                }
            }
        }

        function previewSeek(position) {
            var target = Math.max(0, Math.min(position, storyPlayer.duration > 0 ? storyPlayer.duration : position))
            story.pendingSeekPosition = target
            storySeek.value = target
            story.updateTextScroll(target)
            storySeekPreviewTimer.restart()
        }

        onVisibleChanged: {
            if (visible) {
                win.storyAudioPlaying = false
                if (win.storyVideoAssetUrl && win.storyVideoAssetUrl.toString().length > 0) {
                    storyVideoPlayer.position = 0
                    storyVideoPlayer.play()
                    story.videoPriming = true
                    storyVideoPrimeTimer.restart()
                }
            } else {
                win.storyAudioPlaying = false
                storyPlayer.stop()
                storyVideoPlayer.stop()
            }
        }

        AudioOutput { id: storyOut; volume: 1.0 }
        AudioOutput { id: storyVideoOut; volume: 0.0; muted: true }

        MediaPlayer {
            id: storyPlayer
            source: win.audioAssetUrl
            audioOutput: storyOut
        }

        MediaPlayer {
            id: storyVideoPlayer
            source: win.storyVideoAssetUrl
            audioOutput: storyVideoOut
            activeAudioTrack: -1
            videoOutput: storyVideoOutput
        }

        Timer {
            id: storyVideoPrimeTimer
            interval: 120
            repeat: false
            onTriggered: {
                if (story.videoPriming) {
                    storyVideoPlayer.pause()
                    storyVideoPlayer.position = 0
                    story.videoPriming = false
                }
            }
        }

        Timer {
            id: storySeekPreviewTimer
            interval: 180
            repeat: false
            onTriggered: {
                if (story.manualSeek) {
                    story.seekTo(story.pendingSeekPosition)
                }
            }
        }

        Connections {
            target: storyPlayer

            function onPositionChanged() {
                if (!story.manualSeek) {
                    storySeek.value = storyPlayer.position
                    story.updateTextScroll(storyPlayer.position)
                }
                win.syncStoryVideo(false)
            }

            function onPlaybackStateChanged() {
                if (!story.manualSeek) {
                    storySeek.value = storyPlayer.position
                    story.updateTextScroll(storyPlayer.position)
                }
                win.storyAudioPlaying = storyPlayer.playbackState === MediaPlayer.PlayingState
                if (storyPlayer.playbackState === MediaPlayer.PlayingState) {
                    win.syncStoryVideo(true)
                } else if (!story.videoPriming && storyVideoPlayer.playbackState === MediaPlayer.PlayingState) {
                    storyVideoPlayer.pause()
                }
            }
        }

        Connections {
            target: storyVideoPlayer

            function onMediaStatusChanged() {
                if (!story.videoPriming) {
                    if (storyPlayer.playbackState === MediaPlayer.PlayingState
                            && (storyVideoPlayer.mediaStatus === MediaPlayer.BufferedMedia
                                || storyVideoPlayer.mediaStatus === MediaPlayer.LoadedMedia
                                || storyVideoPlayer.mediaStatus === MediaPlayer.StalledMedia)) {
                        win.syncStoryVideo(true)
                    }
                    return
                }
                if (storyVideoPlayer.mediaStatus === MediaPlayer.LoadedMedia
                        || storyVideoPlayer.mediaStatus === MediaPlayer.BufferedMedia) {
                    storyVideoPlayer.pause()
                    storyVideoPlayer.position = 0
                    story.videoPriming = false
                }
            }
        }

        GlassCard {
            width: Math.min(1100, win.width - 120)
            height: Math.min(640, win.height - 140)
            anchors.centerIn: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "STORIA"
                        color: win.textMain
                        font.pixelSize: win.fsTitle - 4
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    GlassButton {
                        w: 160
                        h: 44
                        text: "HOME"
                        onClicked: {
                            win.storyAudioPlaying = false
                            storyPlayer.stop()
                            storyVideoPlayer.stop()
                            win.page = "home"
                        }
                    }
                }

                RowLayout {
                    id: storyContentRow
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: Math.floor(storyContentRow.width * 0.56)
                        radius: 22
                        color: Qt.rgba(0, 0, 0, 0.18)

                        Flickable {
                            id: flick
                            anchors.fill: parent
                            anchors.margins: 16
                            clip: true
                            contentWidth: width
                            contentHeight: storyTextItem.implicitHeight
                            ScrollBar.vertical: ThemeScrollBar {}

                            Text {
                                id: storyTextItem
                                width: flick.width
                                text: (typeof win.storyAssetText === "string" && win.storyAssetText.length > 0)
                                      ? win.storyAssetText
                                      : "story.txt non trovato."
                                color: win.textMain
                                font.pixelSize: 18
                                wrapMode: Text.WordWrap
                                lineHeight: win.bodyLine
                            }
                        }
                    }

                    GlassCard {
                        property int side: Math.max(240, Math.min(storyContentRow.height, Math.floor(storyContentRow.width * 0.44)))
                        Layout.preferredWidth: side
                        Layout.preferredHeight: side
                        Layout.maximumWidth: side
                        Layout.maximumHeight: side
                        Layout.minimumWidth: 240
                        Layout.minimumHeight: 240
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        radius: 22
                        color: Qt.rgba(0, 0, 0, 0.18)

                        Item {
                            id: videoSquare
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 20, parent.height - 20)
                            height: width

                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(0.0, 0.0, 0.0, 0.40)
                                antialiasing: true
                            }

                            Rectangle {
                                id: videoClip
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: 17
                                color: Qt.rgba(0, 0, 0, 0.30)
                                border.width: 1
                                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                                antialiasing: true
                                clip: true

                                VideoOutput {
                                    id: storyVideoOutput
                                    anchors.fill: parent
                                    fillMode: VideoOutput.PreserveAspectFit
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !(win.storyVideoAssetUrl && win.storyVideoAssetUrl.toString().length > 0)
                                    text: "Video non trovato in ui/assets"
                                    color: win.textSub
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: win.formatAudioTime(storyPlayer.position)
                            color: win.textSub
                            font.pixelSize: 13
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: win.formatAudioTime(storyPlayer.duration)
                            color: win.textSub
                            font.pixelSize: 13
                        }
                    }

                    Slider {
                        id: storySeek
                        Layout.fillWidth: true
                        from: 0
                        to: Math.max(1, storyPlayer.duration)
                        value: 0
                        enabled: storyPlayer.duration > 0

                        onPressedChanged: {
                            if (pressed) {
                                story.manualSeek = true
                            } else {
                                storySeekPreviewTimer.stop()
                                story.seekTo(value)
                                story.manualSeek = false
                                win.syncStoryVideo(true)
                            }
                        }

                        onMoved: {
                            story.previewSeek(value)
                        }

                        background: Rectangle {
                            x: storySeek.leftPadding
                            y: storySeek.topPadding + storySeek.availableHeight / 2 - height / 2
                            width: storySeek.availableWidth
                            height: 8
                            radius: 4
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.15)

                            Rectangle {
                                width: storySeek.visualPosition * parent.width
                                height: parent.height
                                radius: parent.radius
                                color: win.accent
                            }
                        }

                        handle: Rectangle {
                            x: storySeek.leftPadding + storySeek.visualPosition * (storySeek.availableWidth - width)
                            y: storySeek.topPadding + storySeek.availableHeight / 2 - height / 2
                            implicitWidth: 16
                            implicitHeight: 16
                            radius: 8
                            color: storySeek.pressed ? Qt.darker(win.accent, 1.15) : Qt.lighter(win.accent, 1.04)
                            border.width: 1
                            border.color: Qt.rgba(0.0, 0.0, 0.0, 0.35)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    GlassButton {
                        w: 200
                        h: 52
                        text: (storyPlayer.playbackState === MediaPlayer.PlayingState) ? "PAUSA" : "PLAY"
                        primary: true
                        onClicked: {
                            if (storyPlayer.playbackState === MediaPlayer.PlayingState) {
                                storyPlayer.pause()
                                if (win.storyVideoAssetUrl && win.storyVideoAssetUrl.toString().length > 0) {
                                    storyVideoPlayer.pause()
                                }
                            } else {
                                storyPlayer.play()
                                if (win.storyVideoAssetUrl && win.storyVideoAssetUrl.toString().length > 0) {
                                    storyVideoPlayer.position = storyPlayer.position
                                    storyVideoPlayer.play()
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        Timer {
            interval: 650
            running: storyPlayer.playbackState === MediaPlayer.PlayingState
            repeat: true
            onTriggered: {
                win.syncStoryVideo(false)
                story.updateTextScroll(storyPlayer.position)
            }
        }
    }
}
