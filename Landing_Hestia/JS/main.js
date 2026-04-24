const releaseConfig = window.HestiaReleaseConfig || {};
const downloadConfig = releaseConfig.platforms || {};
const siteConfig = {
  version: releaseConfig.currentVersion || "preview",
  links: releaseConfig.links || {},
};

const platformNames = {
  android: "Android",
  windows: "Windows",
  windowsPortable: "Windows portable",
  macos: "macOS",
  linux: "Linux",
  ios: "iOS",
  web: "Web",
  server: "Backend server",
  landing: "Landing/site",
  checksums: "Checksums",
};

function getPlatformSignal() {
  const uaDataPlatform = navigator.userAgentData?.platform || "";
  const platform = navigator.platform || "";
  const userAgent = navigator.userAgent || "";

  return `${uaDataPlatform} ${platform} ${userAgent}`.toLowerCase();
}

function detectPlatform() {
  const signal = getPlatformSignal();
  const hasTouch = navigator.maxTouchPoints > 1;

  if (/android/.test(signal)) {
    return "android";
  }

  if (/iphone|ipad|ipod/.test(signal)) {
    return "web";
  }

  if (/mac/.test(signal) && hasTouch) {
    return "web";
  }

  if (/mac|darwin/.test(signal)) {
    return "macos";
  }

  if (/win/.test(signal)) {
    return "windows";
  }

  if (/linux|x11/.test(signal)) {
    return hasTouch && /mobile/.test(signal) ? "android" : "linux";
  }

  return null;
}

function applyDownloadLinks() {
  document.querySelectorAll("[data-download-key]").forEach((link) => {
    const key = link.dataset.downloadKey;
    const config = downloadConfig[key];

    if (!config) {
      return;
    }

    link.href = config.url;
    link.textContent = config.cardLabel;
    link.rel = key === "web" ? "noopener noreferrer" : "";

    if (key === "web") {
      link.target = "_blank";
    }
  });
}

function applyReleaseLinks() {
  document.querySelectorAll("[data-release-link]").forEach((link) => {
    const key = link.dataset.releaseLink;
    const url = releaseConfig[key];

    if (!url) {
      return;
    }

    link.href = url;
  });
}

function applySiteLinks() {
  document.querySelectorAll("[data-site-link]").forEach((link) => {
    const key = link.dataset.siteLink;
    const url = siteConfig.links[key];

    if (!url) {
      return;
    }

    link.href = url;

    if (/^https?:\/\//.test(url)) {
      link.target = "_blank";
      link.rel = "noopener noreferrer";
    }
  });

  document.querySelectorAll("[data-site-version]").forEach((element) => {
    element.textContent = siteConfig.version;
  });
}

function createMetaItem(label, value) {
  const item = document.createElement("span");
  item.className = "release-meta-item";
  item.textContent = `${label}: ${value}`;
  return item;
}

function createDownloadRow(key, platform) {
  const row = document.createElement("article");
  row.className = "release-row";
  row.dataset.platformCard = key;

  const info = document.createElement("div");

  const title = document.createElement("h3");
  title.textContent = platform.name;

  const description = document.createElement("p");
  description.textContent = platform.description;

  const meta = document.createElement("div");
  meta.className = "release-meta";
  meta.append(
    createMetaItem("Type", platform.fileType),
    createMetaItem("Version", siteConfig.version),
    createMetaItem("Size", platform.fileSize),
  );

  const checksum = document.createElement("code");
  checksum.className = "checksum";
  checksum.textContent = platform.checksum;

  if (platform.available === false) {
    checksum.className = "release-status";
    checksum.textContent = platform.description;
    row.classList.add("is-disabled");
  }

  info.append(title, description, meta, checksum);

  const actions = document.createElement("div");
  actions.className = "release-actions";

  const fileName = document.createElement("span");
  fileName.className = "release-file";
  fileName.textContent = platform.fileName;

  const button = document.createElement(platform.available === false ? "span" : "a");
  button.className = platform.available === false
    ? "button button-disabled"
    : "button button-download";
  button.textContent = platform.available === false ? "Coming later" : platform.cardLabel;

  if (platform.available === false) {
    button.setAttribute("aria-disabled", "true");
  } else {
    button.href = platform.url;
  }

  if (platform.available !== false && /^https?:\/\//.test(platform.url)) {
    button.target = "_blank";
    button.rel = "noopener noreferrer";
  }

  actions.append(fileName, button);
  row.append(info, actions);

  return row;
}

function renderDownloadsPage() {
  const list = document.querySelector("[data-release-list]");

  if (!list) {
    return;
  }

  const platformOrder = [
    "android",
    "windows",
    "windowsPortable",
    "web",
    "server",
    "landing",
    "checksums",
    "linux",
    "macos",
    "ios",
  ];
  list.replaceChildren(
    ...platformOrder
      .filter((key) => downloadConfig[key])
      .map((key) => createDownloadRow(key, downloadConfig[key])),
  );
}

function setRecommendedDownload(platformKey) {
  const primaryDownload = document.querySelector("#primary-download");
  const platformNote = document.querySelector("#platform-note");

  document.querySelectorAll("[data-platform-card]").forEach((card) => {
    card.classList.toggle(
      "is-recommended",
      card.dataset.platformCard === platformKey,
    );
  });

  if (!primaryDownload || !platformNote) {
    return;
  }

  if (
    !platformKey ||
    !downloadConfig[platformKey] ||
    downloadConfig[platformKey].available === false
  ) {
    primaryDownload.textContent = "View all downloads";
    primaryDownload.href = "#downloads";
    primaryDownload.removeAttribute("target");
    primaryDownload.removeAttribute("rel");
    platformNote.textContent = downloadConfig[platformKey]?.available === false
      ? downloadConfig[platformKey].description
      : "We could not identify your platform, so no download will start automatically.";
    return;
  }

  const recommended = downloadConfig[platformKey];
  primaryDownload.textContent = recommended.label;
  primaryDownload.href = recommended.url;

  if (platformKey === "web") {
    primaryDownload.target = "_blank";
    primaryDownload.rel = "noopener noreferrer";
  } else {
    primaryDownload.removeAttribute("target");
    primaryDownload.removeAttribute("rel");
  }

  platformNote.textContent = `Recommended for ${platformNames[platformKey]}. Download starts only after you click.`;
}

function initDownloads() {
  applyDownloadLinks();
  applyReleaseLinks();
  applySiteLinks();
  renderDownloadsPage();
  setRecommendedDownload(detectPlatform());
}

document.addEventListener("DOMContentLoaded", initDownloads);
