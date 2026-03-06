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
    positions: "AAA",
    plugboardPairs: [],
    inputStream: "",
    outputStream: "",
    traceLog: [],
    lastStep: "-",
    apiBase:
      (window.localStorage && window.localStorage.getItem("enigma_api_base")) ||
      "https://enigma-touch-web-api.onrender.com",
    galleryOffset: 0,
    gallerySingleWidth: 0,
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
    const hideTop = state.page === "disclaimer" || state.page === "soundtrack";
    topButtons.style.display = hideTop ? "none" : "flex";

    const hideByline =
      state.page === "intro" ||
      state.page === "machine" ||
      state.page === "disclaimer" ||
      state.page === "soundtrack";
    byline.style.display = hideByline ? "none" : "block";
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
    inner.style.animation = "none";
    const sources = [];
    for (let i = 1; i <= 8; i += 1) {
      sources.push("ui/assets/gallery/" + i + ".png");
    }

    let loaded = 0;
    const makeImage = (src) => {
      const img = document.createElement("img");
      img.src = src;
      img.alt = src.split("/").pop();
      img.addEventListener("click", () => openGalleryModal(src));
      const onDone = () => {
        loaded += 1;
        if (loaded >= 2) {
          window.setTimeout(recalc, 0);
        }
      };
      img.addEventListener("load", onDone, { once: true });
      img.addEventListener("error", onDone, { once: true });
      return img;
    };

    sources.forEach((src) => inner.appendChild(makeImage(src)));
    sources.forEach((src) => inner.appendChild(makeImage(src)));

    track.appendChild(inner);

    const recalc = () => {
      state.gallerySingleWidth = Math.max(1, inner.scrollWidth / 2);
    };

    window.setTimeout(recalc, 120);
    window.setTimeout(recalc, 700);
    window.setTimeout(recalc, 1500);
    window.addEventListener("resize", recalc);

    track.addEventListener("mouseenter", () => {
      state.galleryPaused = true;
    });
    track.addEventListener("mouseleave", () => {
      state.galleryPaused = false;
    });

    if (state.galleryRaf) {
      cancelAnimationFrame(state.galleryRaf);
      state.galleryRaf = null;
    }

    const tick = () => {
      if (state.page === "intro" && !state.galleryPaused && state.gallerySingleWidth > 1) {
        state.galleryOffset += 0.35;
        if (state.galleryOffset >= state.gallerySingleWidth) {
          state.galleryOffset -= state.gallerySingleWidth;
        }
        inner.style.transform = "translateX(" + String(-state.galleryOffset) + "px)";
      }
      state.galleryRaf = requestAnimationFrame(tick);
    };
    state.galleryRaf = requestAnimationFrame(tick);
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
      "Posizioni: " + state.positions + " | Reflector: " + state.reflector;

    for (let i = 0; i < 3; i += 1) {
      const rotorChar = q("rotor-char-" + String(i));
      const rotorName = q("rotor-name-" + String(i));
      if (rotorChar) rotorChar.textContent = state.positions[i] || "A";
      if (rotorName) rotorName.textContent = state.rotors[i] || "-";
    }

    q("positions").value = state.positions;
  }

  function rotateRotor(index, delta) {
    if (index < 0 || index > 2) return;
    const chars = state.positions.split("");
    chars[index] = alphaShift(chars[index], delta);
    state.positions = chars.join("");
    updateMachineLivePanel();
    setMachineStatus("Posizioni aggiornate manualmente: " + state.positions);
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

  function getMachineConfig() {
    return {
      rotors: [q("rotor-left").value, q("rotor-middle").value, q("rotor-right").value],
      reflector: q("reflector").value,
      positions: state.positions,
      plugboard_pairs: state.plugboardPairs.slice(),
    };
  }

  async function machineRequest(path, text) {
    const payload = getMachineConfig();
    payload.text = text;
    const url = state.apiBase.replace(/\/+$/, "") + path;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

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
      setMachineStatus("Errore: " + msg);
      pushTrace("Errore " + mode + ": " + msg);
    }
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
      state.positions = normalizePositions(q("positions").value);
      updateMachineLivePanel();
      setMachineStatus("Configurazione applicata.");
      pushTrace("Configurazione: rotori " + state.rotors.join("-") + ", reflector " + state.reflector + ", start " + state.positions + ".");
    });

    q("positions").addEventListener("input", () => {
      const raw = (q("positions").value || "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 3);
      q("positions").value = raw;
      if (raw.length === 3) {
        state.positions = raw;
        updateMachineLivePanel();
      }
    });

    q("btn-reset-machine").addEventListener("click", () => {
      q("positions").value = state.positions;
      updateMachineLivePanel();
      setMachineStatus("Posizioni resettate a " + state.positions + ".");
      pushTrace("Reset posizioni a " + state.positions + ".");
    });

    q("btn-add-pair").addEventListener("click", addPlugPair);
    q("btn-remove-pair").addEventListener("click", removePlugByLetter);

    q("btn-clear-pairs").addEventListener("click", () => {
      state.plugboardPairs = [];
      renderPlugboard();
      setMachineStatus("Plugboard azzerato.");
      pushTrace("Plugboard azzerato.");
    });

    q("btn-clear-streams").addEventListener("click", () => {
      q("machine-input").value = "";
      q("machine-output").value = "";
      state.inputStream = "";
      state.outputStream = "";
      refreshStreamUi();
      setMachineStatus("Stream puliti.");
      pushTrace("Stream input/output puliti.");
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

    q("btn-fullscreen").addEventListener("click", async () => {
      if (!document.fullscreenElement) {
        await document.documentElement.requestFullscreen().catch(() => {});
      } else {
        await document.exitFullscreen().catch(() => {});
      }
      q("btn-fullscreen").textContent = document.fullscreenElement ? "WINDOW" : "FULLSCREEN";
    });

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
  }

  function initialize() {
    storyVideo.controls = false;
    storyVideo.defaultMuted = true;
    storyVideo.muted = true;
    storyVideo.volume = 0;
    storyVideo.playsInline = true;

    setupGallery();
    setupMachineOptions();
    loadStoryText();
    renderPlugboard();
    bindRotorDialEvents();
    bindEvents();

    setMachineStatus("Configurazione iniziale pronta.");
    pushTrace("Sistema pronto.");

    syncSettingsUi();
    applySettings();
    updateOverlayVisibility();
    updateBootUi(0);
    updateStoryUiFromTime();
    startStoryTicker();
    scheduleDisruption(true);
  }

  initialize();
})();
