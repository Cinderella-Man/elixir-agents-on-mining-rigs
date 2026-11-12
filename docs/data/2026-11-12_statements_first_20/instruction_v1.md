You are writing the task statement for one coding task in the Elixir application {{repository}}. A developer will
get the application's repository at the commit just before the change shown below, together with your statement, and
nothing else: they never see the change or the tests shown below. They must then make the change themselves.
Afterwards the tests shown below are run on their work.

The task is a {{kind_words}}.

Write the statement the way the application's maintainer would write the ticket for this work.

- For a bug fix: start with one sentence that says what goes wrong, in what situation, and asks for it to be fixed.
  Then add only the facts a developer needs where more than one fix would be reasonable and the tests expect one of
  them: an example input, the action that shows the problem, a rule that must keep holding.
- For a feature: write what a developer would know after asking the maintainer every question that matters: the
  goal; every behaviour that was decided, with examples; edge cases and what happens on errors; what is out of scope;
  what must stay compatible; and the public interface that the tests call or read directly (module names, function
  names and arities, routes, schema fields, configuration keys), because the developer's code must match those names
  exactly.

Rules:
1. Do not say how to do it: no root cause, no solution steps, no names of files to change or create, no code from the
   change, and no names of functions, modules or fields that only the change introduces and the tests do not use.
2. Name a module, function, field, route or key only when it already exists in the repository, or when the tests
   below call or read it directly.
3. Do not mention tests, test files, test names, checks or grading. Do not mention the pull request, its number, its
   author or any commit.
4. Every behaviour the tests check must follow from your statement and the existing code. Do not leave the developer
   to guess a product decision, and do not ask for anything the change and the tests do not support.
5. Write plain English. Markdown is allowed. Keep it as short as the task allows.
6. Apart from your statement, the developer is told this, so do not repeat it:

{{engine_text}}

Answer with the statement only, between a line `<statement>` and a line `</statement>`.
{{retry_note}}
## The change (the developer does not see it)

```diff
{{reference_patch}}
```

## The tests run afterwards (the developer does not see them)

```diff
{{reference_tests_patch}}
```
