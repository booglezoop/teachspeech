import { createClient } from "@supabase/supabase-js";

const config = window.TEACHSPEECH_SUPABASE;

if (!config?.url || !config?.publishableKey) {
  throw new Error("Supabase configuration is missing.");
}

const supabase = createClient(config.url, config.publishableKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

const loginPanel = document.querySelector("#login-panel");
const appPanel = document.querySelector("#app-panel");
const loginForm = document.querySelector("#login-form");
const loginError = document.querySelector("#login-error");
const accountSummary = document.querySelector("#account-summary");
const appMessage = document.querySelector("#app-message");
const signOutButton = document.querySelector("#sign-out");

function showLogin() {
  loginPanel.hidden = false;
  appPanel.hidden = true;
}

function showApp() {
  loginPanel.hidden = true;
  appPanel.hidden = false;
}

function showLoginError(message) {
  loginError.textContent = message;
  loginError.hidden = false;
}

async function loadAccount() {
  const { data: sessionData, error: sessionError } = await supabase.auth.getSession();

  if (sessionError) throw sessionError;

  const user = sessionData.session?.user;
  if (!user) {
    showLogin();
    return;
  }

  const { data: profile, error: profileError } = await supabase
    .from("staff_profiles")
    .select("display_name, role, is_active")
    .eq("user_id", user.id)
    .maybeSingle();

  if (profileError) throw profileError;

  if (!profile || !profile.is_active) {
    await supabase.auth.signOut();
    showLoginError("Нямате активен профил за достъп до календара.");
    showLogin();
    return;
  }

  if (!["admin", "specialist"].includes(profile.role)) {
    await supabase.auth.signOut();
    showLoginError("Ролята на профила не позволява достъп.");
    showLogin();
    return;
  }

  accountSummary.textContent = `${profile.display_name || "Член на екипа"} · ${
    profile.role === "admin" ? "Администратор" : "Специалист"
  }`;

  appMessage.textContent =
    profile.role === "admin"
      ? "Администраторски достъп. Ще добавим управление на всички графици."
      : "Достъп до личния график. Ще добавим само разрешените за вас срещи.";

  showApp();
}

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  loginError.hidden = true;

  const submitButton = loginForm.querySelector('button[type="submit"]');
  submitButton.disabled = true;

  try {
    const formData = new FormData(loginForm);
    const { error } = await supabase.auth.signInWithPassword({
      email: String(formData.get("email")).trim(),
      password: String(formData.get("password")),
    });

    if (error) throw error;

    loginForm.reset();
    await loadAccount();
  } catch (error) {
    console.error("Internal calendar sign-in failed:", error);
    showLoginError("Входът не беше успешен. Проверете данните си и опитайте отново.");
  } finally {
    submitButton.disabled = false;
  }
});

signOutButton.addEventListener("click", async () => {
  signOutButton.disabled = true;

  try {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    showLogin();
  } catch {
    appMessage.textContent = "Изходът не беше успешен. Опитайте отново.";
  } finally {
    signOutButton.disabled = false;
  }
});

supabase.auth.onAuthStateChange((_event, _session) => {
  // Avoid making another Supabase request inside the auth callback.
  queueMicrotask(() => {
    loadAccount().catch((error) => {
      console.error("Could not load staff profile:", error);
      showLoginError("Профилът не можа да бъде зареден. Опитайте отново.");
      showLogin();
    });
  });
});

loadAccount().catch((error) => {
  console.error("Could not initialize internal calendar:", error);
  showLoginError("Вътрешният календар не можа да се зареди.");
  showLogin();
});
