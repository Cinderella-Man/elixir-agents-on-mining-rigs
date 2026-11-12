You are writing the request that a developer types to a coding agent working in their own repository, the Elixir
application {{repository}}. The agent gets the repository at the commit just before the change shown below, together
with your request, and nothing else: it never sees the change or the tests shown below. It must then make the change
itself. Afterwards the tests shown below are run on its work.

The task is a {{kind_words}}.

Write as that developer, to the agent, the way a developer really types a request in their own project. No title, no
ticket template, and no "Steps to reproduce", "Expected" or "Actual" headings.

- For a bug fix or any other change that is not a feature: short and plain, the way it is typed in a terminal: what
  goes wrong and where it shows, what it should do instead, and an example value or an error line when the developer
  would have one at hand. A few sentences, with no Markdown structure: no headings and no lists. It must still say
  enough that the fix a reader would make is the one the tests expect.
- For a feature: long and detailed, the way a developer writes it after having been questioned about it in depth
  until every decision was settled: the goal; every decision that was settled, with examples; the edge cases and what
  happens on errors; what is out of scope; what must stay compatible; and the names the rest of the code will use
  (module names, function names and arities, routes, schema fields, configuration keys) where the tests call or read
  them directly, because the agent's code must match those names exactly. Headings and lists are fine here.

Rules:
1. Do not say how to do it: no root cause, no solution steps, no names of files to change or create, no code from the
   change, and no names of functions, modules or fields that only the change introduces and the tests do not use.
2. Name a module, function, field, route or key only when it already exists in the repository, or when the tests
   below call or read it directly.
3. Do not mention tests, test files, test names, checks or grading. Do not mention the pull request, its number, its
   author or any commit.
4. Every behaviour the tests check must follow from your request and the existing code. Do not leave the agent to
   guess a product decision, and do not ask for anything the change and the tests do not support.
5. Write plain English. For anything that is not a feature, keep it as short as the task allows; for a feature, leave
   no settled decision out.
6. Apart from your request, the agent is told this, so do not repeat it:

{{engine_text}}

Answer with the request only, between a line `<statement>` and a line `</statement>`.
{{retry_note}}
## The change (the agent does not see it)

```diff
{{reference_patch}}
```

## The tests run afterwards (the agent does not see them)

```diff
{{reference_tests_patch}}
```
