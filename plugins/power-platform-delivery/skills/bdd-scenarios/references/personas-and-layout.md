# Personas and layout

## Login step

- Start every scenario in which someone uses the app with exactly one login step, taken from the project's existing login bindings, such as `Given I am logged in to the 'Case Management' app as 'Inspector'`. Search the step index for them.
- Take the app name from the model-driven app's `AppModule.xml` and the persona from the project's `Persona` enum (see the [project-facts procedure](../../power-platform-standards/references/project-facts.md)). A persona is a named set of security roles. Never invent one.
- Choose the least privileged persona that meets the precondition. When the scenario tests permissions, the persona is the point of the scenario.
- A scenario runs as one user. Don't switch persona part-way through. If two people interact, such as one submitting and another approving, split the scenario or make the first person's action a precondition.
- Use a "with no other roles" login variant, if the project has one, only when the scenario asserts that access is limited to the named roles.
- Leave the login step out when nobody uses the app in the scenario: when every step is set up, triggered and checked at data level, such as a scheduled process whose result is checked through the API.
- If no persona has the roles a scenario needs, report it as a testability concern. Adding a persona is test code work.

## Layout

Follow the repository's existing layout where it has one. Otherwise:

- use one folder per table or business entity, named in the plural, such as `Inspections`;
- use one feature file per user action, such as `Record an inspection outcome.feature`. Don't combine actions such as creating and updating in one file;
- make the `Feature:` line match the file name;
- write one scenario per genuine business scenario, named specifically enough to tell it apart from its siblings. Never use names such as "Success" or "Test 1";
- keep a "View" feature to structural, read-only checks, such as tabs, fields and view columns. Whether a command is available belongs in that command's own feature;
- add to the existing feature file for the same entity and action rather than create a duplicate.

```text
Cases/
    View cases.feature
    View a case.feature
Inspections/
    Record an inspection outcome.feature
```
