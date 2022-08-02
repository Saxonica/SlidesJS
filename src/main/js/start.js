const SlidesJSVersion = "1.3.3";

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

window.slidesEventQueue = [];

window.slidesPushEvent = function(state, value) {
  window.slidesEventQueue.push({'state': state, 'value': value});
  if (localStorageKey) {
    window.localStorage.setItem(`${localStorageKey}.${state}`, value);
  }
};

window.slidesPopEvent = function() {
  return window.slidesEventQueue.shift();
};

window.manageSlides = {
  "slidesJSVersion": SlidesJSVersion,
  "showNotes": false,
  "duration": 'PT0S',
  "startTime": "",
  "paused": true,
  "last-reveal": "",
  "last-unreveal": "",
  "last-reveal-all": "",
  "touchX": 0,
  "touchY": 0
};

if (localStorageKey) {
  if (window.localStorage.getItem(`${localStorageKey}.version`) !== SlidesJSVersion) {
    Object.keys(window.localStorage).forEach(key => {
      if (key.startsWith(localStorageKey+".")) {
        window.localStorage.removeItem(key);
      }
    });
    window.localStorage.setItem(`${localStorageKey}.version`, SlidesJSVersion);
  }
}

// If we open a URI without a fragment identifier, we're immediately
// redirected to one that ends with a bare #. This causes an annoying
// flicker when multiple browser windows are open, so just normalize
// the location so that it always has a fragment identifier.
// (Candidly, I don't much like the trailing empty fragid on the
// title page, but it's not worth fussing about.)
const normalizedLocation = function(loc) {
  if (!loc) {
    loc = location.href;
  }
  if (loc.indexOf("#") >= 0) {
    return loc;
  } else {
    return loc + "#";
  }
};

const storageChange = function(changes, areaName) {
  if (changes.key.startsWith(localStorageKey)) {
    const key = changes.key.substring(localStorageKey.length + 1);
    // Changes to the current page are managed with the location.href
    if (key === "currentPage") {
      if (normalizedLocation() !== normalizedLocation(changes.newValue)) {
        location.href = normalizedLocation(changes.newValue);
      }
    } else {
      window.slidesEventQueue.push({'state': key, 'value': changes.newValue});
    }
  }
};

const hashChange = function(event) {
  // Defer hash changes to the storage change function so
  // that they're handled in one place.
  window.slidesPushEvent("currentPage", normalizedLocation());
};

const initialValue = function(key, defaultValue) {
  let value = null;
  if (localStorageKey) {
    value = window.localStorage.getItem(`${localStorageKey}.${key}`);
  }
  return value === null ? defaultValue : value;
}

window.slidesPushEvent("currentPage", normalizedLocation());

let now = new Date().toISOString();
window.slidesPushEvent("reload", now);

window.slidesPushEvent("duration", initialValue("duration", "PT0S"));
window.slidesPushEvent("startTime", initialValue("startTime", now));
window.slidesPushEvent("paused", initialValue("paused", "true") === "true");

window.addEventListener("storage", storageChange);
window.addEventListener("hashchange", hashChange);
