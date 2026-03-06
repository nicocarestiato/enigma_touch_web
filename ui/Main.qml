pragma ComponentBehavior: Bound

import QtQuick 6.7
import QtQuick.Controls 6.7
import QtQuick.Layouts 6.7
import QtQuick.Window 6.7
import QtMultimedia 6.7
import Qt5Compat.GraphicalEffects

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
    property url sottofondoAssetUrl: Qt.resolvedUrl("assets/sottofondo.mp3")
    property url sottofondoSpariAssetUrl: Qt.resolvedUrl("assets/sottofondospari.mp3")
    property url bgMusicSourceUrl: soundtrackMode === "war" ? sottofondoSpariAssetUrl : sottofondoAssetUrl
    property bool galleryExpanded: false
    property url galleryExpandedSource: ""

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

        delegate: ItemDelegate {
            id: comboDelegate
            required property int index
            required property var modelData
            width: cb.width
            text: modelData
            highlighted: cb.highlightedIndex === comboDelegate.index
            contentItem: Text {
                text: comboDelegate.text
                color: win.textMain
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: comboDelegate.highlighted ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.22) : Qt.rgba(0.11, 0.09, 0.08, 0.92)
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
            y: cb.height + 4
            width: cb.width
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 260)
            padding: 4
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: cb.delegateModel
                currentIndex: cb.highlightedIndex
            }
            background: Rectangle {
                radius: 12
                color: Qt.rgba(0.09, 0.08, 0.07, 0.94)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
            }
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
        color: Qt.rgba(win.bgTint.r, win.bgTint.g, win.bgTint.b, 0.25)
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Math.max(0.0, (1.0 - win.uiBrightness) * 0.70)
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
        width: Math.min(760, win.width - 80)
        height: Math.min(620, win.height - 80)
        background: GlassCard {}

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12

            Text {
                text: "CREDITS"
                color: win.textMain
                font.pixelSize: 22
                font.bold: true
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: creditsBody.implicitHeight

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
                    font.pixelSize: 14
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                GlassButton {
                    w: 140
                    h: 44
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
        width: Math.min(640, win.width - 70)
        height: Math.min(620, win.height - 70)
        Overlay.modal: Rectangle { color: Qt.rgba(0.0, 0.0, 0.0, 0.58) }
        background: Rectangle {
            radius: 26
            color: Qt.rgba(0.05, 0.04, 0.03, 0.95)
            border.width: 1
            border.color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.28)
            antialiasing: true
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 8

            Text {
                text: "SETTINGS"
                color: win.textMain
                font.pixelSize: 24
                font.bold: true
            }

            Text {
                text: "Audio, atmosfera e display"
                color: win.textSub
                font.pixelSize: 13
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 156
                radius: 16
                color: Qt.rgba(0.08, 0.07, 0.06, 0.94)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 7

                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "Musica sottofondo"
                            color: win.textMain
                            font.pixelSize: 14
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
                        spacing: 8

                        GlassButton {
                            w: Math.max(130, Math.floor((settingsThemeRow.width - settingsThemeRow.spacing) / 2))
                            h: 38
                            textSize: 12
                            text: "TEMA CLASSICO"
                            primary: win.soundtrackMode === "classic"
                            onClicked: win.setSoundtrack("classic", true)
                        }

                        GlassButton {
                            w: Math.max(130, Math.floor((settingsThemeRow.width - settingsThemeRow.spacing) / 2))
                            h: 38
                            textSize: 12
                            text: "TEMA IMMERSIVO"
                            primary: win.soundtrackMode === "war"
                            onClicked: win.setSoundtrack("war", true)
                        }
                    }

                    Text {
                        text: "Volume base: " + Math.round(win.bgMusicVolume * 100) + "%"
                        color: win.textSub
                        font.pixelSize: 12
                    }

                    Slider {
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
                Layout.preferredHeight: 96
                radius: 16
                color: Qt.rgba(0.08, 0.07, 0.06, 0.94)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 7

                    Text {
                        text: "Riduzione in Storia: " + Math.round((1 - win.storyDuckingFactor) * 100) + "%"
                        color: win.textMain
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Slider {
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
                Layout.preferredHeight: 122
                radius: 16
                color: Qt.rgba(0.08, 0.07, 0.06, 0.94)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 7

                    Text {
                        text: "Luminosita interfaccia: " + Math.round(win.uiBrightness * 100) + "%"
                        color: win.textMain
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Slider {
                        width: parent.width
                        from: 0.45
                        to: 1.0
                        value: win.uiBrightness
                        onValueChanged: win.uiBrightness = value
                    }

                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                GlassButton {
                    w: 178
                    h: 42
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
                    w: 120
                    h: 42
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
        font.pixelSize: 13
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
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
            width: Math.min(920, win.width - 140)
            spacing: 14
            visible: !win.disruptionBlackPhase

            Text {
                text: win.disruptionTitle
                color: Qt.rgba(1.0, 0.94, 0.86, 0.98)
                font.pixelSize: 30
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.55)
            }

            Text {
                text: win.disruptionText
                color: Qt.rgba(1.0, 1.0, 1.0, 0.90)
                font.pixelSize: 18
                lineHeight: 1.24
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            Row {
                spacing: 8
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: 3
                    Rectangle {
                        id: pulseDot
                        required property int index
                        width: 9
                        height: 9
                        radius: 5
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
                font.pixelSize: 13
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
            width: Math.min(900, win.width - 120)
            spacing: 14

            Text {
                text: "DISCLAIMER"
                color: Qt.rgba(1.0, 1.0, 1.0, 0.96)
                font.pixelSize: 30
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            Text {
                text: "Questo applicativo non si propone come ricostruzione storica perfetta.\n\nEnigma Touch e' una ricostruzione didattica e divulgativa: alcune parti sono semplificate per facilitare comprensione, utilizzo e apprendimento.\n\nLe configurazioni, i tempi operativi e alcune dinamiche narrative sono adattate per finalita formative.\n\nIl progetto non intende glorificare eventi bellici: l'obiettivo e' spiegare principi storici e crittografici in modo accessibile.\n\nEssendo una ricostruzione indipendente a scopo didattico, possono verificarsi occasionali malfunzionamenti o comportamenti non previsti."
                color: Qt.rgba(1.0, 1.0, 1.0, 0.85)
                font.pixelSize: 17
                lineHeight: 1.22
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            GlassButton {
                text: "CONTINUA"
                primary: true
                w: 210
                h: 50
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
            width: Math.min(980, win.width - 120)
            height: Math.min(500, win.height - 120)
            anchors.centerIn: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 12

                Text {
                    text: "SCEGLI ATMOSFERA SONORA"
                    color: win.textMain
                    font.pixelSize: 32
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: "Seleziona la colonna sonora con cui vuoi vivere l'esperienza."
                    color: win.textSub
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 18
                        color: Qt.rgba(0, 0, 0, 0.20)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            Text {
                                text: "IMMERSIVA"
                                color: win.textMain
                                font.pixelSize: 18
                                font.bold: true
                            }

                            Text {
                                text: "Scenario bellico: ambiente piu intenso e drammatico."
                                color: win.textSub
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item { Layout.fillHeight: true }

                            GlassButton {
                                text: "TRACCIA IMMERSIVA"
                                primary: true
                                w: 240
                                h: 44
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
                            anchors.margins: 16
                            spacing: 10

                            Text {
                                text: "CLASSICA"
                                color: win.textMain
                                font.pixelSize: 18
                                font.bold: true
                            }

                            Text {
                                text: "Rivisitazione avventura piu generica, meno impattante."
                                color: win.textSub
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item { Layout.fillHeight: true }

                            GlassButton {
                                text: "TRACCIA CLASSICA"
                                primary: true
                                w: 220
                                h: 44
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
            width: Math.min(900, win.width - 120)
            height: 320
            anchors.centerIn: parent

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: "ENIGMA TOUCH"
                    color: win.textMain
                    font.pixelSize: 44
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 1.03; duration: 850; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.03; to: 1.0; duration: 850; easing.type: Easing.InOutQuad }
                    }
                }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 180
                    height: 78

                    Repeater {
                        model: 3
                        Rectangle {
                            id: ring
                            required property int index
                            width: 64 + (index * 26)
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
                    spacing: 10

                    Repeater {
                        model: 5
                        Rectangle {
                            id: dot
                            required property int index
                            width: 10
                            height: 10
                            radius: 5
                            color: win.textSub

                            SequentialAnimation on y {
                                loops: Animation.Infinite
                                PauseAnimation { duration: dot.index * 110 }
                                NumberAnimation { to: -9; duration: 260; easing.type: Easing.OutCubic }
                                NumberAnimation { to: 0; duration: 300; easing.type: Easing.InCubic }
                                PauseAnimation { duration: 180 }
                            }
                        }
                    }
                }

                Rectangle {
                    width: Math.min(620, bootPage.width - 220)
                    height: 14
                    radius: 7
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
                        width: 72
                        height: parent.height
                        radius: parent.radius
                        x: (parent.width + width) * win.bootProgress - width
                        color: Qt.rgba(1.0, 1.0, 1.0, 0.20)
                    }
                }

                Text {
                    text: win.bootStatusText()
                    color: win.textSub
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: Math.round(win.bootProgress * 100) + "%"
                    color: Qt.rgba(win.textMain.r, win.textMain.g, win.textMain.b, 0.92)
                    font.pixelSize: 13
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
            width: Math.min(980, win.width - 140)
            height: Math.min(610, win.height - 120)
            anchors.centerIn: parent
            property int galleryHeight: Math.max(200, Math.min(260, Math.floor(height * 0.45)))
            property int galleryCardSize: galleryHeight
            property int galleryGap: 12
            property int galleryViewportWidth: Math.min(width - 36, Math.max(560, Math.floor(width * 0.90)))

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 8

                Column {
                    width: parent.width
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "ENIGMA TOUCH"
                        color: win.textMain
                        font.pixelSize: win.fsTitle
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Una reinterpretazione contemporanea della macchina Enigma.\nInterfaccia moderna, principio crittografico autentico."
                        color: win.textSub
                        font.pixelSize: win.fsLabel + 1
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: win.bodyLine
                        width: Math.min(parent.width, 760)
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
                                property int frameRadius: 22

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
                    h: 52
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
                        Layout.preferredWidth: 420
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
                                w: 300
                                h: 54
                                Layout.alignment: Qt.AlignHCenter
                                onClicked: win.page = "story"
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
        property string helpBody: ""
        property string helpImageFile: ""
        property url helpImageSource: ""

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

        function openHelp(title, body, imageFile) {
            machine.helpTitle = title
            machine.helpBody = body
            machine.helpImageFile = imageFile ? imageFile : ""
            machine.helpImageSource = machine.helpImageFile.length > 0
                                     ? Qt.resolvedUrl("assets/help/" + machine.helpImageFile)
                                     : ""
            helpPopup.open()
        }

        onVisibleChanged: {
            if (visible) {
                syncFromController()
                machine.forceActiveFocus()
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

        Popup {
            id: helpPopup
            modal: true
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            x: (win.width - width) / 2
            y: (win.height - height) / 2
            width: Math.min(700, win.width - 90)
            height: Math.min(560, win.height - 90)
            padding: 0
            Overlay.modal: Rectangle {
                color: Qt.rgba(0.0, 0.0, 0.0, 0.62)
            }
            background: Rectangle {
                radius: 22
                antialiasing: true
                color: Qt.rgba(0.09, 0.07, 0.06, 0.94)
                border.width: 1
                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.18)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 21
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0.0, 0.0, 0.0, 0.35)
                }
            }

            contentItem: ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: machine.helpTitle
                        color: win.textMain
                        font.pixelSize: 24
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    radius: 16
                    color: Qt.rgba(0.0, 0.0, 0.0, 0.42)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                    antialiasing: true
                    clip: true

                    Image {
                        id: helpImage
                        anchors.fill: parent
                        anchors.margins: 8
                        source: machine.helpImageSource
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        visible: machine.helpImageFile.length > 0 && status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 26
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: win.textSub
                        font.pixelSize: 14
                        text: machine.helpImageFile.length > 0
                              ? ("Immagine guida non trovata.\nAggiungi " + machine.helpImageFile + " in ui/assets/help")
                              : "Area immagine facoltativa.\nSe vuoi, qui mostriamo un esempio visivo."
                        visible: !helpImage.visible
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.rgba(0.0, 0.0, 0.0, 0.34)
                    border.width: 1
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        contentWidth: width
                        contentHeight: helpBodyText.implicitHeight

                        Text {
                            id: helpBodyText
                            width: parent.width
                            text: machine.helpBody
                            color: Qt.rgba(1.0, 1.0, 1.0, 0.95)
                            font.pixelSize: 16
                            wrapMode: Text.WordWrap
                            lineHeight: 1.3
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
                                    onClicked: machine.openHelp(
                                        "Configurazione macchina",
                                        "Qui imposti tutti i parametri iniziali della simulazione: ordine dei rotori, tipo di reflector, posizioni di partenza e plugboard.\n\nOgni modifica influisce sulla cifratura finale.",
                                        "configurazione.png"
                                    )
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

                            GlassComboBox {
                                id: reflectorBox
                                model: machine.reflectorOptions
                                Layout.fillWidth: true
                                onActivated: {
                                    if (win.simController) {
                                        win.simController.setReflector(currentText)
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
                                    onClicked: machine.openHelp(
                                        "Plugboard",
                                        "Il plugboard scambia coppie di lettere prima e dopo i rotori.\n\nEsempio: A-B significa che A diventa B e B diventa A.\nE' uno dei fattori che aumentano molto la complessita della chiave.",
                                        "infoplugboard.png"
                                    )
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

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 12
                                color: Qt.rgba(0.0, 0.0, 0.0, 0.18)
                                border.width: 1
                                border.color: Qt.rgba(1.0, 1.0, 1.0, 0.10)
                                clip: true

                                Text {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    text: win.simController ? win.simController.statusMessage : "Controller non disponibile."
                                    color: win.textSub
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    font.pixelSize: 12
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
                                    onClicked: machine.openHelp(
                                        "Stato in tempo reale",
                                        "Qui vedi la posizione corrente dei rotori durante la digitazione.\n\nA destra vedi anche il reflector attivo.",
                                        "stato.png"
                                    )
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
                                    onClicked: machine.openHelp(
                                        "Comandi rapidi",
                                        "Rotori: passa sopra il disco e usa la rotellina del mouse, oppure clicca nella meta alta/bassa per ruotare.\nTastiera fisica: ogni lettera inserita avanza i rotori e genera output.\nESC: torna alla Home.",
                                        "controlli.png"
                                    )
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
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }

                                                Rectangle {
                                                    id: rotorDisc
                                                    width: 176
                                                    height: 176
                                                    radius: width / 2
                                                    scale: rotorMouse.containsMouse ? 1.03 : 1.0
                                                    border.width: 1
                                                    border.color: rotorMouse.containsMouse
                                                                  ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.55)
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
                                                    text: "Rotella o click (su/giu)"
                                                    color: win.textSub
                                                    font.pixelSize: 11
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
                                                onClicked: machine.openHelp(
                                                    "Input stream",
                                                    "Qui compare il testo inserito con la tastiera fisica.\n\nIl pulsante SVUOTA cancella solo l'input mostrato, senza cambiare configurazione della macchina.",
                                                    "input-stream.png"
                                                )
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
                                                onClicked: machine.openHelp(
                                                    "Output stream",
                                                    "Qui compare la cifratura prodotta in tempo reale.\n\nCOPIA mette l'output negli appunti per incollarlo dove vuoi.",
                                                    "output-stream.png"
                                                )
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
                                            onClicked: machine.openHelp(
                                                "Traccia e ultimo step",
                                                "Ultimo step mostra la trasformazione piu recente.\n\nLa traccia sotto registra gli eventi principali: cambi configurazione, step di cifratura e reset.",
                                                "traccia.png"
                                            )
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
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        contentWidth: width
                                        contentHeight: traceText.implicitHeight

                                        Text {
                                            id: traceText
                                            width: parent.width
                                            text: win.simController ? win.simController.traceLog : ""
                                            color: win.textMain
                                            font.pixelSize: 12
                                            wrapMode: Text.WordWrap
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

        Connections {
            target: storyPlayer

            function onPositionChanged() {
                if (!story.manualSeek) {
                    storySeek.value = storyPlayer.position
                }
            }

            function onPlaybackStateChanged() {
                if (!story.manualSeek) {
                    storySeek.value = storyPlayer.position
                }
                win.storyAudioPlaying = storyPlayer.playbackState === MediaPlayer.PlayingState
            }
        }

        Connections {
            target: storyVideoPlayer

            function onMediaStatusChanged() {
                if (!story.videoPriming) {
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

                                VideoOutput {
                                    id: storyVideoOutput
                                    anchors.fill: parent
                                    fillMode: VideoOutput.PreserveAspectFit
                                    visible: false
                                }

                                Rectangle {
                                    id: storyVideoMask
                                    anchors.fill: parent
                                    radius: videoClip.radius
                                    color: "black"
                                    visible: false
                                    antialiasing: true
                                }

                                OpacityMask {
                                    anchors.fill: storyVideoOutput
                                    source: storyVideoOutput
                                    maskSource: storyVideoMask
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
                                storyPlayer.position = value
                                story.manualSeek = false
                            }
                        }

                        onMoved: {
                            storyPlayer.position = value
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
            interval: 90
            running: storyPlayer.playbackState === MediaPlayer.PlayingState
            repeat: true
            onTriggered: {
                if (win.storyVideoAssetUrl && win.storyVideoAssetUrl.toString().length > 0
                        && storyVideoPlayer.playbackState === MediaPlayer.PlayingState) {
                    var drift = Math.abs(storyVideoPlayer.position - storyPlayer.position)
                    if (drift > 120) {
                        storyVideoPlayer.position = storyPlayer.position
                    }
                }
                if (storyPlayer.duration > 0) {
                    var maxScroll = Math.max(0, flick.contentHeight - flick.height)
                    var t = storyPlayer.position / storyPlayer.duration
                    flick.contentY = maxScroll * t
                }
            }
        }
    }
}
