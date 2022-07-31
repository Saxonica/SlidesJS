window.onload = function() {
  const defeatTheCache = new Date();
  SaxonJS.transform({
    stylesheetLocation: `xslt/slides.sef.json?nocache=${defeatTheCache.getTime()}`,
    sourceLocation: `index.html?nocache=${defeatTheCache.getTime()}`
  }, "async");
};

window.forceHighlight = function() {
  document.querySelectorAll("pre").forEach(pre => {
    Prism.highlightElement(pre);
  });
};

let meta = document.querySelector("head meta[name='localStorage.key']");
const localStorageKey = meta && meta.getAttribute("content");
const notesKey = "viewingNotes";
let notesView = false;

window.manageSpeakerNotes = {
  "reload": new Date().toString(),
  "navigated": false,
  "currentPage": window.location.href,
  "reveal": false,
  "unreveal": false,
  "showNotes": false,
  "duration": 'PT0S',
  "startTime": "",
  "paused": true,
  "touchX": 0,
  "touchY": 0,
  "touchSwipe": ""
};

const storageChange = function(changes, areaName) {
  if (changes.key.startsWith(localStorageKey)) {
    const key = changes.key.substring(localStorageKey.length + 1);
    if (window.manageSpeakerNotes[key] !== changes.newValue) {
      window.manageSpeakerNotes[key] = changes.newValue;
    }
  }
};

if (localStorageKey) {
  const dt = new Date().toString();
  window.localStorage.setItem(`${localStorageKey}.currentPage`, window.location.href);
  window.localStorage.setItem(`${localStorageKey}.reveal`, "");
  window.localStorage.setItem(`${localStorageKey}.unreveal`, "");
  window.localStorage.setItem(`${localStorageKey}.reload`, dt);

  let duration = window.localStorage.getItem(`${localStorageKey}.duration`);
  if (duration == null) {
    window.localStorage.setItem(`${localStorageKey}.duration`, "PT0S");
  } else {
    window.manageSpeakerNotes.duration = duration;
  }

  let startTime = window.localStorage.getItem(`${localStorageKey}.startTime`);
  // There was a bug in 1.1.0 that meant startTime could sometimes
  // incorrectly get initialized to 'true' instead of a dateTime
  if (startTime === null || startTime === "true") {
    startTime = new Date().toISOString();
    window.localStorage.setItem(`${localStorageKey}.startTime`, startTime);
  }
  window.manageSpeakerNotes.startTime = startTime;

  let paused = window.localStorage.getItem(`${localStorageKey}.paused`);
  if (paused == null) {
    paused = "true";
    window.localStorage.setItem(`${localStorageKey}.paused`, paused);
  }
  window.manageSpeakerNotes.paused = (paused == "true");

  window.addEventListener("storage", storageChange);
};
