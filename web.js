/* global document, window, fetch, requestAnimationFrame, cancelAnimationFrame */

(function () {
  "use strict";

  const state = {
    page: "disclaimer",
    soundtrackMode: "classic",
    bgMusicEnabled: true,
    bgMusicVolume: 0.5,
    bgStartupFade: 0,
    storyDuckingFactor: 0.2,
    storyAudioPlaying: false,
    emergencyMusicFactor: 1.0,
    uiBrightness: 1.0,
    disruptionEnabled: true,
    disruptionOccurred: false,
    disruptionActive: false,
    disruptionTimer: null,
    disruptionBlackTimer: null,
    disruptionMessageTimer: null,
    disruptionResumeStoryAudio: false,
    disruptionResumeStoryVideo: false,
    bootMs: 10000,
    bootHoldMs: 2000,
    bootPause48Ms: 1000,
    bootPause60Ms: 3000,
    bootPause98Ms: 1000,
    bootRaf: null,
    rotors: ["I", "II", "III"],
    reflector: "B",
    startPositions: "AAA",
    positions: "AAA",
    plugboardPairs: [],
    inputStream: "",
    outputStream: "",
    traceLog: [],
    lastStep: "-",
    mission: {
      active: false,
      solved: false,
      attempts: 0,
      score: 0,
      startedAt: 0,
      elapsedTimer: null,
      plain: "",
      cipher: "",
      solution: "AAA",
      config: "Rotori I-II-III | Reflector B | Plugboard nessuna coppia",
      status: "Nessuna missione attiva.",
    },
    apiBase:
      (window.localStorage && window.localStorage.getItem("enigma_api_base")) ||
      "https://enigma-touch-web-api.onrender.com",
    galleryOffset: 0,
    gallerySingleWidth: 0,
    galleryLastTick: 0,
    galleryPaused: false,
    galleryRaf: null,
    storySeekManual: false,
    storyRaf: null,
  };

  const tracks = {
    classic: "ui/assets/sottofondo.mp3",
    war: "ui/assets/sottofondospari.mp3",
  };

  const pageIds = ["disclaimer", "soundtrack", "boot", "intro", "home", "machine", "story"];
  const q = (id) => document.getElementById(id);
  const pages = new Map(pageIds.map((id) => [id, q("page-" + id)]));

  const pageFade = q("page-fade");
  const byline = q("byline");
  const topButtons = q("top-buttons");
  const brightnessLayer = q("brightness-layer");

  const bgMusic = q("bg-music");
  const storyAudio = q("story-audio");
  const storyVideo = q("story-video");
  const storyTextScroll = q("story-text-scroll");
  const storySeek = q("story-seek");

  const disruptionOverlay = q("disruption-overlay");
  const disruptionBlack = q("disruption-black");
  const disruptionMessage = q("disruption-message");
  const disruptionTitle = q("disruption-title");
  const disruptionText = q("disruption-text");

  const bootFill = q("boot-fill");
  const bootGlow = q("boot-glow");
  const bootStatus = q("boot-status");
  const bootPercent = q("boot-percent");

  const creditsModal = q("credits-modal");
  const settingsModal = q("settings-modal");
  const galleryModal = q("gallery-modal");
  const galleryModalImage = q("gallery-modal-image");
  const missionModal = q("mission-modal");

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  function pickOne(list) {
    return list[randomInt(0, list.length - 1)];
  }

  function pickDistinct(list, count) {
    const src = list.slice();
    const out = [];
    while (src.length > 0 && out.length < count) {
      const idx = randomInt(0, src.length - 1);
      out.push(src[idx]);
      src.splice(idx, 1);
    }
    return out;
  }

  function formatList(values) {
    if (values.length === 0) return "";
    if (values.length === 1) return values[0];
    if (values.length === 2) return values[0] + " e " + values[1];
    return values.slice(0, -1).join(", ") + " e " + values[values.length - 1];
  }

  function formatTime(seconds) {
    if (!Number.isFinite(seconds) || seconds <= 0) return "00:00";
    const total = Math.floor(seconds);
    const mm = Math.floor(total / 60);
    const ss = total % 60;
    return String(mm) + ":" + String(ss).padStart(2, "0");
  }

  function showModal(modal) {
    modal.classList.remove("hidden");
  }

  function hideModal(modal) {
    modal.classList.add("hidden");
  }

  function updateOverlayVisibility() {
    document.body.dataset.page = state.page;

    const hideTop = state.page === "disclaimer" || state.page === "soundtrack";
    topButtons.style.display = hideTop ? "none" : "flex";

    const hideByline =
      state.page === "intro" ||
      state.page === "machine" ||
      state.page === "story" ||
      state.page === "disclaimer" ||
      state.page === "soundtrack";
    byline.style.display = hideByline ? "none" : "block";
  }

  function updateMachineScale() {
    const mobileMachine = window.matchMedia("(max-width: 760px), (pointer: coarse) and (max-width: 1024px)").matches;
    if (mobileMachine) {
      document.documentElement.style.setProperty("--machine-width", "100%");
      document.documentElement.style.setProperty("--machine-height", "auto");
      return;
    }

    const machineWidth = Math.min(1544, Math.max(980, window.innerWidth - 48));
    const machineHeight = Math.min(720, Math.max(620, window.innerHeight - 22));
    document.documentElement.style.setProperty("--machine-width", `${machineWidth}px`);
    document.documentElement.style.setProperty("--machine-height", `${machineHeight}px`);
  }

  function setPage(next) {
    if (!pages.has(next) || next === state.page) return;

    pageFade.classList.add("active");
    window.setTimeout(() => {
      pages.get(state.page).classList.remove("active");
      state.page = next;
      pages.get(state.page).classList.add("active");
      updateOverlayVisibility();

      if (next === "boot") {
        startBootSequence();
      }

      if (next === "story") {
        updateStoryUiFromTime();
        startStoryTicker();
        syncStoryDucking(true);
      } else {
        syncStoryDucking(false);
      }

      window.setTimeout(() => pageFade.classList.remove("active"), 140);
    }, 120);
  }

  function bootStatusText(progress) {
    if (progress < 0.2) return "Inizializzazione interfaccia...";
    if (progress < 0.45) return "Caricamento risorse grafiche...";
    if (progress < 0.7) return "Sincronizzazione moduli Enigma...";
    if (progress < 0.92) return "Ottimizzazione esperienza...";
    return "Pronto.";
  }

  function progressAtElapsed(elapsed) {
    const travel =
      state.bootMs -
      state.bootHoldMs -
      state.bootPause48Ms -
      state.bootPause60Ms -
      state.bootPause98Ms;

    const seg1 = state.bootHoldMs;
    const seg2 = seg1 + Math.round(travel * 0.48);
    const seg3 = seg2 + state.bootPause48Ms;
    const seg4 = seg3 + Math.round(travel * 0.12);
    const seg5 = seg4 + state.bootPause60Ms;
    const seg6 = seg5 + Math.round(travel * 0.38);
    const seg7 = seg6 + state.bootPause98Ms;
    const seg8 = state.bootMs;

    if (elapsed <= seg1) return 0;
    if (elapsed <= seg2) return ((elapsed - seg1) / Math.max(1, seg2 - seg1)) * 0.48;
    if (elapsed <= seg3) return 0.48;
    if (elapsed <= seg4) return 0.48 + ((elapsed - seg3) / Math.max(1, seg4 - seg3)) * 0.12;
    if (elapsed <= seg5) return 0.6;
    if (elapsed <= seg6) return 0.6 + ((elapsed - seg5) / Math.max(1, seg6 - seg5)) * 0.38;
    if (elapsed <= seg7) return 0.98;
    if (elapsed <= seg8) return 0.98 + ((elapsed - seg7) / Math.max(1, seg8 - seg7)) * 0.02;
    return 1.0;
  }

  function updateBootUi(progress) {
    const pct = Math.round(progress * 100);
    bootFill.style.width = pct + "%";
    bootGlow.style.left = "calc(" + pct + "% - 72px)";
    bootPercent.textContent = pct + "%";
    bootStatus.textContent = bootStatusText(progress);
  }

  function startBootSequence() {
    if (state.bootRaf) {
      cancelAnimationFrame(state.bootRaf);
      state.bootRaf = null;
    }
    updateBootUi(0);
    const start = performance.now();
    const tick = (now) => {
      const elapsed = now - start;
      const progress = clamp(progressAtElapsed(elapsed), 0, 1);
      updateBootUi(progress);
      if (elapsed >= state.bootMs) {
        state.bootRaf = null;
        setPage("intro");
        return;
      }
      state.bootRaf = requestAnimationFrame(tick);
    };
    state.bootRaf = requestAnimationFrame(tick);
  }

  function animateValue(setter, from, to, durationMs, done) {
    const start = performance.now();
    const step = (now) => {
      const t = clamp((now - start) / Math.max(1, durationMs), 0, 1);
      const eased = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      setter(from + (to - from) * eased);
      if (t >= 1) {
        if (done) done();
        return;
      }
      requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }

  function updateBgMusicVolume() {
    const raw =
      (state.bgMusicEnabled ? state.bgMusicVolume : 0) *
      state.bgStartupFade *
      (state.storyAudioPlaying ? state.storyDuckingFactor : 1) *
      state.emergencyMusicFactor;
    bgMusic.volume = clamp(raw, 0, 1);
  }

  function setSoundtrack(mode, restartPlayback) {
    state.soundtrackMode = mode === "war" ? "war" : "classic";
    bgMusic.src = tracks[state.soundtrackMode];
    if (restartPlayback && state.bgMusicEnabled) {
      bgMusic.currentTime = 0;
      bgMusic.play().catch(() => {});
    }
    syncSettingsUi();
  }

  function startMusicWithFade() {
    bgMusic.src = tracks[state.soundtrackMode];
    state.bgStartupFade = 0;
    updateBgMusicVolume();
    bgMusic.currentTime = 0;
    bgMusic.play().catch(() => {});
    animateValue(
      (v) => {
        state.bgStartupFade = v;
        updateBgMusicVolume();
      },
      0,
      1,
      4000
    );
  }

  function openGalleryModal(src) {
    if (!src) return;
    galleryModalImage.src = src;
    showModal(galleryModal);
  }

  function setupGallery() {
    const track = q("gallery-track");
    track.innerHTML = "";

    const inner = document.createElement("div");
    inner.className = "gallery-inner";
    const sources = [];
    for (let i = 1; i <= 8; i += 1) {
      sources.push("ui/assets/gallery/" + i + ".png");
    }

    const makeImage = (src) => {
      const img = document.createElement("img");
      img.src = src;
      img.alt = src.split("/").pop();
      img.addEventListener("click", () => openGalleryModal(src));
      return img;
    };

    sources.forEach((src) => inner.appendChild(makeImage(src)));
    sources.forEach((src) => inner.appendChild(makeImage(src)));

    track.appendChild(inner);
  }

  function loadStoryText() {
    fetch("ui/assets/story.txt")
      .then((res) => (res.ok ? res.text() : "story.txt non trovato."))
      .then((text) => {
        q("story-text").textContent = text;
      })
      .catch(() => {
        q("story-text").textContent = "story.txt non trovato.";
      });
  }

  function getStoryDuration() {
    const d1 = Number(storyAudio.duration);
    if (Number.isFinite(d1) && d1 > 0) return d1;
    const d2 = Number(storyVideo.duration);
    if (Number.isFinite(d2) && d2 > 0) return d2;
    return 0;
  }

  function getStoryTime() {
    const t1 = Number(storyAudio.currentTime);
    if (Number.isFinite(t1) && t1 >= 0) return t1;
    const t2 = Number(storyVideo.currentTime);
    if (Number.isFinite(t2) && t2 >= 0) return t2;
    return 0;
  }

  function setStoryTime(seconds) {
    const duration = getStoryDuration();
    const target = clamp(seconds, 0, duration > 0 ? duration : seconds);
    try {
      storyAudio.currentTime = target;
    } catch (e) {}
    try {
      storyVideo.currentTime = target;
    } catch (e) {}
    updateStoryUiFromTime();
  }

  function updateStoryUiFromTime() {
    const duration = getStoryDuration();
    const current = getStoryTime();
    const progress = duration > 0 ? clamp(current / duration, 0, 1) : 0;

    q("story-time-now").textContent = formatTime(current);
    q("story-time-total").textContent = formatTime(duration);

    if (!state.storySeekManual) {
      storySeek.value = String(Math.round(progress * 1000));
    }

    q("story-text-progress-fill").style.width = String(Math.round(progress * 100)) + "%";

    if (!state.storySeekManual && duration > 0 && (!storyAudio.paused || !storyVideo.paused)) {
      const maxScroll = Math.max(0, storyTextScroll.scrollHeight - storyTextScroll.clientHeight);
      storyTextScroll.scrollTop = maxScroll * progress;
    }

    q("btn-story-play-toggle").textContent =
      !storyAudio.paused || !storyVideo.paused ? "PAUSA" : "PLAY";
  }

  function syncStoryVideo() {
    if (storyAudio.paused || storyVideo.paused) return;
    const drift = Math.abs(storyAudio.currentTime - storyVideo.currentTime);
    if (drift > 0.18) {
      try {
        storyVideo.currentTime = storyAudio.currentTime;
      } catch (e) {}
    }
  }

  function storyPlay() {
    storyAudio.play().catch(() => {});
    try {
      storyVideo.currentTime = storyAudio.currentTime || storyVideo.currentTime;
    } catch (e) {}
    storyVideo.play().catch(() => {});
    syncStoryDucking(state.page === "story");
    updateStoryUiFromTime();
  }

  function storyPause() {
    storyAudio.pause();
    storyVideo.pause();
    syncStoryDucking(state.page === "story");
    updateStoryUiFromTime();
  }

  function storyStop() {
    storyPause();
    setStoryTime(0);
  }

  function toggleStoryPlayback() {
    if (!storyAudio.paused || !storyVideo.paused) {
      storyPause();
    } else {
      storyPlay();
    }
  }

  function startStoryTicker() {
    if (state.storyRaf) {
      cancelAnimationFrame(state.storyRaf);
      state.storyRaf = null;
    }

    const tick = () => {
      if (state.page !== "story") {
        state.storyRaf = null;
        return;
      }
      updateStoryUiFromTime();
      syncStoryVideo();
      state.storyRaf = requestAnimationFrame(tick);
    };
    state.storyRaf = requestAnimationFrame(tick);
  }

  function syncStoryDucking(isStoryPage) {
    if (!isStoryPage) {
      state.storyAudioPlaying = false;
      updateBgMusicVolume();
      return;
    }
    state.storyAudioPlaying = !storyAudio.paused || !storyVideo.paused;
    updateBgMusicVolume();
  }

  function normalizeLetter(v) {
    return (v || "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 1);
  }

  function normalizePositions(value) {
    let clean = (value || "").toUpperCase().replace(/[^A-Z]/g, "");
    if (clean.length < 3) clean = (clean + "AAA").slice(0, 3);
    return clean.slice(0, 3);
  }

  function alphaShift(letter, delta) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const idx = alphabet.indexOf(letter);
    if (idx < 0) return "A";
    const moved = (idx + delta + 26) % 26;
    return alphabet[moved];
  }

  function alphaIndex(letter) {
    const idx = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".indexOf(letter || "A");
    return idx < 0 ? 0 : idx;
  }

  const localEnigmaData = {
    rotors: {
      I: { wiring: "EKMFLGDQVZNTOWYHXUSPAIBRCJ", notch: "Q" },
      II: { wiring: "AJDKSIRUXBLHWTMCQGZNPYFVOE", notch: "E" },
      III: { wiring: "BDFHJLCPRTXVZNYEIWGAKMUSQO", notch: "V" },
      IV: { wiring: "ESOVPZJAYQUIRHXLNFTGKDCMWB", notch: "J" },
      V: { wiring: "VZBRGITYUPSDNHLXAWMJQOFECK", notch: "Z" },
    },
    reflectors: {
      B: "YRUHQSLDPXNGOKMIEBFZCWVJAT",
      C: "FVPJIAOYEDRZXWGCTKUQSBNMHL",
    },
  };

  function plugLetter(letter, pairs) {
    for (const pair of pairs || []) {
      const parts = String(pair).toUpperCase().split("-");
      if (parts.length === 2) {
        if (letter === parts[0]) return parts[1];
        if (letter === parts[1]) return parts[0];
      }
    }
    return letter;
  }

  function rotorForward(index, rotorName, position) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const rotor = localEnigmaData.rotors[rotorName] || localEnigmaData.rotors.I;
    const shifted = (index + position) % 26;
    const wired = alphabet.indexOf(rotor.wiring[shifted]);
    return (wired - position + 26) % 26;
  }

  function rotorBackward(index, rotorName, position) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const rotor = localEnigmaData.rotors[rotorName] || localEnigmaData.rotors.I;
    const shifted = (index + position) % 26;
    const wired = rotor.wiring.indexOf(alphabet[shifted]);
    return (wired - position + 26) % 26;
  }

  function stepLocalPositions(positionText, rotorNames) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const pos = normalizePositions(positionText).split("").map(alphaIndex);
    const middle = localEnigmaData.rotors[rotorNames[1]] || localEnigmaData.rotors.II;
    const right = localEnigmaData.rotors[rotorNames[2]] || localEnigmaData.rotors.III;
    const middleAtNotch = alphabet[pos[1]] === middle.notch;
    const rightAtNotch = alphabet[pos[2]] === right.notch;

    if (middleAtNotch) pos[0] = (pos[0] + 1) % 26;
    if (middleAtNotch || rightAtNotch) pos[1] = (pos[1] + 1) % 26;
    pos[2] = (pos[2] + 1) % 26;

    return pos.map((idx) => alphabet[idx]).join("");
  }

  function localEnigmaProcess(text, config) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const rotors = (config.rotors || ["I", "II", "III"]).slice(0, 3);
    let positions = normalizePositions(config.positions || state.positions);
    const reflector = localEnigmaData.reflectors[config.reflector] || localEnigmaData.reflectors.B;
    let output = "";

    String(text || "").toUpperCase().split("").forEach((raw) => {
      if (!/^[A-Z]$/.test(raw)) return;
      positions = stepLocalPositions(positions, rotors);
      const pos = positions.split("").map(alphaIndex);
      let letter = plugLetter(raw, config.plugboard_pairs);
      let signal = alphaIndex(letter);
      signal = rotorForward(signal, rotors[2], pos[2]);
      signal = rotorForward(signal, rotors[1], pos[1]);
      signal = rotorForward(signal, rotors[0], pos[0]);
      signal = alphabet.indexOf(reflector[signal]);
      signal = rotorBackward(signal, rotors[0], pos[0]);
      signal = rotorBackward(signal, rotors[1], pos[1]);
      signal = rotorBackward(signal, rotors[2], pos[2]);
      letter = plugLetter(alphabet[signal], config.plugboard_pairs);
      output += letter;
    });

    return { output, final_positions: positions, local: true };
  }

  function formatGroupedStream(text) {
    const cleaned = (text || "").toUpperCase().replace(/[^A-Z]/g, "");
    if (!cleaned.length) return "";
    return cleaned.match(/.{1,5}/g).join(" ");
  }

  function setMachineStatus(text) {
    q("machine-status").textContent = text;
  }

  function setMachineLastStep(text) {
    state.lastStep = text || "-";
    q("machine-last-step").textContent = "Ultimo step: " + state.lastStep;
  }

  function pushTrace(text) {
    const now = new Date();
    const stamp =
      String(now.getHours()).padStart(2, "0") +
      ":" +
      String(now.getMinutes()).padStart(2, "0") +
      ":" +
      String(now.getSeconds()).padStart(2, "0");
    state.traceLog.unshift("[" + stamp + "] " + text);
    state.traceLog = state.traceLog.slice(0, 40);
    q("machine-trace-log").textContent = state.traceLog.join("\n");
  }

  function refreshStreamUi() {
    q("machine-input-stream").textContent = state.inputStream.length
      ? formatGroupedStream(state.inputStream)
      : "In attesa di input...";
    q("machine-output-stream").textContent = state.outputStream.length
      ? formatGroupedStream(state.outputStream)
      : "Output non ancora generato.";
  }

  function updateMachineLivePanel() {
    q("machine-live-summary").textContent =
      "Posizioni: " + state.positions;
    const reflectorSummary = q("machine-reflector-summary");
    if (reflectorSummary) reflectorSummary.textContent = "Reflector: " + state.reflector;

    for (let i = 0; i < 3; i += 1) {
      const rotorChar = q("rotor-char-" + String(i));
      const rotorName = q("rotor-name-" + String(i));
      if (rotorChar) rotorChar.textContent = state.positions[i] || "A";
      if (rotorName) rotorName.textContent = state.rotors[i] || "-";
      const ring = document.querySelector('.rotor-dial[data-rotor-index="' + i + '"] .rotor-ring');
      if (ring) ring.style.transform = "rotate(" + (-alphaIndex(state.positions[i] || "A") * (360 / 26)) + "deg)";
    }

    q("positions").value = state.startPositions;
  }

  function setupRotorRings() {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    document.querySelectorAll(".rotor-ring").forEach((ring) => {
      ring.innerHTML = "";
      for (let i = 0; i < alphabet.length; i += 1) {
        const mark = document.createElement("span");
        mark.className = "rotor-mark" + (i % 13 === 0 ? " major" : "");
        mark.style.setProperty("--angle", i * (360 / 26) + "deg");
        const letter = document.createElement("strong");
        letter.textContent = alphabet[i];
        mark.appendChild(letter);
        ring.appendChild(mark);
      }
    });
  }

  function missionElapsedSeconds() {
    if (!state.mission.startedAt) return 0;
    return Math.max(0, Math.floor((Date.now() - state.mission.startedAt) / 1000));
  }

  function renderMission() {
    const m = state.mission;
    const stateEl = q("mission-state");
    stateEl.className = "mission-pill accent" + (m.solved ? " solved" : (m.active ? " active" : ""));
    stateEl.textContent = m.solved ? "COMPLETATA" : (m.active ? "ATTIVA" : "NON ATTIVA");
    q("mission-attempts").textContent = "TENTATIVI: " + m.attempts;
    q("mission-time").textContent = "TEMPO: " + missionElapsedSeconds() + "s";
    q("mission-score").textContent = "SCORE: " + m.score;
    q("mission-plain").textContent = m.plain || "Premi NUOVA MISSIONE";
    q("mission-cipher").textContent = m.cipher || "---";
    q("mission-config").textContent = m.config;
    q("mission-status-text").textContent = m.status;
  }

  function stopMissionTimer() {
    if (state.mission.elapsedTimer) {
      window.clearInterval(state.mission.elapsedTimer);
      state.mission.elapsedTimer = null;
    }
  }

  async function startMission() {
    const missionTexts = ["SCUOLA", "ENIGMA", "CODICE", "TURING", "ROTORI", "SEGRETO", "BLETCHLEY"];
    const starts = ["DDA", "KQF", "MZT", "RAV", "LNE", "QCP"];
    state.mission.plain = missionTexts[randomInt(0, missionTexts.length - 1)];
    state.mission.solution = starts[randomInt(0, starts.length - 1)];
    state.mission.active = true;
    state.mission.solved = false;
    state.mission.attempts = 0;
    state.mission.score = 0;
    state.mission.startedAt = Date.now();
    state.mission.config = "Rotori I-II-III | Reflector B | Plugboard nessuna coppia | Start target " + state.mission.solution;
    state.mission.status = "Missione attiva: imposta la posizione iniziale indicata, digita il plaintext e valida.";
    state.rotors = ["I", "II", "III"];
    state.reflector = "B";
    state.plugboardPairs = [];
    state.startPositions = state.mission.solution;
    state.positions = state.startPositions;
    q("rotor-left").value = "I";
    q("rotor-middle").value = "II";
    q("rotor-right").value = "III";
    q("reflector").value = "B";
    renderPlugboard();
    updateMachineLivePanel();
    q("machine-input").value = state.mission.plain;
    await runEncode("/encode");
    state.mission.cipher = q("machine-output").value || state.mission.cipher;
    if (!state.mission.cipher) state.mission.cipher = fallbackMissionCipher(state.mission.plain, state.mission.solution);
    q("machine-input").value = "";
    q("machine-output").value = "";
    state.inputStream = "";
    state.outputStream = "";
    state.startPositions = "AAA";
    state.positions = "AAA";
    updateMachineLivePanel();
    refreshStreamUi();
    setMachineStatus("Missione pronta: plaintext e target sono nel popup.");
    pushTrace("Nuova missione generata: " + state.mission.plain + " -> " + state.mission.cipher + ".");
    stopMissionTimer();
    state.mission.elapsedTimer = window.setInterval(renderMission, 1000);
    renderMission();
  }

  function validateMission() {
    if (!state.mission.active) {
      state.mission.status = "Premi NUOVA MISSIONE per iniziare.";
      renderMission();
      return;
    }
    state.mission.attempts += 1;
    const current = (state.outputStream || "").replace(/\s+/g, "").slice(-state.mission.cipher.length);
    if (current === state.mission.cipher) {
      state.mission.solved = true;
      state.mission.active = false;
      state.mission.score = Math.max(10, 100 - state.mission.attempts * 8 - missionElapsedSeconds());
      state.mission.status = "Missione completata: output target generato correttamente.";
      stopMissionTimer();
      setMachineStatus("Missione completata.");
      pushTrace("Missione completata con score " + state.mission.score + ".");
    } else {
      state.mission.status = "Output non coincide ancora. Target: " + state.mission.cipher + ". Ultimo output: " + (current || "---");
      setMachineStatus("Missione non ancora completata.");
    }
    renderMission();
  }

  function revealMissionSolution() {
    if (!state.mission.plain) {
      state.mission.status = "Nessuna missione da risolvere.";
      renderMission();
      return;
    }
    state.startPositions = state.mission.solution;
    state.positions = state.mission.solution;
    clearMachineRuntime();
    updateMachineLivePanel();
    state.mission.status = "Soluzione inserita: posizione iniziale " + state.mission.solution + ". Digita " + state.mission.plain + ".";
    setMachineStatus("Soluzione missione applicata.");
    renderMission();
  }

  function fallbackMissionCipher(text, seed) {
    const shift = alphaIndex((seed || "A")[0]) + 3;
    return (text || "")
      .toUpperCase()
      .replace(/[^A-Z]/g, "")
      .split("")
      .map((letter) => alphaShift(letter, shift))
      .join("");
  }

  function rotateRotor(index, delta) {
    if (index < 0 || index > 2) return;
    const chars = state.startPositions.split("");
    chars[index] = alphaShift(chars[index], delta);
    state.startPositions = chars.join("");
    state.positions = state.startPositions;
    clearMachineRuntime();
    updateMachineLivePanel();
    setMachineStatus("Posizioni aggiornate manualmente: " + state.startPositions);
  }

  function clearMachineRuntime() {
    q("machine-input").value = "";
    q("machine-output").value = "";
    state.inputStream = "";
    state.outputStream = "";
    refreshStreamUi();
    setMachineLastStep("Pronto.");
  }

  function recomputeRuntimeFromInput(text) {
    const clean = (text || "").toUpperCase().replace(/[^A-Z]/g, "");
    state.positions = state.startPositions;
    state.inputStream = "";
    state.outputStream = "";
    q("machine-input").value = "";
    q("machine-output").value = "";

    let lastStep = "Pronto.";
    clean.split("").forEach((letter) => {
      const beforePos = state.positions;
      const localData = localEnigmaProcess(letter, getMachineConfig(true));
      const output = localData.output || "";
      state.inputStream += letter;
      state.outputStream += output;
      state.positions = normalizePositions(localData.final_positions || state.positions);
      lastStep = letter + " -> " + output + " | " + beforePos + " -> " + state.positions;
    });

    q("machine-input").value = state.inputStream;
    q("machine-output").value = state.outputStream;
    refreshStreamUi();
    updateMachineLivePanel();
    setMachineLastStep(lastStep);
  }

  function backspaceInputStream() {
    if (!state.inputStream.length) {
      state.positions = state.startPositions;
      updateMachineLivePanel();
      setMachineStatus("Input stream gia vuoto.");
      return;
    }
    recomputeRuntimeFromInput(state.inputStream.slice(0, -1));
    setMachineStatus("Input stream: rimosso ultimo carattere.");
    pushTrace("Backspace: output ricostruito da " + state.startPositions + ".");
  }

  function renderPlugboard() {
    const box = q("plugboard-list");
    box.innerHTML = "";
    state.plugboardPairs.forEach((pair) => {
      const chip = document.createElement("button");
      chip.className = "pair-chip";
      chip.textContent = pair + "  x";
      chip.title = "Rimuovi " + pair;
      chip.addEventListener("click", () => {
        state.plugboardPairs = state.plugboardPairs.filter((p) => p !== pair);
        state.positions = state.startPositions;
        clearMachineRuntime();
        renderPlugboard();
        setMachineStatus("Rimossa coppia " + pair + ".");
        pushTrace("Plugboard: rimossa coppia " + pair + ".");
      });
      box.appendChild(chip);
    });
  }

  function addPlugPair() {
    const a = normalizeLetter(q("plug-a").value);
    const b = normalizeLetter(q("plug-b").value);
    if (!a || !b || a === b) {
      setMachineStatus("Coppia plugboard non valida.");
      return;
    }
    const pair = a < b ? a + "-" + b : b + "-" + a;
    state.plugboardPairs = state.plugboardPairs.filter((p) => !p.includes(a) && !p.includes(b));
    state.plugboardPairs.push(pair);
    state.plugboardPairs.sort();
    q("plug-a").value = "";
    q("plug-b").value = "";
    state.positions = state.startPositions;
    clearMachineRuntime();
    renderPlugboard();
    setMachineStatus("Plugboard aggiornato.");
    pushTrace("Plugboard: collegata coppia " + pair + ".");
  }

  function removePlugByLetter() {
    const letter = normalizeLetter(q("plug-remove").value);
    q("plug-remove").value = "";
    if (!letter) {
      setMachineStatus("Inserisci una lettera valida.");
      return;
    }
    const before = state.plugboardPairs.length;
    state.plugboardPairs = state.plugboardPairs.filter((p) => !p.includes(letter));
    state.positions = state.startPositions;
    clearMachineRuntime();
    renderPlugboard();
    if (state.plugboardPairs.length === before) {
      setMachineStatus("Nessuna coppia contiene la lettera " + letter + ".");
      return;
    }
    setMachineStatus("Rimosse coppie con la lettera " + letter + ".");
    pushTrace("Plugboard: rimosse coppie contenenti " + letter + ".");
  }

  function setupMachineOptions() {
    const rotorNames = ["I", "II", "III", "IV", "V"];
    const reflectorNames = ["B", "C"];

    ["rotor-left", "rotor-middle", "rotor-right"].forEach((id, i) => {
      const sel = q(id);
      sel.innerHTML = "";
      rotorNames.forEach((name) => {
        const opt = document.createElement("option");
        opt.value = name;
        opt.textContent = name;
        if (name === state.rotors[i]) opt.selected = true;
        sel.appendChild(opt);
      });
    });

    const reflector = q("reflector");
    reflector.innerHTML = "";
    reflectorNames.forEach((name) => {
      const opt = document.createElement("option");
      opt.value = name;
      opt.textContent = name;
      reflector.appendChild(opt);
    });
    reflector.value = state.reflector;

    q("positions").value = state.positions;
    updateMachineLivePanel();
    refreshStreamUi();
    setMachineLastStep("-");
  }

  function getMachineConfig(useCurrentPosition) {
    return {
      rotors: [q("rotor-left").value, q("rotor-middle").value, q("rotor-right").value],
      reflector: q("reflector").value,
      positions: useCurrentPosition ? state.positions : state.startPositions,
      plugboard_pairs: state.plugboardPairs.slice(),
    };
  }

  async function machineRequest(path, text) {
    const payload = getMachineConfig();
    payload.text = text;
    const url = state.apiBase.replace(/\/+$/, "") + path;
    const controller = window.AbortController ? new AbortController() : null;
    const timer = controller ? window.setTimeout(() => controller.abort(), 1300) : null;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller ? controller.signal : undefined,
    });
    if (timer) window.clearTimeout(timer);

    if (!res.ok) {
      let detail = "Errore API";
      try {
        const data = await res.json();
        if (data && data.detail) detail = String(data.detail);
      } catch (e) {}
      throw new Error(detail);
    }
    return res.json();
  }

  async function runEncode(pathLabel) {
    const input = q("machine-input").value || "";
    if (!input.length) {
      setMachineStatus("Inserisci prima del testo.");
      return;
    }

    const mode = pathLabel === "/decode" ? "DECIFRA" : "CIFRA";
    const beforePos = state.positions;
    setMachineStatus("Elaborazione in corso...");

    try {
      const data = await machineRequest(pathLabel, input);
      const output = data.output || "";
      q("machine-output").value = output;

      state.inputStream = (state.inputStream + input).slice(-2500);
      state.outputStream = (state.outputStream + output).slice(-2500);
      refreshStreamUi();

      state.positions = normalizePositions(data.final_positions || state.positions);
      updateMachineLivePanel();

      const step = mode + ": " + beforePos + " -> " + state.positions;
      setMachineLastStep(step);
      pushTrace(step + " | " + String(input.length) + " caratteri.");
      setMachineStatus("Operazione completata. Posizioni finali: " + state.positions);
    } catch (err) {
      const msg = err && err.message ? err.message : "Errore sconosciuto";
      if (pathLabel === "/encode" || pathLabel === "/decode") {
        const localData = localEnigmaProcess(input, getMachineConfig(false));
        const output = localData.output || "";
        q("machine-output").value = output;
        state.inputStream = (state.inputStream + input).slice(-2500);
        state.outputStream = (state.outputStream + output).slice(-2500);
        state.positions = normalizePositions(localData.final_positions || state.positions);
        refreshStreamUi();
        updateMachineLivePanel();
        const step = mode + ": motore locale";
        setMachineLastStep(step);
        pushTrace(step + " | API non disponibile: " + msg);
        setMachineStatus("Motore locale attivo. Output generato.");
        return;
      }
      setMachineStatus("Errore: " + msg);
      pushTrace("Errore " + mode + ": " + msg);
    }
  }

  function encodeImmediateLetter(letter) {
    const clean = normalizeLetter(letter);
    if (!clean) return;
    const beforePos = state.positions;
    const localData = localEnigmaProcess(clean, getMachineConfig(true));
    const output = localData.output || "";
    state.inputStream = (state.inputStream + clean).slice(-2500);
    state.outputStream = (state.outputStream + output).slice(-2500);
    q("machine-input").value = state.inputStream;
    q("machine-output").value = state.outputStream;
    state.positions = normalizePositions(localData.final_positions || state.positions);
    refreshStreamUi();
    updateMachineLivePanel();
    const step = "CIFRA: " + beforePos + " -> " + state.positions;
    setMachineLastStep(step);
    pushTrace(step + " | " + clean + " -> " + output + " | motore locale.");
    setMachineStatus("Lettera cifrata: " + clean + " -> " + output + ".");
  }

  function setDisruptionOverlay(visible, blackOnly) {
    if (!visible) {
      disruptionOverlay.classList.add("hidden");
      disruptionMessage.classList.add("hidden");
      disruptionBlack.style.opacity = "0";
      return;
    }
    disruptionOverlay.classList.remove("hidden");
    disruptionBlack.style.opacity = "0.96";
    if (blackOnly) {
      disruptionMessage.classList.add("hidden");
    } else {
      disruptionMessage.classList.remove("hidden");
    }
  }

  function buildDisruptionMessage() {
    const localita = pickDistinct(
      [
        "Wolverton",
        "Stony Stratford",
        "Fenny Stratford",
        "Woburn Sands",
        "Newport Pagnell",
        "Buckingham",
        "Leighton Buzzard",
        "Bicester",
      ],
      randomInt(3, 4)
    );
    const attore = pickOne(["Luftwaffe tedesca", "forze dell'Asse", "squadriglie tedesche d'attacco"]);
    const azione = pickOne(["azioni offensive coordinate", "una nuova ondata di incursioni", "un attacco mirato alle infrastrutture"]);
    const velivolo = pickOne(["Heinkel He 111", "Junkers Ju 88", "Dornier Do 17", "Messerschmitt Bf 110"]);
    const ordigno = pickOne(["V-1", "V-2"]);

    disruptionTitle.textContent = "ALLERTA OPERATIVA: BLACKOUT TEMPORANEO";
    disruptionText.textContent =
      "Rapporto da Bletchley Park: detonazioni segnalate nell'area di " +
      formatList(localita) +
      ".\n\nIntelligence: " +
      attore +
      " in " +
      azione +
      ", possibile impiego di " +
      velivolo +
      " e ordigni " +
      ordigno +
      ".\n\nInterruzione di corrente confermata. I generatori di emergenza entreranno in funzione tra pochi istanti.";

    return randomInt(18000, 30000);
  }

  function isDisruptionEligiblePage() {
    return state.page === "intro" || state.page === "home" || state.page === "machine" || state.page === "story";
  }

  function scheduleDisruption(initial) {
    if (!state.disruptionEnabled || state.disruptionOccurred || state.disruptionActive) return;
    if (state.disruptionTimer) {
      window.clearTimeout(state.disruptionTimer);
      state.disruptionTimer = null;
    }
    const minDelay = initial ? 55000 : 25000;
    const maxDelay = initial ? 90000 : 60000;
    state.disruptionTimer = window.setTimeout(triggerDisruption, randomInt(minDelay, maxDelay));
  }

  function triggerDisruption() {
    if (!state.disruptionEnabled || state.disruptionOccurred || state.disruptionActive) return;
    if (!isDisruptionEligiblePage()) {
      scheduleDisruption(false);
      return;
    }

    state.disruptionOccurred = true;
    state.disruptionActive = true;

    state.disruptionResumeStoryAudio = !storyAudio.paused;
    state.disruptionResumeStoryVideo = !storyVideo.paused;
    storyPause();

    animateValue(
      (v) => {
        state.emergencyMusicFactor = v;
        updateBgMusicVolume();
      },
      state.emergencyMusicFactor,
      0,
      700
    );

    setDisruptionOverlay(true, true);
    const messageDuration = buildDisruptionMessage();

    state.disruptionBlackTimer = window.setTimeout(() => {
      setDisruptionOverlay(true, false);
      state.disruptionMessageTimer = window.setTimeout(() => {
        finishDisruption();
      }, messageDuration);
    }, 2000);
  }

  function finishDisruption() {
    if (!state.disruptionActive) return;

    if (state.disruptionBlackTimer) {
      window.clearTimeout(state.disruptionBlackTimer);
      state.disruptionBlackTimer = null;
    }
    if (state.disruptionMessageTimer) {
      window.clearTimeout(state.disruptionMessageTimer);
      state.disruptionMessageTimer = null;
    }

    state.disruptionActive = false;
    setDisruptionOverlay(false, false);

    animateValue(
      (v) => {
        state.emergencyMusicFactor = v;
        updateBgMusicVolume();
      },
      state.emergencyMusicFactor,
      1,
      900
    );

    if (state.page === "story" && state.disruptionResumeStoryAudio) {
      storyPlay();
    }
    state.disruptionResumeStoryAudio = false;
    state.disruptionResumeStoryVideo = false;
  }

  function syncSettingsUi() {
    q("settings-music-enabled").checked = state.bgMusicEnabled;
    q("settings-volume").value = String(Math.round(state.bgMusicVolume * 100));
    q("settings-volume-label").textContent = String(Math.round(state.bgMusicVolume * 100)) + "%";
    q("settings-ducking").value = String(Math.round(state.storyDuckingFactor * 100));
    q("settings-duck-label").textContent = String(Math.round((1 - state.storyDuckingFactor) * 100)) + "%";
    q("settings-brightness").value = String(Math.round(state.uiBrightness * 100));
    q("settings-brightness-label").textContent = String(Math.round(state.uiBrightness * 100)) + "%";
    q("settings-disruption-enabled").checked = state.disruptionEnabled;
    q("settings-api-url").value = state.apiBase;
  }

  function syncSettingsPreviewLabels() {
    q("settings-volume-label").textContent = String(Number(q("settings-volume").value)) + "%";
    q("settings-duck-label").textContent = String(100 - Number(q("settings-ducking").value)) + "%";
    q("settings-brightness-label").textContent = String(Number(q("settings-brightness").value)) + "%";
  }

  function applySettings() {
    const wasEnabled = state.disruptionEnabled;
    state.bgMusicEnabled = q("settings-music-enabled").checked;
    state.bgMusicVolume = clamp(Number(q("settings-volume").value) / 100, 0, 1);
    state.storyDuckingFactor = clamp(Number(q("settings-ducking").value) / 100, 0.15, 1);
    state.uiBrightness = clamp(Number(q("settings-brightness").value) / 100, 0.45, 1);
    state.disruptionEnabled = q("settings-disruption-enabled").checked;
    state.apiBase = (q("settings-api-url").value || "").trim() || state.apiBase;

    if (window.localStorage) {
      window.localStorage.setItem("enigma_api_base", state.apiBase);
    }

    brightnessLayer.style.opacity = String((1 - state.uiBrightness) * 0.7);
    updateBgMusicVolume();
    syncSettingsUi();

    if (!state.disruptionEnabled && wasEnabled) {
      if (state.disruptionTimer) {
        window.clearTimeout(state.disruptionTimer);
        state.disruptionTimer = null;
      }
    } else if (state.disruptionEnabled && !wasEnabled && !state.disruptionOccurred && !state.disruptionActive) {
      scheduleDisruption(false);
    }
  }

  function bindRotorDialEvents() {
    document.querySelectorAll(".rotor-dial").forEach((dial) => {
      const index = Number(dial.getAttribute("data-rotor-index"));

      dial.addEventListener("click", (ev) => {
        const rect = dial.getBoundingClientRect();
        const isUp = ev.clientY - rect.top <= rect.height / 2;
        rotateRotor(index, isUp ? 1 : -1);
      });

      dial.addEventListener(
        "wheel",
        (ev) => {
          ev.preventDefault();
          rotateRotor(index, ev.deltaY < 0 ? 1 : -1);
        },
        { passive: false }
      );
    });
  }

  function setupMobileKeyboard() {
    const keyboard = q("mobile-keyboard");
    if (!keyboard) return;
    keyboard.innerHTML = "";
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").forEach((letter) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.textContent = letter;
      btn.addEventListener("click", () => {
        encodeImmediateLetter(letter);
      });
      keyboard.appendChild(btn);
    });
  }

  function bindEvents() {
    q("btn-disclaimer-continue").addEventListener("click", () => setPage("soundtrack"));

    q("btn-theme-war").addEventListener("click", () => {
      setSoundtrack("war", false);
      startMusicWithFade();
      setPage("boot");
    });

    q("btn-theme-classic").addEventListener("click", () => {
      setSoundtrack("classic", false);
      startMusicWithFade();
      setPage("boot");
    });

    q("btn-start-experience").addEventListener("click", () => setPage("home"));
    q("btn-open-machine").addEventListener("click", () => setPage("machine"));
    q("btn-open-story").addEventListener("click", () => setPage("story"));
    q("btn-open-mission").addEventListener("click", () => {
      setPage("machine");
      window.setTimeout(async () => {
        showModal(missionModal);
        if (!state.mission.active && !state.mission.solved) await startMission();
      }, 160);
    });

    q("btn-machine-mission").addEventListener("click", () => showModal(missionModal));
    q("btn-machine-help").addEventListener("click", async () => {
      showModal(missionModal);
      if (!state.mission.active && !state.mission.solved) await startMission();
      setMachineStatus("Prova guidata avviata: segui la missione nel pannello.");
      pushTrace("Prova guidata avviata dalla simulazione.");
    });
    q("btn-machine-home").addEventListener("click", () => setPage("home"));

    q("btn-story-home").addEventListener("click", () => {
      storyStop();
      setPage("home");
    });

    q("btn-apply-config").addEventListener("click", () => {
      const left = q("rotor-left").value;
      const middle = q("rotor-middle").value;
      const right = q("rotor-right").value;
      if (new Set([left, middle, right]).size !== 3) {
        setMachineStatus("I tre rotori devono essere diversi.");
        return;
      }
      state.rotors = [left, middle, right];
      state.reflector = q("reflector").value;
      state.startPositions = normalizePositions(q("positions").value);
      state.positions = state.startPositions;
      clearMachineRuntime();
      updateMachineLivePanel();
      setMachineStatus("Configurazione applicata.");
      pushTrace("Configurazione: rotori " + state.rotors.join("-") + ", reflector " + state.reflector + ", start " + state.startPositions + ".");
    });

    q("positions").addEventListener("input", () => {
      const raw = (q("positions").value || "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 3);
      q("positions").value = raw;
      if (raw.length === 3) {
        state.startPositions = raw;
        state.positions = raw;
        clearMachineRuntime();
        updateMachineLivePanel();
      }
    });

    q("btn-reset-machine").addEventListener("click", () => {
      state.positions = state.startPositions;
      clearMachineRuntime();
      updateMachineLivePanel();
      setMachineStatus("Posizioni resettate a " + state.startPositions + ".");
      pushTrace("Reset posizioni a " + state.startPositions + ".");
    });

    q("btn-add-pair").addEventListener("click", addPlugPair);
    q("btn-remove-pair").addEventListener("click", removePlugByLetter);

    q("btn-clear-pairs").addEventListener("click", () => {
      state.plugboardPairs = [];
      state.positions = state.startPositions;
      clearMachineRuntime();
      renderPlugboard();
      setMachineStatus("Plugboard azzerato.");
      pushTrace("Plugboard azzerato.");
    });

    q("btn-clear-streams").addEventListener("click", () => {
      clearMachineRuntime();
      setMachineStatus("Stream puliti.");
      pushTrace("Stream input/output puliti.");
    });
    q("btn-clear-input-stream").addEventListener("click", () => {
      clearMachineRuntime();
      setMachineStatus("Input stream svuotato.");
      pushTrace("Input stream svuotato.");
    });
    q("btn-copy-output-stream").addEventListener("click", async () => {
      if (navigator.clipboard) {
        navigator.clipboard.writeText(state.outputStream || "")
          .then(() => setMachineStatus("Output copiato negli appunti."))
          .catch(() => setMachineStatus("Copia non riuscita: seleziona il testo manualmente."));
      } else {
        setMachineStatus("Clipboard non supportata su questo browser.");
      }
    });

    q("btn-encode").addEventListener("click", () => runEncode("/encode"));
    q("btn-decode").addEventListener("click", () => runEncode("/decode"));

    q("btn-story-play-toggle").addEventListener("click", toggleStoryPlayback);
    q("btn-story-sync-stop").addEventListener("click", storyStop);
    storyVideo.addEventListener("click", toggleStoryPlayback);

    storySeek.addEventListener("input", () => {
      state.storySeekManual = true;
      const duration = getStoryDuration();
      const ratio = Number(storySeek.value) / 1000;
      setStoryTime(duration * ratio);
    });

    storySeek.addEventListener("change", () => {
      state.storySeekManual = false;
      updateStoryUiFromTime();
    });

    ["play", "pause", "ended", "loadedmetadata", "timeupdate"].forEach((evt) => {
      storyAudio.addEventListener(evt, () => {
        updateStoryUiFromTime();
        syncStoryDucking(state.page === "story");
      });
      storyVideo.addEventListener(evt, () => {
        updateStoryUiFromTime();
        syncStoryDucking(state.page === "story");
      });
    });

    if (!document.documentElement.requestFullscreen) {
      q("btn-fullscreen").style.display = "none";
    } else {
      q("btn-fullscreen").addEventListener("click", async () => {
        if (!document.fullscreenElement) {
          await document.documentElement.requestFullscreen().catch(() => {});
        } else {
          await document.exitFullscreen().catch(() => {});
        }
        q("btn-fullscreen").textContent = document.fullscreenElement ? "WINDOW" : "FULLSCREEN";
      });
    }

    q("btn-credits").addEventListener("click", () => showModal(creditsModal));
    q("btn-settings").addEventListener("click", () => {
      syncSettingsUi();
      showModal(settingsModal);
    });

    document.querySelectorAll("[data-close-modal]").forEach((btn) => {
      btn.addEventListener("click", () => hideModal(q(btn.getAttribute("data-close-modal"))));
    });

    q("btn-gallery-close").addEventListener("click", () => hideModal(galleryModal));
    galleryModal.addEventListener("click", (ev) => {
      if (ev.target === galleryModal) hideModal(galleryModal);
    });
    missionModal.addEventListener("click", (ev) => {
      if (ev.target === missionModal) hideModal(missionModal);
    });

    q("btn-mission-new").addEventListener("click", () => {
      setPage("machine");
      startMission();
    });
    q("btn-mission-validate").addEventListener("click", () => {
      setPage("machine");
      validateMission();
    });
    q("btn-mission-solution").addEventListener("click", () => {
      setPage("machine");
      revealMissionSolution();
    });

    q("settings-theme-classic").addEventListener("click", () => setSoundtrack("classic", true));
    q("settings-theme-war").addEventListener("click", () => setSoundtrack("war", true));

    q("settings-defaults").addEventListener("click", () => {
      state.bgMusicEnabled = true;
      state.bgMusicVolume = 0.5;
      state.storyDuckingFactor = 0.2;
      state.uiBrightness = 1;
      state.disruptionEnabled = true;
      setSoundtrack("classic", true);
      syncSettingsUi();
      applySettings();
    });

    q("settings-save").addEventListener("click", () => {
      applySettings();
      hideModal(settingsModal);
    });

    ["settings-volume", "settings-ducking", "settings-brightness"].forEach((id) => {
      q(id).addEventListener("input", syncSettingsPreviewLabels);
    });

    document.addEventListener("keydown", (event) => {
      if (state.disruptionActive && event.key === "Enter") {
        event.preventDefault();
        finishDisruption();
      }
      const tag = event.target && event.target.tagName ? event.target.tagName.toLowerCase() : "";
      const editingConfig =
        tag === "input" ||
        tag === "select" ||
        tag === "textarea" ||
        (event.target && event.target.isContentEditable);
      if (state.page === "machine" && event.key === "Backspace" && !editingConfig) {
        event.preventDefault();
        backspaceInputStream();
        return;
      }
      if (state.page === "machine" && (event.key === "Delete" || event.key === "Tab") && !editingConfig) {
        event.preventDefault();
        return;
      }
      if (state.page === "machine" && !event.ctrlKey && !event.altKey && !event.metaKey && /^[a-zA-Z]$/.test(event.key)) {
        if (editingConfig) return;
        encodeImmediateLetter(event.key);
      }
    });
  }

  function initialize() {
    storyVideo.controls = false;
    storyVideo.defaultMuted = true;
    storyVideo.muted = true;
    storyVideo.volume = 0;
    storyVideo.playsInline = true;

    setupGallery();
    setupRotorRings();
    setupMobileKeyboard();
    setupMachineOptions();
    loadStoryText();
    renderPlugboard();
    renderMission();
    bindRotorDialEvents();
    bindEvents();
    updateMachineScale();
    window.addEventListener("resize", updateMachineScale);

    setMachineStatus("Configurazione iniziale pronta.");
    pushTrace("Sistema pronto.");

    syncSettingsUi();
    applySettings();
    updateOverlayVisibility();
    updateBootUi(0);
    updateStoryUiFromTime();
    startStoryTicker();
    scheduleDisruption(true);

    const params = new URLSearchParams(window.location.search);
    const debugPage = params.get("page");
    if (debugPage && pages.has(debugPage)) {
      pages.get(state.page).classList.remove("active");
      state.page = debugPage;
      pages.get(state.page).classList.add("active");
      updateOverlayVisibility();
      if (state.page === "story") startStoryTicker();
    }
    const debugModal = params.get("modal");
    if (debugModal === "settings") {
      syncSettingsUi();
      showModal(settingsModal);
    } else if (debugModal === "credits") {
      showModal(creditsModal);
    }
    if (params.get("mission") === "1") {
      if (state.page !== "machine") {
        pages.get(state.page).classList.remove("active");
        state.page = "machine";
        pages.get(state.page).classList.add("active");
        updateOverlayVisibility();
      }
      showModal(missionModal);
      startMission();
    }
  }

  initialize();
})();
