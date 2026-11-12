I want to add a league calendar download to the fantasy league show page.

The show page should get a new card below the league header and above the standings chart. It should have the heading "Download League Calendar", a short explanation that the download is an all-day calendar of key dates and that exact deadline times are not in it (users should refer to the championships page), and a link/button labelled "Download". The link goes to `GET /fantasy_leagues/:fantasy_league_id/calendar_download` through the existing authenticated league routes.

That URL should send back a downloadable `.ics` attachment with content type `text/calendar`, not an HTML page. Generate it on demand from the league's current data; do not store it.

The file should use date-only all-day entries. Put the entry fee deadline for The 338 Challenge on November 1 of the league's championship start year. For every championship already returned for the league, include the championship date as `338 Championship: <championship title>`. Also include the waiver deadline, and if the waiver and trade deadlines fall on the same date, use one combined event titled `<championship title> 338 Waiver and Trade Deadline`; otherwise use separate `<championship title> 338 Waiver Deadline` and `<championship title> 338 Trade Deadline` events on their respective dates.

Each event should have the date in `YYYYMMDD` form under `DTSTART`, plus a unique `UID` and a `DTSTAMP` generated when the file is built. The result must be a valid iCalendar file that standard calendar apps can import, with the normal calendar metadata and one event block per event. If a league has no championships, it should still produce a valid file with just the entry fee deadline. For a missing league id, just let the existing lookup behavior stand; don't add a special error page.

Keep the rest of the league show page unchanged apart from adding this card. No schema, migration or persistence changes. Out of scope: subscriptions, editing events, timezone conversion, and including exact deadline times.
