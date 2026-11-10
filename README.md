# MealSync

**Live app:** [mealsync](https://xiwaiwai25-commits.github.io/campus-table/)\
**Source code:** [GitHub repository](https://github.com/xiwaiwai25-commits/campus-table)

MealSync is a campus food ordering prototype. Guests can browse; Demo students can place shared sample orders; Demo vendors can manage sample stalls. Registered students and vendors use real account data. Student registration requires a TP number (`TP` plus six digits). Payments are not enabled.

## Run locally on Windows

Run `start-demo.bat` from this folder. It starts a local server and opens **http://localhost:4173**. Python must be installed. To stop the server, close its command window.

Alternatively, run this command in the repository folder and open **http://127.0.0.1:4173/**:

```powershell
python -m http.server 4173 --bind 127.0.0.1
```

## Demo

Choose **Try the interactive demo**, then **Sample Student** or a sample stall. Demo changes are shared across browsers and kept separate from real accounts. **Account details → Reset shared demo** clears Demo orders and reviews and restores the 8 sample menus. Guests can browse; ordering and account features require login. Registered users see real store data.
