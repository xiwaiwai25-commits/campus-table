# MealSync

**Live app:** [https://xiwaiwai25-commits.github.io/campus-table/](https://xiwaiwai25-commits.github.io/campus-table/)  
**GitHub repository:** [https://github.com/xiwaiwai25-commits/campus-table](https://github.com/xiwaiwai25-commits/campus-table)

MealSync is a campus food ordering web app for students and campus vendors. Guest visitors can browse; a registered account is required for real orders. Sample accounts are available from **Try demo** and need no email. Payment processing is not enabled.

The Supabase JavaScript client is served from this repository, so the app does not depend on third-party CDN scripts. Internet access is still required to reach the shared Supabase backend.

## Run in GitHub Codespaces

In the Codespace terminal, from the repository folder, start the preview server:

```bash
python -m http.server 4173 --bind 0.0.0.0
```

In VS Code, open the **Ports** panel. If port `4173` is not listed, choose **Forward a Port** and enter `4173`. Then use **Open in Browser** for that port (or click the forwarded URL shown by Codespaces). Do not enter `localhost:4173` in a browser outside the Codespace; that address points to your own computer. Keep the terminal process running while you use the preview. Keep the port private unless you intend to share the preview publicly.

## Run on your computer

VS Code Live Server works too. To use Python instead, open a terminal in this repository folder and run:

```powershell
python -m http.server 4173 --bind 127.0.0.1
```

Keep the terminal open and visit **http://127.0.0.1:4173/** in your browser. Stop the server with `Ctrl+C`. Do not double-click the HTML file: `file://` can only show a limited preview; real shared orders need the web server and internet.

## Demo

Choose **Try demo**, then Sample Student or one of four sample stalls. Demo orders are shared across browsers and separate from real accounts.
