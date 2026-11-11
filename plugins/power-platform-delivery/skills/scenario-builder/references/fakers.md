# Fakers

Anything an event generates, rather than takes from a configured override, comes from a [Bogus](https://github.com/bchavez/Bogus) `Faker`. Never use a hard-coded value or ad hoc random logic. Each event holds its faker in an overridable field with a default instance, so:

- a test gets realistic, valid data for everything it doesn't configure;
- a test that cares about a value overrides it through the event's builder, never by reaching into the faker;
- the rules for a record type live in one place, not across events and tests.

## Conventions

- Default to the `en_GB` locale, or the locale of the service's users.
- A faker must always produce a record valid enough to pass the platform's validation. It must never be the reason a test fails.
- A faker for a Dataverse early-bound entity **inherits `RecordFaker<TEntity>`**, not `Faker<TEntity>`. Copy [RecordFaker.cs](../assets/RecordFaker.cs) into the shared test-data project, in the project's namespace. It sets the locale and a random `Id`, so a faker defines rules only for its own columns.
- One folder per entity, with an abstract base faker for the entity and a concrete subclass for each business variant, such as `CaseFaker` and `UrgentCaseFaker`.
- Fakers compose. `InspectionFaker` can take a `CaseFaker` in its constructor. An event builder exposes `With<Thing>Overrides(Action<TFaker> configure)` so a test can reach a nested faker without a builder method for every column.
- Put named variants in Bogus rule sets, with their names as constants in one place, and generate one with `Generate("<rule set>")` instead of writing a second faker for a small difference.
- Give a faker `With*` methods that return the faker for the variations tests need, such as `WithApplicant(Guid id)`.
- Test-only enums and types that aren't Dataverse entities, such as the case type or a persona, live in a `Model` folder. Gherkin transformations produce them, and builders and steps take them as parameters instead of strings.
- Log the key generated values (see [common-conventions.md](../../test-foundations/references/common-conventions.md)), so a failure can be reproduced from the logs.

## Look up the columns first

Check two things separately before writing rules. They come from different sources, so don't derive one from the other.

1. **The constraints on each column**: required level, maximum length, range, format, date behaviour, option values and whether it can be set on create. Run `Get-EntityFieldMetadata.ps1` from the `dataverse-schema` skill against the unpacked solution, once per table, not once per column.
2. **The generated property name and CLR type**, taken from the early-bound model. Run `Get-EntityPropertyClrType.ps1` from `dataverse-schema`. The model builder's casing varies per column, and nullable wrapping, option set enums and collection types depend on the generated code.

Then:

- truncate generated strings to the maximum length, and keep numbers inside the range;
- set only columns that can be set on create;
- never give a date-only column a time of day;
- use only values from the option set;
- use the reported property name and type exactly, including `Nullable<T>` and enum types. Never strip a nullable to its underlying type or assume a choice is an `int` or a `string`;
- if the model lacks a column the solution has, regenerate it with `dataverse-schema` rather than use late-bound names.

## Example

```csharp
public class InspectionFaker : RecordFaker<abc_Inspection>
{
    public InspectionFaker()
    {
        this.RuleFor(i => i.abc_ScheduledOn, f => f.Date.Soon().Date); // date-only column
        this.RuleFor(i => i.abc_Notes, f => f.Lorem.Sentence().Truncate(500)); // 500 is the column's maximum length
        this.RuleFor(i => i.abc_Outcome, f => f.PickRandom<abc_Inspection_abc_Outcome>());
    }

    public InspectionFaker WithCase(Guid caseId)
    {
        return (InspectionFaker)this.RuleFor(i => i.abc_CaseId, new EntityReference(abc_Case.EntityLogicalName, caseId));
    }
}
```

`Truncate` stands for whatever helper the project uses. Take the length, and the option set type, from the lookups above rather than from this example.
