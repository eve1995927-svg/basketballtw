const links = window.GAME_LINKS || {};
const releaseCatalog = window.RELEASE_CATALOG || {};

function isReady(url) {
  return typeof url === "string" && url.startsWith("https://") && !url.includes("REPLACE_ME");
}

document.querySelectorAll("[data-link]").forEach((element) => {
  const platform = element.dataset.link;
  const url = links[platform];

  if (isReady(url)) {
    element.href = url;
    element.target = "_blank";
    element.rel = "noopener noreferrer";
    return;
  }

  element.href = "#download";
  element.classList.add("is-disabled");
  element.setAttribute("aria-disabled", "true");
  element.addEventListener("click", (event) => event.preventDefault());

  const action = element.querySelector("b");
  if (action) action.textContent = "連結準備中";

  const status = document.querySelector(`[data-status="${platform}"]`);
  if (status) status.textContent = platform === "ios" ? "TestFlight 邀請連結準備中" : "Google Play 測試連結準備中";
});

function formatBytes(bytes) {
  if (!Number.isFinite(bytes) || bytes <= 0) return "";
  return `${Math.round(bytes / 1024 / 1024)} MB`;
}

async function loadLatestDirectApk() {
  const cards = document.querySelectorAll("[data-direct-apk]");
  const details = document.querySelector("[data-direct-apk-details]");
  if (!releaseCatalog.supabaseUrl || !releaseCatalog.publishableKey) return;

  const query = new URLSearchParams({
    select: "version_name,version_code,download_url,sha256,file_size_bytes,minimum_os,release_notes,created_at",
    platform: "eq.android",
    channel: "eq.direct",
    published: "eq.true",
    order: "version_code.desc",
    limit: "1"
  });

  try {
    const response = await fetch(`${releaseCatalog.supabaseUrl}/rest/v1/app_releases?${query}`, {
      headers: {
        apikey: releaseCatalog.publishableKey,
        Authorization: `Bearer ${releaseCatalog.publishableKey}`
      }
    });
    if (!response.ok) throw new Error(`release catalog ${response.status}`);
    const [release] = await response.json();
    if (!release || !isReady(release.download_url)) return;

    cards.forEach((card) => {
      card.href = release.download_url;
      card.target = "_blank";
      card.rel = "noopener noreferrer";
      card.classList.remove("is-disabled");
      card.removeAttribute("aria-disabled");
    });

    const version = document.querySelector("[data-apk-version]");
    const status = document.querySelector("[data-apk-status]");
    const action = document.querySelector("[data-apk-action]");
    if (version) version.textContent = `ANDROID APK · ${release.version_name} (${release.version_code})`;
    if (status) {
      const size = formatBytes(Number(release.file_size_bytes));
      const os = release.minimum_os || "Android 7+";
      status.textContent = [size, os, "ARM64", "SHA-256 已驗證"].filter(Boolean).join(" · ");
    }
    if (action) action.textContent = "下載 APK →";
    if (details) {
      details.href = release.download_url;
      details.target = "_blank";
      details.rel = "noopener noreferrer";
      details.removeAttribute("aria-disabled");
      details.textContent = `下載 ${release.version_name} 與查看校驗碼 →`;
      details.title = release.sha256 ? `SHA-256：${release.sha256}` : "";
    }
  } catch (error) {
    console.warn("Unable to load verified APK release", error);
  }
}

loadLatestDirectApk();

const lightbox = document.querySelector(".lightbox");
const lightboxImage = lightbox.querySelector("img");

document.querySelectorAll("[data-image]").forEach((button) => {
  button.addEventListener("click", () => {
    lightboxImage.src = button.dataset.image;
    lightboxImage.alt = button.querySelector("img").alt;
    lightbox.showModal();
  });
});

lightbox.querySelector(".lightbox-close").addEventListener("click", () => lightbox.close());
lightbox.addEventListener("click", (event) => {
  if (event.target === lightbox) lightbox.close();
});
