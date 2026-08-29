const links = window.GAME_LINKS || {};

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
