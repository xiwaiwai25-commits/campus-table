# MealSync

A shared campus food ordering web app for students and independent campus vendors.

## Live app

[Open MealSync](https://xiwaiwai25-commits.github.io/campus-table/)

The app uses Supabase for accounts, store menus, orders, ratings, and live order updates. Register as a student or vendor. Students can browse without signing in; an account is required to place an order. Email and password are used to log in. Student TP number and vendor store name are profile details.

## Run locally

Open this folder in VS Code and use Live Server, or run:

```powershell
python -m http.server 4173
```

Then visit `http://localhost:4173`.

## Core flows

- Students can browse/search stores and menus, place an order with a note, follow live status, cancel before acceptance (or when the vendor sets an estimate over 60 minutes), review completed orders, and see order history and monthly spending.
- Vendors can edit their store and menu, mark products unavailable, accept or decline orders with a reason, set prep estimates, update order status, reply to reviews, and view reports based on actual orders.
- Guests can browse but need a registered account to add to bag and order.

No payment processing is enabled. The site is hosted on GitHub Pages; shared data and authentication are provided by the separate Supabase project.
