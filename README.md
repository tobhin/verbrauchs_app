\# Verbrauchs App

Eine Flutter-App zur Erfassung und Visualisierung von Verbrauchsdaten (z. B. Strom, Wasser) mit Exportfunktionen und Text recognition für Zählerstände.



\## Installation

1\. Installiere Flutter: https://flutter.dev/docs/get-started/install

2\. `flutter pub get`

3\. `flutter run`



\## Funktionen

\- Erfassung von Verbrauchsdaten

\- Visualisierung als Balkendiagramm

\- Export in CSV/Excel/PDF

\- Text recognition mit ML Kit

\- Benachrichtigungen für Zählerstände

\- Backup und Wiederherstellung der Datenbank



\## Abhängigkeiten

\- Flutter SDK: >=3.4.0 <4.0.0

\- Wichtige Packages: `fl\_chart`, `google\_mlkit\_text\_recognition`, `sqflite`, `flutter\_local\_notifications`



\## Entwicklung

\- \*\*Datenbank\*\*: SQLite mit `sqflite` für lokale Speicherung

\- \*\*OCR\*\*: Google ML Kit für Texterkennung

\- \*\*Diagramme\*\*: `fl\_chart` für Visualisierung

