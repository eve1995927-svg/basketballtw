/*
 * Public download links live here so a future custom domain only needs one
 * small edit. Keep unavailable test links empty instead of showing dead URLs.
 */
window.GAME_LINKS = Object.freeze({
  android: "",
  ios: ""
});

// This is a public browser key, not a service-role secret. Database policies
// only permit anonymous clients to read rows explicitly marked as published.
window.RELEASE_CATALOG = Object.freeze({
  supabaseUrl: "https://oqvvtjmgasdnherqbllh.supabase.co",
  publishableKey: "sb_publishable_oDE8MMcMCvM2qnmmsYLG8Q_m605nr3h"
});
