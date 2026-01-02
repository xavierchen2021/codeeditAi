import en from "./translations/en.json";

export type Language = "en";

export const languages: Record<Language, string> = {
  "en": "English",
};

export const translations: Record<Language, typeof en> = {
  en,
};

const STORAGE_KEY = "aizen-language";

export function detectLanguage(): Language {
  return "en";
}

export function saveLanguage(lang: Language): void {
  localStorage.setItem(STORAGE_KEY, lang);
}

export function getTranslation(lang: Language, key: string): string {
  const keys = key.split(".");
  let value: any = translations[lang];

  for (const k of keys) {
    value = value?.[k];
    if (value === undefined) {
      value = translations.en;
      for (const k2 of keys) {
        value = value?.[k2];
      }
      break;
    }
  }

  return value || key;
}
