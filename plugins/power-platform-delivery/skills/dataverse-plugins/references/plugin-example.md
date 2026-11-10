# Worked example: a configurable plug-in

The capability is **copy configured attributes from the triggering record to a related record**. It is named for that capability, not for any first use. The lookup and the attributes are in the step's unsecure configuration, so the first requirement (copy an inspection's outcome to its case) is one row of configuration, and the next similar requirement is another step, not another plug-in.

The code is taken unchanged from a solution with the structure in [project-structure.md](project-structure.md) and the infrastructure in [infrastructure.md](infrastructure.md). It builds without warnings, and the tests pass with MSTest, FluentAssertions 7 and Moq. Some tests are left out for length, and each section says which. `Abc` is a placeholder namespace, and the tables and columns are illustrative. Adapt the shape, not the behaviour.

## Order of work

| Step | Layer | What it adds |
| --- | --- | --- |
| 1. Settings | Application | `CopyFieldsSettings` reads and validates the configuration in one place |
| 2. Application service | Application | `RelatedRecordFieldCopier` holds the rule, and knows nothing of plug-ins |
| 3. Handler | Plug-in head | `CopyFieldsToRelatedRecordHandler` checks the step and calls the service |
| 4. Plug-in and registration | Plug-in head | `CopyFieldsToRelatedRecordPlugin`, and both classes in the composition root |

Run each test and confirm it fails for the right reason before writing its code.

## 1. Settings

The configuration is a `[DataContract]` class with a static `Parse`, which turns every missing or bad value into an `InvalidPluginExecutionException` the user can report. It lives in the Application layer, so any head can use it.

Test:

```csharp
namespace Abc.UnitTests.Application.FieldCopying
{
    using System;
    using System.Runtime.Serialization;
    using Abc.Application.FieldCopying;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;

    [TestClass]
    public sealed class CopyFieldsSettingsTests
    {
        [TestMethod]
        public void Parse_WithAValidConfiguration_ReadsTheLookupAndEveryMapping()
        {
            const string json = """
                {"lookup":"abc_caseid","mappings":[{"from":"abc_outcome","to":"abc_lastoutcome"},{"from":"abc_date","to":"abc_lastdate"}]}
                """;

            var settings = CopyFieldsSettings.Parse(json);

            settings.Lookup.Should().Be("abc_caseid");
            settings.Mappings.Should().HaveCount(2);
            settings.Mappings[1].From.Should().Be("abc_date");
            settings.Mappings[1].To.Should().Be("abc_lastdate");
        }

        [TestMethod]
        [DataRow(null)]
        [DataRow("")]
        [DataRow("not json")]
        [DataRow("null")]
        [DataRow("{}")]
        [DataRow("""{"lookup":"abc_caseid"}""")]
        [DataRow("""{"lookup":"abc_caseid","mappings":[]}""")]
        [DataRow("""{"lookup":"abc_caseid","mappings":[{"from":"abc_outcome"}]}""")]
        [DataRow("""{"mappings":[{"from":"a","to":"b"}]}""")]
        public void Parse_WithMissingOrInvalidConfiguration_Throws(string json)
        {
            Action act = () => CopyFieldsSettings.Parse(json);

            act.Should().Throw<InvalidPluginExecutionException>();
        }

        [TestMethod]
        public void Parse_WithMalformedJson_KeepsTheCauseAsTheInnerException()
        {
            Action act = () => CopyFieldsSettings.Parse("not json");

            act.Should().Throw<InvalidPluginExecutionException>().WithInnerException<SerializationException>();
        }
    }
}
```

Code:

```csharp
namespace Abc.Application.FieldCopying
{
    using System.Runtime.Serialization;

    /// <summary>One attribute to copy, read from the step configuration.</summary>
    [DataContract]
    public sealed class FieldMapping
    {
        /// <summary>Gets the logical name of the attribute on the changed record.</summary>
        [DataMember(Name = "from")]
        public string From { get; init; }

        /// <summary>Gets the logical name of the attribute on the related record.</summary>
        [DataMember(Name = "to")]
        public string To { get; init; }
    }
}
```

```csharp
namespace Abc.Application.FieldCopying
{
    using System.Collections.Generic;
    using System.IO;
    using System.Linq;
    using System.Runtime.Serialization;
    using System.Runtime.Serialization.Json;
    using System.Text;
    using Microsoft.Xrm.Sdk;

    /// <summary>
    /// The configuration of a field-copying step, for example
    /// <c>{"lookup":"abc_caseid","mappings":[{"from":"abc_outcome","to":"abc_lastoutcome"}]}</c>.
    /// </summary>
    [DataContract]
    public sealed class CopyFieldsSettings
    {
        /// <summary>Gets the logical name of the lookup to the related record.</summary>
        [DataMember(Name = "lookup")]
        public string Lookup { get; init; }

        /// <summary>Gets the attributes to copy.</summary>
        [DataMember(Name = "mappings")]
        public List<FieldMapping> Mappings { get; init; }

        /// <summary>Reads and validates a step configuration.</summary>
        /// <param name="json">The step's unsecure configuration.</param>
        /// <returns>The validated settings.</returns>
        /// <exception cref="InvalidPluginExecutionException">The configuration is missing or isn't valid.</exception>
        public static CopyFieldsSettings Parse(string json)
        {
            if (string.IsNullOrWhiteSpace(json))
            {
                throw new InvalidPluginExecutionException("The step has no configuration. Supply JSON with a lookup and mappings.");
            }

            CopyFieldsSettings settings;
            try
            {
                using (var stream = new MemoryStream(Encoding.UTF8.GetBytes(json)))
                {
                    settings = (CopyFieldsSettings)new DataContractJsonSerializer(typeof(CopyFieldsSettings)).ReadObject(stream);
                }
            }
            catch (SerializationException exception)
            {
                throw new InvalidPluginExecutionException("The step configuration is not valid JSON for this plug-in.", exception);
            }

            if (string.IsNullOrWhiteSpace(settings?.Lookup))
            {
                throw new InvalidPluginExecutionException("The step configuration must set 'lookup'.");
            }

            if (settings.Mappings == null
                || settings.Mappings.Count == 0
                || settings.Mappings.Any(mapping => string.IsNullOrWhiteSpace(mapping?.From) || string.IsNullOrWhiteSpace(mapping.To)))
            {
                throw new InvalidPluginExecutionException("The step configuration must set 'mappings', each with 'from' and 'to'.");
            }

            return settings;
        }
    }
}
```

## 2. Application service

The service takes the changes, the current record and the settings, and makes at most one write. When there is nothing to do, it logs why through `ILogWriter` and writes nothing. The second configuration, on another table, proves that the rule isn't tied to its first use.

Test. The full class also checks the other constructor and method arguments for null, that a change to no mapped attribute logs why and writes nothing, and that the inputs are left unchanged:

```csharp
namespace Abc.UnitTests.Application.FieldCopying
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using Abc.Application.FieldCopying;
    using Abc.Infrastructure.Logging;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Moq;

    [TestClass]
    public sealed class RelatedRecordFieldCopierTests
    {
        private const string Inspection = "abc_inspection";
        private const string CaseLookup = "abc_caseid";
        private const string Outcome = "abc_outcome";
        private const string LastOutcome = "abc_lastoutcome";

        private readonly Mock<IOrganizationService> service = new Mock<IOrganizationService>(MockBehavior.Strict);
        private readonly Mock<ILogWriter> log = new Mock<ILogWriter>();
        private readonly EntityReference relatedCase = new EntityReference("abc_case", Guid.NewGuid());
        private readonly RelatedRecordFieldCopier copier;

        public RelatedRecordFieldCopierTests()
        {
            this.copier = new RelatedRecordFieldCopier(this.service.Object, this.log.Object);
        }

        [TestMethod]
        public void Constructor_WithNoService_Throws()
        {
            Action act = () => new RelatedRecordFieldCopier(null, this.log.Object);

            act.Should().Throw<ArgumentNullException>().WithParameterName("service");
        }

        [TestMethod]
        public void CopyToRelatedRecord_WithAMappedChange_UpdatesOnlyThatAttributeOfTheRelatedRecord()
        {
            var updates = this.CaptureUpdates();
            var changes = new Entity(Inspection) { [CaseLookup] = this.relatedCase, [Outcome] = "Passed", ["abc_notes"] = "Not mapped" };

            this.copier.CopyToRelatedRecord(changes, null, Settings(CaseLookup, (Outcome, LastOutcome)));

            var update = updates.Should().ContainSingle().Which;
            update.LogicalName.Should().Be(this.relatedCase.LogicalName);
            update.Id.Should().Be(this.relatedCase.Id);
            update.Attributes.Keys.Should().BeEquivalentTo(LastOutcome);
            update[LastOutcome].Should().Be("Passed");
        }

        [TestMethod]
        public void CopyToRelatedRecord_WithAnotherConfiguration_CopiesOtherAttributesToAnotherTable()
        {
            var updates = this.CaptureUpdates();
            var applicant = new EntityReference("abc_applicant", Guid.NewGuid());
            var changes = new Entity(Inspection) { ["abc_applicantid"] = applicant, ["abc_notes"] = "Follow up", [Outcome] = "Failed" };

            this.copier.CopyToRelatedRecord(changes, null, Settings("abc_applicantid", ("abc_notes", "abc_lastnotes"), (Outcome, LastOutcome)));

            var update = updates.Should().ContainSingle().Which;
            update.LogicalName.Should().Be(applicant.LogicalName);
            update.Id.Should().Be(applicant.Id);
            update["abc_lastnotes"].Should().Be("Follow up");
            update[LastOutcome].Should().Be("Failed");
        }

        [TestMethod]
        public void CopyToRelatedRecord_WhenOnlyTheCurrentRecordHoldsTheLookup_UpdatesTheRecordItPointsTo()
        {
            var updates = this.CaptureUpdates();
            var changes = new Entity(Inspection) { [Outcome] = "Passed" };
            var current = new Entity(Inspection) { [CaseLookup] = this.relatedCase, [Outcome] = "Passed" };

            this.copier.CopyToRelatedRecord(changes, current, Settings(CaseLookup, (Outcome, LastOutcome)));

            updates.Should().ContainSingle().Which.Id.Should().Be(this.relatedCase.Id);
        }

        [TestMethod]
        public void CopyToRelatedRecord_WithNoLookupValue_LogsWhyAndWritesNothing()
        {
            this.copier.CopyToRelatedRecord(new Entity(Inspection) { [Outcome] = "Passed" }, null, Settings(CaseLookup, (Outcome, LastOutcome)));

            this.log.Verify(
                value => value.Log(Severity.Info, nameof(RelatedRecordFieldCopier), It.Is<string>(message => message.Contains(CaseLookup))),
                Times.Once());
            this.service.VerifyNoOtherCalls();
        }

        private static CopyFieldsSettings Settings(string lookup, params (string From, string To)[] mappings)
        {
            return new CopyFieldsSettings
            {
                Lookup = lookup,
                Mappings = mappings.Select(mapping => new FieldMapping { From = mapping.From, To = mapping.To }).ToList(),
            };
        }

        private List<Entity> CaptureUpdates()
        {
            var updates = new List<Entity>();
            this.service.Setup(value => value.Update(It.IsAny<Entity>())).Callback<Entity>(updates.Add);
            return updates;
        }
    }
}
```

Code:

```csharp
namespace Abc.Application.FieldCopying
{
    using Microsoft.Xrm.Sdk;

    /// <summary>Copies configured attributes from a changed record to the record one of its lookups points to.</summary>
    public interface IRelatedRecordFieldCopier
    {
        /// <summary>
        /// Copies the mapped attributes in <paramref name="changes"/> to the related record, in one update. Issues no
        /// write if the lookup is empty or none of the mapped attributes changed. Never changes its inputs.
        /// </summary>
        /// <param name="changes">The attributes that changed, such as the Target of a Create or Update.</param>
        /// <param name="current">The record after the change, which supplies an unchanged lookup, or <see langword="null"/>.</param>
        /// <param name="settings">The validated step configuration.</param>
        void CopyToRelatedRecord(Entity changes, Entity current, CopyFieldsSettings settings);
    }
}
```

```csharp
namespace Abc.Application.FieldCopying
{
    using System;
    using Abc.Infrastructure.Logging;
    using Microsoft.Xrm.Sdk;

    /// <summary>Copies configured attributes from a changed record to a related record.</summary>
    public sealed class RelatedRecordFieldCopier : IRelatedRecordFieldCopier
    {
        private readonly IOrganizationService service;
        private readonly ILogWriter log;

        /// <summary>Initializes a new instance of the <see cref="RelatedRecordFieldCopier"/> class.</summary>
        /// <param name="service">The service that updates the related record.</param>
        /// <param name="log">The log that records why nothing was copied.</param>
        public RelatedRecordFieldCopier(IOrganizationService service, ILogWriter log)
        {
            this.service = service ?? throw new ArgumentNullException(nameof(service));
            this.log = log ?? throw new ArgumentNullException(nameof(log));
        }

        /// <inheritdoc/>
        public void CopyToRelatedRecord(Entity changes, Entity current, CopyFieldsSettings settings)
        {
            if (changes == null)
            {
                throw new ArgumentNullException(nameof(changes));
            }

            if (settings == null)
            {
                throw new ArgumentNullException(nameof(settings));
            }

            // An Update's Target holds only the changed attributes, so an unchanged lookup comes from the current record.
            var related = changes.GetAttributeValue<EntityReference>(settings.Lookup)
                ?? current?.GetAttributeValue<EntityReference>(settings.Lookup);
            if (related == null)
            {
                this.log.Log(Severity.Info, nameof(RelatedRecordFieldCopier), $"The {changes.LogicalName} has no value for {settings.Lookup}, so there's nothing to copy.");
                return;
            }

            var update = new Entity(related.LogicalName, related.Id);
            foreach (var mapping in settings.Mappings)
            {
                if (changes.Contains(mapping.From))
                {
                    update[mapping.To] = changes[mapping.From];
                }
            }

            if (update.Attributes.Count == 0)
            {
                this.log.Log(Severity.Info, nameof(RelatedRecordFieldCopier), $"The {changes.LogicalName} change set none of the mapped attributes, so there's nothing to copy.");
                return;
            }

            this.service.Update(update);
        }
    }
}
```

## 3. Handler

The handler adapts the step to the service. It checks the registration contract first, because a mismatch is a configuration error: the wrong message or stage, no `Target`, or no post-image on an `Update`. It doesn't check the table or the mode, because the capability works on any table, synchronously or asynchronously. Then it parses the step configuration and calls the service. The image name is a constant, which the tests and the hand-off use. The handler catches nothing: the base class reports failures (see [infrastructure.md](infrastructure.md#failures)).

Test. The full class also checks the other constructor arguments for null, a `Create` with no post-image, a `Target` that isn't an entity, and another message:

```csharp
namespace Abc.UnitTests.Plugins.FieldCopying
{
    using System;
    using Abc.Application.FieldCopying;
    using Abc.Infrastructure.Plugins;
    using Abc.Plugins.FieldCopying;
    using Abc.UnitTests.Support;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Moq;

    [TestClass]
    public sealed class CopyFieldsToRelatedRecordHandlerTests
    {
        private const string Inspection = "abc_inspection";
        private const string CaseLookup = "abc_caseid";
        private const string Configuration = """{"lookup":"abc_caseid","mappings":[{"from":"abc_outcome","to":"abc_lastoutcome"}]}""";
        private const string ContractMessage = "This plug-in requires a post-operation Create or Update with a Target.";

        private readonly PluginRuntime runtime = new PluginRuntime();
        private readonly Mock<IRelatedRecordFieldCopier> copier = new Mock<IRelatedRecordFieldCopier>(MockBehavior.Strict);
        private readonly Entity target;
        private readonly Entity image;

        public CopyFieldsToRelatedRecordHandlerTests()
        {
            this.target = new Entity(Inspection, Guid.NewGuid()) { ["abc_outcome"] = "Passed" };
            this.image = new Entity(Inspection, this.target.Id)
            {
                [CaseLookup] = new EntityReference("abc_case", Guid.NewGuid()),
                ["abc_outcome"] = "Passed",
            };
        }

        [TestMethod]
        public void Constructor_WithNoCopier_Throws()
        {
            Action act = () => new CopyFieldsToRelatedRecordHandler(null, this.runtime.CreateExecution(), new PluginStepConfiguration(Configuration, null));

            act.Should().Throw<ArgumentNullException>().WithParameterName("copier");
        }

        [TestMethod]
        [DataRow(PluginMessages.Create)]
        [DataRow(PluginMessages.Update)]
        public void Execute_AfterACreateOrUpdate_CopiesTheTargetWithThePostImageAndTheStepsSettings(string messageName)
        {
            this.GivenAPostOperationStep(messageName).WithPostImage(CopyFieldsToRelatedRecordHandler.PostImageName, this.image);
            this.copier.Setup(value => value.CopyToRelatedRecord(this.target, this.image, It.Is<CopyFieldsSettings>(settings => settings.Lookup == CaseLookup)));

            this.CreateHandler(Configuration).Execute();

            this.copier.VerifyAll();
        }

        [TestMethod]
        [DataRow("create")]
        [DataRow("UPDATE")]
        public void Execute_WithAMessageNameInAnotherCase_StillCopies(string messageName)
        {
            this.GivenAPostOperationStep(messageName).WithPostImage(CopyFieldsToRelatedRecordHandler.PostImageName, this.image);
            this.copier.Setup(value => value.CopyToRelatedRecord(this.target, this.image, It.IsAny<CopyFieldsSettings>()));

            this.CreateHandler(Configuration).Execute();

            this.copier.VerifyAll();
        }

        [TestMethod]
        public void Execute_WhenTheCopierFails_LetsTheFailurePropagate()
        {
            this.GivenAPostOperationStep(PluginMessages.Create);
            this.copier
                .Setup(value => value.CopyToRelatedRecord(this.target, null, It.IsAny<CopyFieldsSettings>()))
                .Throws(new SimulatedFailureException("The copy failed."));

            Action act = this.CreateHandler(Configuration).Execute;

            act.Should().Throw<SimulatedFailureException>();
        }

        [TestMethod]
        public void Execute_WithNoTarget_ThrowsWithoutCopying()
        {
            this.GivenAPostOperationStep(PluginMessages.Create).WithoutTarget();

            this.AssertContractFailure(ContractMessage);
        }

        [TestMethod]
        [DataRow(PluginStages.PreValidation)]
        [DataRow(PluginStages.PreOperation)]
        public void Execute_BeforeTheOperation_ThrowsWithoutCopying(int stage)
        {
            this.runtime.ForStep(PluginMessages.Create, Inspection, stage, PluginModes.Synchronous).WithTarget(this.target);

            this.AssertContractFailure(ContractMessage);
        }

        [TestMethod]
        public void Execute_AfterAnUpdateWithNoPostImage_ThrowsWithoutCopying()
        {
            this.GivenAPostOperationStep(PluginMessages.Update);

            this.AssertContractFailure("This plug-in requires a post-image named PostImage on Update.");
        }

        [TestMethod]
        public void Execute_WithNoStepConfiguration_ThrowsAnErrorTheUserCanReport()
        {
            this.GivenAPostOperationStep(PluginMessages.Create);

            Action act = this.CreateHandler(null).Execute;

            act.Should().Throw<InvalidPluginExecutionException>().WithMessage("*no configuration*");
            this.copier.VerifyNoOtherCalls();
        }

        private PluginRuntime GivenAPostOperationStep(string messageName)
        {
            return this.runtime
                .ForStep(messageName, Inspection, PluginStages.PostOperation, PluginModes.Synchronous)
                .WithTarget(this.target);
        }

        private CopyFieldsToRelatedRecordHandler CreateHandler(string unsecureConfiguration)
        {
            return new CopyFieldsToRelatedRecordHandler(
                this.copier.Object,
                this.runtime.CreateExecution(),
                new PluginStepConfiguration(unsecureConfiguration, null));
        }

        private void AssertContractFailure(string message)
        {
            Action act = this.CreateHandler(Configuration).Execute;

            act.Should().Throw<InvalidOperationException>().WithMessage(message);
            this.copier.VerifyNoOtherCalls();
        }
    }
}
```

Code:

```csharp
namespace Abc.Plugins.FieldCopying
{
    using System;
    using Abc.Application.FieldCopying;
    using Abc.Infrastructure.Plugins;
    using Microsoft.Xrm.Sdk;

    /// <summary>
    /// Adapts a post-operation Create or Update of any table, synchronous or asynchronous, to
    /// <see cref="IRelatedRecordFieldCopier"/>. An Update step needs a post-image holding the lookup. A failure fails
    /// the operation if the step is synchronous.
    /// </summary>
    public sealed class CopyFieldsToRelatedRecordHandler : IPluginHandler
    {
        /// <summary>The name the step's post-image must have.</summary>
        public const string PostImageName = "PostImage";

        private readonly IRelatedRecordFieldCopier copier;
        private readonly IPluginExecution execution;
        private readonly PluginStepConfiguration configuration;

        /// <summary>Initializes a new instance of the <see cref="CopyFieldsToRelatedRecordHandler"/> class.</summary>
        /// <param name="copier">The service that copies the attributes.</param>
        /// <param name="execution">The current invocation.</param>
        /// <param name="configuration">The step's configuration, which says what to copy.</param>
        public CopyFieldsToRelatedRecordHandler(
            IRelatedRecordFieldCopier copier,
            IPluginExecution execution,
            PluginStepConfiguration configuration)
        {
            this.copier = copier ?? throw new ArgumentNullException(nameof(copier));
            this.execution = execution ?? throw new ArgumentNullException(nameof(execution));
            this.configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
        }

        /// <inheritdoc/>
        public void Execute()
        {
            var context = this.execution.Context;

            // A mismatch with the registered step is a configuration error, so it fails loudly.
            var isUpdate = IsMessage(context, PluginMessages.Update);
            if (context.Stage != PluginStages.PostOperation
                || !(isUpdate || IsMessage(context, PluginMessages.Create))
                || !context.InputParameters.TryGetValue(PluginInputParameters.Target, out var value)
                || !(value is Entity target))
            {
                throw new InvalidOperationException("This plug-in requires a post-operation Create or Update with a Target.");
            }

            // An Update's Target holds only what changed, so the image supplies an unchanged lookup.
            context.PostEntityImages.TryGetValue(PostImageName, out var current);
            if (isUpdate && current == null)
            {
                throw new InvalidOperationException("This plug-in requires a post-image named " + PostImageName + " on Update.");
            }

            var settings = CopyFieldsSettings.Parse(this.configuration.Unsecure);
            this.copier.CopyToRelatedRecord(target, current, settings);
        }

        private static bool IsMessage(IPluginExecutionContext context, string messageName)
        {
            return string.Equals(context.MessageName, messageName, StringComparison.OrdinalIgnoreCase);
        }
    }
}
```

## 4. Plug-in and registration

Register the service and the handler in the plug-in head's composition root, which is shown in full in [infrastructure.md](infrastructure.md#composition-roots):

```csharp
root.Register<IRelatedRecordFieldCopier, RelatedRecordFieldCopier>();
root.Register<CopyFieldsToRelatedRecordHandler>();
```

Test that the root resolves the handler, and add a line to `Root_WithTheInvocationsServices_ResolvesEveryHandler` for each new handler. The last test covers the data access registrations from [data-access.md](data-access.md):

```csharp
namespace Abc.UnitTests.Plugins
{
    using Abc.Dataverse.Contexts;
    using Abc.Dataverse.Queries;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Execution;
    using Abc.Infrastructure.Plugins;
    using Abc.Plugins;
    using Abc.Plugins.FieldCopying;
    using Abc.UnitTests.Support;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;

    [TestClass]
    public sealed class PluginCompositionRootTests
    {
        private readonly PluginRuntime runtime = new PluginRuntime();

        [TestMethod]
        public void Root_Always_ReturnsTheSameContainer()
        {
            PluginCompositionRoot.Root.Should().BeSameAs(PluginCompositionRoot.Root);
        }

        [TestMethod]
        public void Root_WithTheInvocationsServices_ResolvesEveryHandler()
        {
            using (var scope = this.CreateScope())
            {
                scope.Resolve<CopyFieldsToRelatedRecordHandler>().Should().NotBeNull();
            }
        }

        [TestMethod]
        public void Root_WithTheInvocationsServices_ResolvesTheDataAccessServices()
        {
            using (var scope = this.CreateScope())
            {
                scope.Resolve<IAbcContextFactory>().Should().BeOfType<AbcContextFactory>();
                scope.Resolve<CaseQueries>().Should().NotBeNull();
            }
        }

        // Registers what PluginBase registers for each invocation.
        private PluginContainer CreateScope()
        {
            var scope = PluginCompositionRoot.Root.CreateExecutionScope();
            scope.Register<IPluginExecutionContext>(this.runtime.Context.Object);
            scope.Register<IOrganizationService>(this.runtime.Service.Object);
            scope.Register<ITracingService>(this.runtime.Tracing);
            scope.Register<IOrganizationServiceFactory>(this.runtime.Factory.Object);
            scope.Register<IPluginExecution>(this.runtime.CreateExecution());
            scope.Register<IExecutionServiceProvider>(new PluginExecutionServiceProvider(this.runtime.Factory.Object, this.runtime.Context.Object));
            scope.Register<PluginStepConfiguration>(new PluginStepConfiguration(null, null));
            return scope;
        }
    }
}
```

Then test the plug-in end to end through `PluginTestBase<TPlugin>`. Only the host is simulated: the real root builds the real handler and service.

```csharp
namespace Abc.UnitTests.Plugins.FieldCopying
{
    using System;
    using System.Collections.Generic;
    using Abc.Infrastructure.Plugins;
    using Abc.Plugins.FieldCopying;
    using Abc.UnitTests.Support;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Moq;

    [TestClass]
    public sealed class CopyFieldsToRelatedRecordPluginTests : PluginTestBase<CopyFieldsToRelatedRecordPlugin>
    {
        private const string Inspection = "abc_inspection";

        private readonly EntityReference relatedCase = new EntityReference("abc_case", Guid.NewGuid());
        private readonly Guid inspectionId = Guid.NewGuid();
        private string unsecureConfiguration = """{"lookup":"abc_caseid","mappings":[{"from":"abc_outcome","to":"abc_lastoutcome"}]}""";

        [TestMethod]
        public void Plugin_Always_RunsItsHandlerThroughTheSharedBaseClass()
        {
            this.Plugin.Should().BeAssignableTo<PluginBase<CopyFieldsToRelatedRecordHandler>>();
        }

        [TestMethod]
        public void Execute_AfterAnInspectionUpdate_CopiesTheOutcomeToItsCase()
        {
            this.GivenAnInspectionUpdate(new Entity(Inspection, this.inspectionId) { ["abc_outcome"] = "Passed" });
            var updates = new List<Entity>();
            this.Runtime.Service.Setup(value => value.Update(It.IsAny<Entity>())).Callback<Entity>(updates.Add);

            this.Execute();

            var update = updates.Should().ContainSingle().Which;
            update.ToEntityReference().Should().BeEquivalentTo(this.relatedCase);
            update.Attributes.Keys.Should().BeEquivalentTo("abc_lastoutcome");
            update["abc_lastoutcome"].Should().Be("Passed");
        }

        [TestMethod]
        public void Execute_WithNoStepConfiguration_FailsWithoutCallingTheService()
        {
            this.unsecureConfiguration = null;
            this.GivenAnInspectionUpdate(new Entity(Inspection, this.inspectionId) { ["abc_outcome"] = "Passed" });

            this.AssertExecuteFailsWithoutCallingService().WithMessage("*no configuration*");
        }

        [TestMethod]
        public void Execute_WhenRegisteredBeforeTheOperation_FailsWithoutCallingTheService()
        {
            this.Runtime.ForPreOperationCreate(new Entity(Inspection));

            this.AssertExecuteFailsWithoutCallingService().WithInnerException<InvalidOperationException>();
        }

        [TestMethod]
        public void Execute_WhenTheUpdateFails_KeepsTheCauseAsTheInnerException()
        {
            this.GivenAnInspectionUpdate(new Entity(Inspection, this.inspectionId) { ["abc_outcome"] = "Passed" });
            var failure = new SimulatedFailureException("The update failed.");
            this.Runtime.Service.Setup(value => value.Update(It.IsAny<Entity>())).Throws(failure);

            Action act = this.Execute;

            act.Should().Throw<InvalidPluginExecutionException>().Which.InnerException.Should().BeSameAs(failure);
        }

        [TestMethod]
        public void Execute_WhenNoMappedAttributeChanged_TracesWhyAndWritesNothing()
        {
            this.GivenAnInspectionUpdate(new Entity(Inspection, this.inspectionId) { ["abc_notes"] = "Not mapped" });

            this.Execute();

            this.Runtime.Tracing.Messages.Should().Contain(message => message.Contains("nothing to copy"));
            this.Runtime.Service.VerifyNoOtherCalls();
        }

        protected override CopyFieldsToRelatedRecordPlugin CreatePlugin()
        {
            return new CopyFieldsToRelatedRecordPlugin(this.unsecureConfiguration, null);
        }

        private void GivenAnInspectionUpdate(Entity target)
        {
            this.Runtime
                .ForStep(PluginMessages.Update, Inspection, PluginStages.PostOperation, PluginModes.Synchronous)
                .WithTarget(target)
                .WithPostImage(
                    CopyFieldsToRelatedRecordHandler.PostImageName,
                    new Entity(Inspection, this.inspectionId) { ["abc_caseid"] = this.relatedCase, ["abc_outcome"] = "Passed" });
        }
    }
}
```

The plug-in is the class registered in Dataverse. It has no logic: it passes the root and the step's configuration to `PluginBase<THandler>`.

```csharp
namespace Abc.Plugins.FieldCopying
{
    using Abc.Infrastructure.Plugins;

    /// <summary>
    /// Copies configured attributes from a created or updated record to the record one of its lookups points to.
    /// Register it on the post-operation Create or Update of any table, with unsecure configuration such as
    /// <c>{"lookup":"abc_caseid","mappings":[{"from":"abc_outcome","to":"abc_lastoutcome"}]}</c>. An Update step
    /// also needs a post-image named <c>PostImage</c> that holds the lookup.
    /// </summary>
    public sealed class CopyFieldsToRelatedRecordPlugin : PluginBase<CopyFieldsToRelatedRecordHandler>
    {
        /// <summary>Initializes a new instance of the <see cref="CopyFieldsToRelatedRecordPlugin"/> class.</summary>
        /// <param name="unsecureConfiguration">The step's unsecure configuration, which says what to copy.</param>
        /// <param name="secureConfiguration">The step's secure configuration, which this plug-in doesn't use.</param>
        public CopyFieldsToRelatedRecordPlugin(string unsecureConfiguration, string secureConfiguration)
            : base(PluginCompositionRoot.Root, unsecureConfiguration, secureConfiguration)
        {
        }
    }
}
```

## Hand-off for this example

Register one step against the plug-in assembly in the development environment:

| Item | Value |
| --- | --- |
| Plug-in type | `Abc.Plugins.FieldCopying.CopyFieldsToRelatedRecordPlugin` |
| Message and table | `Update` on `abc_inspection` |
| Stage and mode | Post-operation, synchronous |
| Filtering attributes | `abc_outcome` |
| Image | A post-image named `PostImage`, with `abc_caseid` |
| Unsecure configuration | `{"lookup":"abc_caseid","mappings":[{"from":"abc_outcome","to":"abc_lastoutcome"}]}` |

To copy the outcome when an inspection is created as well, register a `Create` step with the same configuration. It needs no image. A second use is another step with its own configuration. The plug-in doesn't change.
