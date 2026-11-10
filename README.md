# MealSync

**Live app:** [https://xiwaiwai25-commits.github.io/campus-table/](https://xiwaiwai25-commits.github.io/campus-table/)  
**GitHub repository:** [https://github.com/xiwaiwai25-commits/campus-table](https://github.com/xiwaiwai25-commits/campus-table)

MealSync is a campus food ordering prototype for students and campus vendors. Guests can browse sample stalls, Demo accounts can place and manage shared sample orders, and registered accounts use real store and order data. Registration uses a username and password; student accounts also enter a TP number in the format `TP` plus six digits. No email is collected. Payment processing is not enabled.

The Supabase JavaScript client is served from this repository, so the app does not depend on third-party CDN scripts. Internet access is still required to reach the shared Supabase backend.

## Run locally with Live Server

Open this folder in VS Code, open `index.html`, and choose **Go Live** from the status bar (or right-click the file and choose **Open with Live Server**). Keep VS Code open while using the site. Live Server works best for the local preview.

## Optional local Python preview

The Python preview was also opened successfully in Chrome on this computer. In a terminal at the repository folder, run:

```powershell
python -m http.server 4173 --bind 127.0.0.1
```

Keep the terminal open and visit **http://127.0.0.1:4173/** in your browser. Stop with `Ctrl+C`. Do not double-click the HTML file: `file://` only shows a limited preview. Shared orders need an internet connection to Supabase.

## Demo

Choose **Try the interactive demo**, then Sample Student or one of four sample stalls. Sample orders and menu edits are shared across browsers and separate from real accounts. **Account details → Reset shared demo** clears sample orders and restores the sample menus for everyone. Guest browsing is read-only. Registered users see live store data only.
