We need private leagues whose `navbar_display` is `:hidden` to be usable by the people who can already see them instead of being limited to primary leagues everywhere.

The main navigation rule should be exposed as `Ex338Web.Layouts.main_navigation?/1`, taking a `%Ex338.FantasyLeague{}` and returning a boolean. It must be a pure predicate over the struct fields, not a query. It returns true for any league with `navbar_display: :primary`, regardless of privacy. It also returns true for a private league with `private?: true` and `navbar_display: :hidden`. It returns false for a public league with `navbar_display: :hidden`, for a private league with `navbar_display: :archived`, and for every other combination. So:

- `%FantasyLeague{private?: true, navbar_display: :hidden}` → true
- `%FantasyLeague{private?: false, navbar_display: :primary}` → true
- `%FantasyLeague{private?: false, navbar_display: :hidden}` → false
- `%FantasyLeague{private?: true, navbar_display: :archived}` → false

The same rule must drive which leagues appear in the main navigation, both the user/team dropdown and the sidebar “Fantasy Leagues” sections. A private hidden league should appear there for a user who is allowed to see that private league, and it must not appear for anyone else. Existing visibility rules stay authoritative: public leagues are visible to everyone, admins see all leagues, and private leagues are visible only to their members/owners. Do not introduce a second visibility rule.

The home page league list must use the same criteria. The league collection assigned to `:fantasy_leagues` should contain the leagues visible to the current user that qualify for main navigation. A hidden private league must show on `/` for an owner of that league and for an admin, including its league name in the page, and must be absent for a logged-in user who is not a member. A public hidden league and a private archived league stay absent. A logged-out visitor must only get public primary leagues; no hidden private leagues are exposed. Existing public primary leagues must continue to show exactly as before, and the included leagues must still have their standings data loaded the way home page league cards expect.

Keep the existing `:fantasy_leagues` assignment on the home page and the existing URLs. Do not change league schemas, allowed `navbar_display` values, league creation forms, or the existing private-league access rules. Archived leagues stay out of the main navigation, and sorting/display behavior for the leagues that were already shown should remain unchanged.
