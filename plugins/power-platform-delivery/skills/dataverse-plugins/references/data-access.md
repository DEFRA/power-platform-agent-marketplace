# Data access

This is how plug-ins, custom workflow activities (CWAs) and the code they call read and write Dataverse in the [scaffold](infrastructure.md). If the project has its own data-access patterns, follow them.

The Dataverse shared project holds four things:

- the generated model, in `Model`;
- the context factory, in `Contexts`;
- query classes and their result types, in `Queries`;
- hand-written entity helpers such as `EntityExtensions`.

Application services use these. Handlers and entry points don't build queries.

## The generated model

- `pac modelbuilder` generates the model into its own namespace, such as `Abc.Dataverse.Model`. Never edit it, and never add a hand-written type to its namespace, because regenerating overwrites both. Hand-written helpers, projections and query result types go beside it, in other namespaces.
- Every table and column that the code names at compile time must be in the model. If one is missing, stop and ask the human to regenerate the model (see `dataverse-schema`). Never add a parallel type, a duplicate, or a late-bound workaround.
- Use `<Entity>.EntityLogicalName`, `<Entity>.Fields.<Name>` and the generated option set enums, never literals. Casing differs between tables, so look names up rather than guess.
- Generated files can be very large. Search them for the type or member you need rather than open them whole.
- Keep the `[assembly: ProxyTypesAssembly]` attribute that the generator writes into the context's file. The platform uses it to return the generated types.

In the examples, `AbcContext`, `abc_Case` and `abc_Applicant` stand for generated types. The builder settings name the context.

## Contexts and identity

| Need | Take | Who disposes it |
| --- | --- | --- |
| Queries as the executing user (the default) | `AbcContext` | The scope. The container creates a context for each class that takes one |
| Another identity, deliberately | `IAbcContextFactory` | The caller, with `using`, within the invocation |

Register both in each composition root whose handlers need them, as `root.Register<AbcContext>();` and `root.Register<IAbcContextFactory, AbcContextFactory>();`. The generated context takes `IOrganizationService`, which each scope supplies as the executing user. The factory takes `IExecutionServiceProvider`, so it can ask only for the identities the host supports (see [infrastructure.md](infrastructure.md#identity)).

```csharp
namespace Abc.Dataverse.Contexts
{
    using Abc.Dataverse.Model;

    /// <summary>
    /// Creates contexts bound to a named identity, for code that must not run as the executing user. The caller owns
    /// each context and must dispose of it.
    /// </summary>
    public interface IAbcContextFactory
    {
        /// <summary>Creates a context for the user the step or process runs as.</summary>
        /// <returns>A new context that the caller must dispose of.</returns>
        AbcContext CreateForExecutingUser();

        /// <summary>Creates a context for the user who started the operation, when the host supports it.</summary>
        /// <returns>A new context that the caller must dispose of.</returns>
        AbcContext CreateForInitiatingUser();

        /// <summary>Creates a context that runs as SYSTEM, when the host supports it. Use it only with a reviewed reason.</summary>
        /// <returns>A new context that the caller must dispose of.</returns>
        AbcContext CreateForSystem();
    }
}
```

```csharp
namespace Abc.Dataverse.Contexts
{
    using System;
    using Abc.Dataverse.Model;
    using Abc.Infrastructure.Execution;

    /// <summary>Creates contexts from the identity-aware services of the current invocation.</summary>
    public sealed class AbcContextFactory : IAbcContextFactory
    {
        private readonly IExecutionServiceProvider serviceProvider;

        /// <summary>Initializes a new instance of the <see cref="AbcContextFactory"/> class.</summary>
        /// <param name="serviceProvider">The current invocation's identity-aware service provider.</param>
        public AbcContextFactory(IExecutionServiceProvider serviceProvider)
        {
            this.serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
        }

        /// <inheritdoc/>
        public AbcContext CreateForExecutingUser()
        {
            return new AbcContext(this.serviceProvider.GetExecutingUserService());
        }

        /// <inheritdoc/>
        public AbcContext CreateForInitiatingUser()
        {
            return new AbcContext(this.serviceProvider.GetInitiatingUserService());
        }

        /// <inheritdoc/>
        public AbcContext CreateForSystem()
        {
            return new AbcContext(this.serviceProvider.GetSystemService());
        }
    }
}
```

- Each class that takes `AbcContext` gets its own, so a setting such as `MergeOption` affects only that class. Share a tracking context only when tracking demonstrably needs it, and then only within one invocation and one identity.
- Never let a context, or a query that hasn't run yet, outlive the invocation. Materialise results with `FirstOrDefault` or `ToList` before returning them.

## Query classes

An application service may query through `IOrganizationService` or a context directly. Extract a query class into `Queries` when the query meets any of these conditions:

- it's reused;
- it's hard to fake, for example because it pages, uses `ExecuteMultiple` or uses FetchXML;
- it reads several tables into a result type of its own.

Don't add a reader or repository interface for each table. It adds indirection without hiding anything. A query class is concrete and takes its context. Tests give it a real context over a mock service (see below).

```csharp
namespace Abc.Dataverse.Queries
{
    using System;
    using System.Linq;
    using Abc.Dataverse.Model;
    using Microsoft.Xrm.Sdk.Client;

    /// <summary>Reads cases, and the values that describe them, for the application services.</summary>
    public sealed class CaseQueries
    {
        private readonly AbcContext context;

        /// <summary>Initializes a new instance of the <see cref="CaseQueries"/> class.</summary>
        /// <param name="context">The invocation's context. These queries only read, so it stops tracking entities.</param>
        public CaseQueries(AbcContext context)
        {
            this.context = context ?? throw new ArgumentNullException(nameof(context));
            this.context.MergeOption = MergeOption.NoTracking;
        }

        /// <summary>
        /// Gets the name of a case and the name of its applicant. The applicant is optional, so this is one query per
        /// table, and the second runs only when the case has an applicant.
        /// </summary>
        /// <param name="caseId">The identifier of the case.</param>
        /// <returns>The case's summary.</returns>
        /// <exception cref="InvalidOperationException">The case doesn't exist, or the user can't read it.</exception>
        public CaseSummary GetCaseSummary(Guid caseId)
        {
            // FirstOrDefault asks Dataverse for a single row, so Take(1) would add nothing.
            var caseQuery =
                from record in this.context.abc_CaseSet
                where record.abc_CaseId == caseId
                select new { record.abc_Name, record.abc_ApplicantId };

            var found = caseQuery.FirstOrDefault()
                ?? throw new InvalidOperationException("The case was not found.");

            string applicantName = null;
            if (found.abc_ApplicantId != null)
            {
                var applicantId = found.abc_ApplicantId.Id;
                var applicantQuery =
                    from applicant in this.context.abc_ApplicantSet
                    where applicant.abc_ApplicantId == applicantId
                    select new { applicant.abc_Name };

                applicantName = applicantQuery.FirstOrDefault()?.abc_Name;
            }

            return new CaseSummary(caseId, found.abc_Name, applicantName);
        }
    }
}
```

```csharp
namespace Abc.Dataverse.Queries
{
    using System;

    /// <summary>The values <see cref="CaseQueries.GetCaseSummary(Guid)"/> reads from a case and its applicant.</summary>
    public sealed class CaseSummary
    {
        /// <summary>Initializes a new instance of the <see cref="CaseSummary"/> class.</summary>
        /// <param name="caseId">The identifier of the case.</param>
        /// <param name="caseName">The name of the case.</param>
        /// <param name="applicantName">The name of the applicant, or <see langword="null"/> if there's none.</param>
        public CaseSummary(Guid caseId, string caseName, string applicantName)
        {
            this.CaseId = caseId;
            this.CaseName = caseName;
            this.ApplicantName = applicantName;
        }

        /// <summary>Gets the identifier of the case.</summary>
        public Guid CaseId { get; }

        /// <summary>Gets the name of the case.</summary>
        public string CaseName { get; }

        /// <summary>Gets the name of the applicant, or <see langword="null"/> if the case has none or it can't be read.</summary>
        public string ApplicantName { get; }
    }
}
```

### Early-bound LINQ

Prefer early-bound LINQ over `QueryExpression`, and `QueryExpression` over FetchXML. If you need FetchXML, say why in a comment. Use query syntax when there are joins. The SDK's client-side provider (9.0.2.60) behaves as follows. This was checked against the SDK, not in a live environment.

- **Always project.** `select record` reads every column. An anonymous type or member initialiser reads only the columns it names.
- `FirstOrDefault()` asks for one row, so `Take(1)` adds nothing.
- A `where` on the primary key becomes a single `Equal` condition.
- The provider sends `RetrieveMultipleRequest` through `Execute`, not `RetrieveMultiple`. Test doubles must set up `Execute`, and must return generated types, not plain `Entity`.
- The provider joins only related tables, and its outer-join support is unclear. Read an optional related record with a second query that runs only when the lookup has a value, as `GetCaseSummary` does. Use a `join` only where every row has the related record.

## Writes

- Write explicitly through `IOrganizationService`, so each write and its timing are visible and testable. Never add `SaveChanges()` on disposal, retries, transaction wrappers or deferred writes.
- An `Update` holds only the attributes that change. Use `GetChanges` (see [infrastructure.md](infrastructure.md#entity-helpers)), and send nothing when nothing changed.
- In a pre-operation step, the handler copies the changed values onto the `Target`, and the platform saves them. It doesn't send its own `Update` for the same record.

## Testing data access

Test a query class against a real context over a strict service mock. `ReturnsRecords` (from the [test support](../assets/UnitTests/Support/OrganizationServiceMockExtensions.cs)) answers a table's queries with the given records. It also returns the list of queries sent, so you can assert columns and conditions with `GetAllConditions` and `UsesOnlyAndFilters`. `VerifyQueried` and `VerifyQueriedAny` count the queries.

```csharp
namespace Abc.UnitTests.Dataverse.Queries
{
    using System;
    using Abc.Dataverse.Model;
    using Abc.Dataverse.Queries;
    using Abc.UnitTests.Support;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Query;
    using Moq;

    [TestClass]
    public sealed class CaseQueriesTests
    {
        private readonly Mock<IOrganizationService> service = new Mock<IOrganizationService>(MockBehavior.Strict);
        private readonly Guid caseId = Guid.NewGuid();
        private readonly Guid applicantId = Guid.NewGuid();
        private readonly CaseQueries queries;

        public CaseQueriesTests()
        {
            this.queries = new CaseQueries(new AbcContext(this.service.Object));
        }

        [TestMethod]
        public void Constructor_WithNoContext_Throws()
        {
            Action act = () => new CaseQueries(null);

            act.Should().Throw<ArgumentNullException>().WithParameterName("context");
        }

        [TestMethod]
        public void GetCaseSummary_ForACaseWithAnApplicant_ReturnsBothNames()
        {
            this.service.ReturnsRecords(abc_Case.EntityLogicalName, this.Case(withApplicant: true));
            this.service.ReturnsRecords(abc_Applicant.EntityLogicalName, new abc_Applicant { Id = this.applicantId, abc_Name = "Applicant 1" });

            var summary = this.queries.GetCaseSummary(this.caseId);

            summary.CaseId.Should().Be(this.caseId);
            summary.CaseName.Should().Be("Case 1");
            summary.ApplicantName.Should().Be("Applicant 1");
        }

        [TestMethod]
        public void GetCaseSummary_Always_ReadsOnlyTheColumnsItNeedsOfTheRequestedCase()
        {
            var caseQueries = this.service.ReturnsRecords(abc_Case.EntityLogicalName, this.Case(withApplicant: false));

            this.queries.GetCaseSummary(this.caseId);

            var query = caseQueries.Should().ContainSingle().Which;
            query.ColumnSet.AllColumns.Should().BeFalse();
            query.ColumnSet.Columns.Should().BeEquivalentTo(abc_Case.Fields.abc_Name, abc_Case.Fields.abc_ApplicantId);
            query.UsesOnlyAndFilters().Should().BeTrue();
            var condition = query.GetAllConditions().Should().ContainSingle().Which;
            condition.AttributeName.Should().Be(abc_Case.Fields.abc_CaseId);
            condition.Operator.Should().Be(ConditionOperator.Equal);
            condition.Values.Should().Equal(this.caseId);
        }

        [TestMethod]
        public void GetCaseSummary_ForACaseWithNoApplicant_ReturnsNoApplicantNameWithoutReadingApplicants()
        {
            this.service.ReturnsRecords(abc_Case.EntityLogicalName, this.Case(withApplicant: false));

            var summary = this.queries.GetCaseSummary(this.caseId);

            summary.ApplicantName.Should().BeNull();
            this.service.VerifyQueriedAny(Times.Once());
        }

        [TestMethod]
        public void GetCaseSummary_WhenTheApplicantCannotBeRead_ReturnsNoApplicantName()
        {
            this.service.ReturnsRecords(abc_Case.EntityLogicalName, this.Case(withApplicant: true));
            var applicantQueries = this.service.ReturnsRecords(abc_Applicant.EntityLogicalName);

            var summary = this.queries.GetCaseSummary(this.caseId);

            summary.ApplicantName.Should().BeNull();
            applicantQueries.Should().ContainSingle()
                .Which.GetAllConditions().Should().ContainSingle()
                .Which.Values.Should().Equal(this.applicantId);
        }

        [TestMethod]
        public void GetCaseSummary_WhenTheCaseIsNotFound_Throws()
        {
            this.service.ReturnsRecords(abc_Case.EntityLogicalName);

            Action act = () => this.queries.GetCaseSummary(this.caseId);

            act.Should().Throw<InvalidOperationException>().WithMessage("The case was not found.");
        }

        private abc_Case Case(bool withApplicant)
        {
            return new abc_Case
            {
                Id = this.caseId,
                abc_Name = "Case 1",
                abc_ApplicantId = withApplicant ? new EntityReference(abc_Applicant.EntityLogicalName, this.applicantId) : null,
            };
        }
    }
}
```

Test the context factory with a strict `IExecutionServiceProvider` mock, so asking for the wrong identity fails the test. This test sends a request through each context it creates:

```csharp
private void AssertSendsRequestsThroughTheService(Func<AbcContext> createContext)
{
    var request = new OrganizationRequest("WhoAmI");
    this.service.Setup(value => value.Execute(request)).Returns(new OrganizationResponse());

    using (var context = createContext())
    {
        context.Execute(request);
    }

    this.service.Verify(value => value.Execute(request), Times.Once());
}
```
