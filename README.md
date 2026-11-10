# MealSync

**Live app:** [mealsync](https://xiwaiwai25-commits.github.io/campus-table/)\
**Source code:** [GitHub repository](https://github.com/xiwaiwai25-commits/campus-table)

MealSync is a campus food ordering prototype. Guests can browse; Demo students can place shared sample orders; Demo vendors can manage sample stalls. Registered students and vendors use real account data. New accounts require a unique username, a verified email address, and a password; students also need a TP number (`TP` plus six digits), while vendors provide stall details instead. Password inputs include a visibility toggle. New accounts log in with email and password. Existing accounts continue using username and password. Password reset is available to accounts with a verified email address. Students can cancel a pending order, or an accepted order when the vendor's estimate is more than 60 minutes. Payments are not enabled.

## Run locally on Windows

Run `start-demo.bat` from this folder. It starts a local server bound to `127.0.0.1` and opens **http://127.0.0.1:4173/**. Python must be installed. To stop the server, close its command window.

Alternatively, run this command in the repository folder and open **http://127.0.0.1:4173/**:

```powershell
python -m http.server 4173 --bind 127.0.0.1
```

## Demo

Choose **Try the interactive demo**, then **Sample Student** or a sample stall. Demo changes are shared across browsers and kept separate from real accounts. **Account details → Reset shared demo** clears Demo orders and reviews and restores the 8 sample menus. Guests can browse; ordering and account features require login. Demo vendors can manage sample menus and weekly opening hours. Registered vendors can manage their own menus, orders and weekly opening hours. Registered users see real store data.
