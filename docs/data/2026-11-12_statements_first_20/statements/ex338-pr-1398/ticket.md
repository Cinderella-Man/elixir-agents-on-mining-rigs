I want to add per-team draft grades and analysis to the commissioner league edit flow and show them on the draft picks page.

Data model and storage:

- Add two nullable fields to fantasy teams: `draft_grade` as a string and `draft_analysis` as text. Existing teams without values must remain valid, so no backfill is needed.
- `draft_grade` is free text, not an enum. It must accept values like `A`, `B+`, `C`, `D`, or `F`, with no format or length restriction.
- `draft_analysis` holds rich-text HTML and is nullable. Store the HTML as entered.
- The normal fantasy team changeset should allow both fields so teams can be created or updated with them.
- The commissioner-only team changes need to handle `team_name`, `draft_grade`, and `draft_analysis`. Team name is required and has a 16-character maximum. No other team attributes should be editable through this nested form.

Commissioner league edit page:

- Keep the existing commissioner league edit route and the existing `#fantasy_league-form` form.
- When the edit page opens, load the league’s fantasy teams with the league, ordered alphabetically by `team_name`, and show them in a “Fantasy Teams” section.
- For each team show the team name, a “Draft Grade” text input, and a “Draft Analysis” rich-text editor. The editor should not expose file/attachment tools, and LiveView validation re-renders should not wipe out what is being typed.
- The form needs to submit nested team params under the `fantasy_teams` key, keyed by index such as `"0"`, `"1"`, etc. Each existing team entry must include its `id` in a hidden field and must carry `team_name`, `draft_grade`, and `draft_analysis`.
- Saving the form should update both the league and its existing teams together. Existing teams must be updated by id, not duplicated. A changed team name must be persisted. Adding or deleting teams through this form is out of scope.
- Keep the existing league validations and success behavior: league name, year, and division remain required, and successful saves should still show the existing success message.
- The validation event should also use the nested league/team changeset so team field changes and validation errors render correctly.

Draft picks page:

- On the existing league draft picks page, show a grades section only when every team in that league has a non-nil `draft_grade`. If no teams have grades, do not show the section.
- For an admin, show the section as a preview as soon as at least one team has a grade, even if other teams are not graded yet. If no team has a grade, hide it even for admins. Non-admin users should not see partial grades.
- The section heading must read `Draft Grades` followed by an ampersand and then `Analysis`, with spaces around the ampersand.
- List all the league’s teams sorted alphabetically by `team_name`. Each team card should show the team name, the grade formatted as `Grade: <draft_grade>` (for example `Grade: A` and `Grade: B+`), and the `draft_analysis` rendered as HTML so rich text displays correctly. If analysis is blank, the card can show the grade with no analysis text.
- The section should depend only on the teams’ grades, not on whether draft picks exist.

Keep the rest of the draft picks page, league editing, and existing team behavior working as they do now. Do not add grade calculations, a separate team edit page, or any new routes.
