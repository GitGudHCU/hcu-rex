# HCU-Rex

Pixel-Endless-Runner durch die HCU: über Mülleimer springen, unter Fluchtwegschildern ducken,
Tassen einsammeln und ans Café zurückbringen – vom Bachelor bis zur Professur.

- `index.html` – das ganze Spiel inklusive HCU-Bestenliste (eine Datei, keine Abhängigkeiten)
- `supabase-setup.sql` – Datenbank für die Bestenliste (einmal im Supabase SQL Editor ausführen)
- `netlify.toml` – Netlify veröffentlicht jede Änderung an `main` automatisch

Gezählt werden nur zurückgebrachte Tassen; Hüte gibt es für Bachelor, Master und Promotion.
Bestenliste: Supabase (Region EU/Irland). Gespeichert werden Name, Tassen, Spieldauer, ein unsichtbarer Fortschrittswert für die Plausibilitätsprüfung und der Zeitpunkt.
Einträge lassen sich im Supabase-Dashboard in der Tabelle `scores` löschen.
