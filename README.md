# Campus Table

A responsive campus food ordering prototype for a student innovation competition.

## Try the demo online

Open the hosted app: <https://xiwaiwai25-commits.github.io/campus-table/>.

Opening `index.html` from GitHub shows the source code; GitHub's file viewer does not run the app. To run it locally, download or clone this repository and use VS Code Live Server, or start the small local server below.

## Run it

From this folder, run:

```powershell
python -m http.server 4173
```

Then visit `http://localhost:4173`.

## Demo flows

- Student: register an account, browse stalls, add an item, check out, and follow the order.
- Vendor: use the Student/Vendor switch and register or log in as a vendor to open Vendor Studio. The vendor workspace is seeded with Nook & Noodle and sample orders.
- Vendor can accept or decline orders, set pickup estimates, update preparation status, edit menu availability, reply to reviews, and view sample sales reports.
- Student can review completed orders, inspect past orders, manage their account, and see a spending summary.

## Prototype scope

This is a front-end prototype. User accounts, menu edits, reviews, and orders are stored in the current browser's local storage. There is no shared server, secure authentication, real-time cross-device notification, or payment processing yet. Product photos use remote Unsplash image URLs. The sales dashboard includes illustrative sample figures when there is not yet enough completed demo data.

Before a live multi-user launch, connect a hosted database and secure authentication, and implement shared order updates and notifications.
