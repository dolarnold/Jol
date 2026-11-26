# Changelog

What changed in the JOL app, newest first. The version is `version:` in
`pubspec.yaml` (the part before `+`). Numbers are MAJOR.MINOR.PATCH:

- **PATCH** (1.0.1): fixes only.
- **MINOR** (1.1.0): new features.
- **MAJOR** (2.0.0): big changes, e.g. moving to a new API version.

## [Unreleased]

### Added (social)
- Friends: follow people; when you follow each other you're friends. Event cards and pages show which friends are going, with their photos. Profile → Friends has your friend code, people to follow back, and a switch to hide what you're going to.
- The wall: every event page has a wall where guests going (and the host) post before the night. Hosts can remove posts; anyone can report one.
- Sharing to WhatsApp sends the event link with its preview card (cover, name, date, price).
- Split with friends: at checkout, book for the group and let each friend pay their own share. Places are held for 24 hours; if not everyone pays, everyone is refunded. Links (jolnow.co.za/split/…) open the app.

### Changed
- The app talks to https://jolnow.co.za/api/v1. Shared event links on jolnow.co.za (and www) open the app; old links on the Laravel Cloud address still do.

### Added (24 Nov)
- Host details: "Verify your identity" with Didit. It opens in the browser, and the result shows when you come back. The host checklist includes it.
- Student verification is real now. The code is sent to the university email (only domains JOL lists), lasts 24 hours, and is checked by the server.
- Investec in the bank list.

### Added
- Live splash screen: the JOL pin drops in, bobs, looks around and blinks while the app checks your sign-in. With "reduce motion" on it stays still.
- Going out / Hosting switch on one account (Me tab and host dashboard). The app remembers your choice and opens in that mode next time. In "Going out" mode the Host tab explains hosting and offers the switch.
- Host details & payouts screen:
  - mobile number, business name, VAT number and business address;
  - bank account, with each bank's universal branch code filled in;
  - ID document and bank statement uploads (a photo, or a PDF or image file via `file_picker`, up to 4 MB), kept private;
  - email verification link.
  - Existing bank details can only be changed on the website.
- "Before you sell tickets" checklist on the host dashboard.
- Event form:
  - "Other" category with a box to type what kind of event it is;
  - ticket types can be a group deal (one price for several people) or a table (seats per table, optional table names);
  - price limits are checked per person.
- Login: show/hide password and "Forgot password?" (opens the website). Sign-up: show/hide password.

### Removed
- The "View as" card on Discover (replaced by the Going out / Hosting switch). The out-of-date "student verification is not connected" note on sign-up.

### Changed
- Buying several tickets is one purchase: one payment and one Paystack checkout (it used to be one checkout per ticket, and only the first went through).
- The "payment pending" screen says to finish paying on the Paystack page.

## [1.2.0] - 2026-11-15

### Added
- Group deals and tables: shown on the ticket screen ("Group of 4", "Table for 8"), with a choice of free tables. Each person gets their own ticket; the table shows on the ticket.
- Hosting: Repeat event and Message guests in an event's menu.
- Tickets: Report a problem with this payment, which goes to the JOL team.
- Me → Help: questions and answers with search, Message JOL support, and the language for emails and web pages (English, Afrikaans, isiXhosa).
- Me → JOL credit: balance, gift card codes, your invite code to share, and a friend's code. Checkout offers Pay with JOL credit when it covers the order.
- The event form's categories and poster styles come from the JOL team's list (Admin → Categories & cities).
- GitHub Actions run `flutter analyze` and `flutter test` on every push (`deploy/github-checks.yml`, copy to `.github/workflows/`).

## [1.1.0] - 2026-11-15

### Added
- Door screen for the host, co-hosts and door staff (Staff → Open door, or Door in a hosted event's menu): scan tickets with the camera, a guest list to let RSVP guests in by name (with plus-ones and walk-ins), and selling tickets at the door for cash or the host's own card machine.
- Works without signal: save the list on the phone before doors open. Checks, check-ins and door sales are sent when the signal is back, and anything that needs a look (like a ticket let in on two phones) is shown.
- Hosted events count guests let in from the door guest list.

### Changed
- Staff: the door now opens per event, with scanning, the guest list and door sales in one place.

## [1.0.0] - 2026-11-15

First numbered version. Everything built so far:

### Added
- Welcome, sign-up with phone number, sign-in with two-step code, interests and student verification.
- Discover feed by category, search, map of events nearby, Top List and private events by invite code.
- Event page: details, location, follow the host, rate the event, report it, message the organiser, ask to promote it, share it.
- RSVPs and tickets: tiers, promo codes, checkout, QR tickets with ticket page and calendar, transfers, refund requests, waitlist and chip-in funds.
- Hosting from the app: create and edit events with a map location picker, guest lists and ticket scanning.
- Door staff: ask to work an event's door, then scan tickets.
- Inbox with notifications, support messages and account warnings; push notifications.
- Profile, light and dark mode, privacy and data (download, delete account, marketing choice).
- Shared event links (https://…/e/CODE) open in the app.
- "Update JOL" screen for versions that are too old, and a note when a newer version is out.
- Crash reports through Firebase Crashlytics (release builds only).
