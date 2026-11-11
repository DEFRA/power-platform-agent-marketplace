# Worked example: a configurable custom workflow activity

The capability is **trim white space from named text attributes of a process's primary record**. It is named for that capability, and what varies (the attributes) is an input, so makers reuse it in processes on any table. It is one small job, not a business process.

The code is taken unchanged from the same solution as the [plug-in example](plugin-example.md), and the tests pass. Some tests are left out for length, and each section says which. Adapt the shape, not the behaviour.

## Order of work

| Step                                  | Layer         | What it adds                                                                       |
| ------------------------------------- | ------------- | ---------------------------------------------------------------------------------- |
| 1. Application service                | Application   | `TextFieldTrimmer` holds the rule, and knows nothing of workflows                  |
| 2. Activity, handler and registration | Workflow head | `TrimTextFields`, `TrimTextFieldsHandler`, and the handler in the composition root |

Run each test and confirm it fails for the right reason before writing its code.

## 1. Application service

`Trim` reads only the named columns, and updates only the values that trimming changed, in one write. When nothing changes, it logs why through `ILogWriter` and doesn't update. `GetTrimmedValues` is the part with no reads or writes, so a pre-operation plug-in could apply it to its `Target`. Both use `Clone` and `GetChanges` from [`EntityExtensions`](infrastructure.md#entity-helpers).

Test. The full class also checks the other constructor and method arguments for null:

```csharp
namespace Abc.UnitTests.Application.TextTrimming
{
    using System;
    using System.Collections.Generic;
    using Abc.Application.TextTrimming;
    using Abc.Infrastructure.Logging;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Query;
    using Moq;

    [TestClass]
    public sealed class TextFieldTrimmerTests
    {
        private const string CaseTable = "abc_case";
        private const string Name = "abc_name";
        private const string Description = "abc_description";

        private static readonly string[] Names = { Name, Description };

        private readonly Mock<IOrganizationService> service = new Mock<IOrganizationService>(MockBehavior.Strict);
        private readonly Mock<ILogWriter> log = new Mock<ILogWriter>();
        private readonly EntityReference record = new EntityReference(CaseTable, Guid.NewGuid());
        private readonly TextFieldTrimmer trimmer;

        public TextFieldTrimmerTests()
        {
            this.trimmer = new TextFieldTrimmer(this.service.Object, this.log.Object);
        }

        [TestMethod]
        public void Constructor_WithNoService_Throws()
        {
            Action act = () => new TextFieldTrimmer(null, this.log.Object);

            act.Should().Throw<ArgumentNullException>().WithParameterName("service");
        }

        [TestMethod]
        public void GetTrimmedValues_WithPaddedText_ReturnsOnlyTheValuesThatChanged()
        {
            var current = new Entity(CaseTable, this.record.Id) { [Name] = "  Case 1 ", [Description] = "Tidy", ["abc_notes"] = " Not named " };

            var changes = this.trimmer.GetTrimmedValues(current, Names);

            changes.LogicalName.Should().Be(CaseTable);
            changes.Id.Should().Be(this.record.Id);
            changes.Attributes.Keys.Should().BeEquivalentTo(Name);
            changes[Name].Should().Be("Case 1");
        }

        [TestMethod]
        public void GetTrimmedValues_WithAValueThatIsNotText_LeavesItAlone()
        {
            var current = new Entity(CaseTable, this.record.Id) { [Name] = new OptionSetValue(1) };

            var changes = this.trimmer.GetTrimmedValues(current, Names);

            changes.Attributes.Should().BeEmpty();
        }

        [TestMethod]
        public void GetTrimmedValues_Always_LeavesTheRecordUnchanged()
        {
            var current = new Entity(CaseTable, this.record.Id) { [Name] = "  Case 1 " };

            this.trimmer.GetTrimmedValues(current, Names);

            current[Name].Should().Be("  Case 1 ");
        }

        [TestMethod]
        public void Trim_WithPaddedText_ReadsOnlyTheNamedColumnsAndUpdatesOnlyTheValuesThatChanged()
        {
            var columns = this.ReturnsRecord(new Entity(CaseTable, this.record.Id) { [Name] = "  Case 1 ", [Description] = "Tidy" });
            var updates = new List<Entity>();
            this.service.Setup(value => value.Update(It.IsAny<Entity>())).Callback<Entity>(updates.Add);

            var changed = this.trimmer.Trim(this.record, Names);

            changed.Should().Be(1);
            columns.Should().ContainSingle().Which.Columns.Should().BeEquivalentTo(Names);
            var update = updates.Should().ContainSingle().Which;
            update.Id.Should().Be(this.record.Id);
            update.Attributes.Keys.Should().BeEquivalentTo(Name);
            update[Name].Should().Be("Case 1");
        }

        [TestMethod]
        public void Trim_WhenNothingNeedsTrimming_LogsWhyAndSendsNoUpdate()
        {
            this.ReturnsRecord(new Entity(CaseTable, this.record.Id) { [Name] = "Case 1" });

            var changed = this.trimmer.Trim(this.record, Names);

            changed.Should().Be(0);
            this.log.Verify(value => value.Log(Severity.Info, nameof(TextFieldTrimmer), It.IsAny<string>()), Times.Once());
            this.service.Verify(value => value.Retrieve(CaseTable, this.record.Id, It.IsAny<ColumnSet>()), Times.Once());
            this.service.VerifyNoOtherCalls();
        }

        private List<ColumnSet> ReturnsRecord(Entity current)
        {
            var columns = new List<ColumnSet>();
            this.service
                .Setup(value => value.Retrieve(CaseTable, this.record.Id, It.IsAny<ColumnSet>()))
                .Callback<string, Guid, ColumnSet>((name, id, columnSet) => columns.Add(columnSet))
                .Returns(current);
            return columns;
        }
    }
}
```

Code:

```csharp
namespace Abc.Application.TextTrimming
{
    using System.Collections.Generic;
    using Microsoft.Xrm.Sdk;

    /// <summary>Removes leading and trailing white space from a record's text attributes.</summary>
    public interface ITextFieldTrimmer
    {
        /// <summary>
        /// Gets the trimmed values of a record's named text attributes. Issues no read or write, and never changes
        /// <paramref name="record"/>.
        /// </summary>
        /// <param name="record">The record, holding at least the named attributes.</param>
        /// <param name="attributeNames">The logical names of the attributes to trim. Values that aren't text are ignored.</param>
        /// <returns>A new entity for the same record, holding only the attributes whose value trimming changed.</returns>
        Entity GetTrimmedValues(Entity record, IReadOnlyCollection<string> attributeNames);

        /// <summary>
        /// Reads a record's named attributes, trims them and updates only those that changed, in one update. Issues no
        /// update if nothing changed.
        /// </summary>
        /// <param name="record">The record to trim.</param>
        /// <param name="attributeNames">The logical names of the attributes to trim. Values that aren't text are ignored.</param>
        /// <returns>The number of attributes updated.</returns>
        int Trim(EntityReference record, IReadOnlyCollection<string> attributeNames);
    }
}
```

```csharp
namespace Abc.Application.TextTrimming
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using Abc.Dataverse;
    using Abc.Infrastructure.Logging;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Query;

    /// <summary>Removes leading and trailing white space from a record's text attributes.</summary>
    public sealed class TextFieldTrimmer : ITextFieldTrimmer
    {
        private readonly IOrganizationService service;
        private readonly ILogWriter log;

        /// <summary>Initializes a new instance of the <see cref="TextFieldTrimmer"/> class.</summary>
        /// <param name="service">The service that reads and updates the record.</param>
        /// <param name="log">The log that records why nothing was updated.</param>
        public TextFieldTrimmer(IOrganizationService service, ILogWriter log)
        {
            this.service = service ?? throw new ArgumentNullException(nameof(service));
            this.log = log ?? throw new ArgumentNullException(nameof(log));
        }

        /// <inheritdoc/>
        public Entity GetTrimmedValues(Entity record, IReadOnlyCollection<string> attributeNames)
        {
            if (record == null)
            {
                throw new ArgumentNullException(nameof(record));
            }

            if (attributeNames == null)
            {
                throw new ArgumentNullException(nameof(attributeNames));
            }

            var trimmed = record.Clone();
            foreach (var name in attributeNames)
            {
                if (record.Attributes.TryGetValue(name, out var value) && value is string text)
                {
                    trimmed[name] = text.Trim();
                }
            }

            return trimmed.GetChanges(record);
        }

        /// <inheritdoc/>
        public int Trim(EntityReference record, IReadOnlyCollection<string> attributeNames)
        {
            if (record == null)
            {
                throw new ArgumentNullException(nameof(record));
            }

            if (attributeNames == null)
            {
                throw new ArgumentNullException(nameof(attributeNames));
            }

            var current = this.service.Retrieve(record.LogicalName, record.Id, new ColumnSet(attributeNames.ToArray()));
            var changes = this.GetTrimmedValues(current, attributeNames);
            if (changes.Attributes.Count == 0)
            {
                this.log.Log(Severity.Info, nameof(TextFieldTrimmer), $"The {record.LogicalName} needed no trimming, so it wasn't updated.");
                return 0;
            }

            this.service.Update(changes);
            return changes.Attributes.Count;
        }
    }
}
```

## 2. Activity, handler and registration

Only the workflow runtime can create a `CodeActivityContext`, so the handler is tested through its activity. `WorkflowActivityTestBase<TActivity>` runs the activity in `WorkflowInvoker`. Only the host is simulated: the real root builds the real handler and service. The argument attributes are tested because they are the contract that makers see. A missing required input fails in the runtime before the handler runs, so that test expects an `ArgumentException`:

```csharp
namespace Abc.UnitTests.Workflows.TextTrimming
{
    using System;
    using System.Activities;
    using System.Collections.Generic;
    using System.Reflection;
    using Abc.Infrastructure.Workflows;
    using Abc.UnitTests.Support;
    using Abc.Workflows.TextTrimming;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Query;
    using Microsoft.Xrm.Sdk.Workflow;
    using Moq;

    [TestClass]
    public sealed class TrimTextFieldsTests : WorkflowActivityTestBase<TrimTextFields>
    {
        private const string CaseTable = "abc_case";
        private const string Name = "abc_name";
        private const string Description = "abc_description";

        private readonly Guid recordId = Guid.NewGuid();
        private readonly List<Entity> updates = new List<Entity>();

        public TrimTextFieldsTests()
        {
            this.Runtime.Context.SetupGet(context => context.PrimaryEntityName).Returns(CaseTable);
            this.Runtime.Context.SetupGet(context => context.PrimaryEntityId).Returns(this.recordId);
            this.Runtime.Service.Setup(value => value.Update(It.IsAny<Entity>())).Callback<Entity>(this.updates.Add);
        }

        [TestMethod]
        public void Activity_Always_RunsItsHandlerThroughTheSharedBaseClass()
        {
            this.Activity.Should().BeAssignableTo<WorkflowActivityBase<TrimTextFieldsHandler>>();
        }

        [TestMethod]
        public void AttributeNames_Always_IsARequiredInputWithADisplayName()
        {
            var property = typeof(TrimTextFields).GetProperty(nameof(TrimTextFields.AttributeNames));

            property.GetCustomAttribute<RequiredArgumentAttribute>().Should().NotBeNull();
            property.GetCustomAttribute<InputAttribute>().Name.Should().Be("Attribute logical names (comma-separated)");
        }

        [TestMethod]
        public void AttributesChanged_Always_IsAnOutputWithADisplayName()
        {
            var property = typeof(TrimTextFields).GetProperty(nameof(TrimTextFields.AttributesChanged));

            property.GetCustomAttribute<OutputAttribute>().Name.Should().Be("Attributes changed");
        }

        [TestMethod]
        public void Invoke_WithPaddedText_TrimsThePrimaryRecordAndOutputsHowManyChanged()
        {
            var columns = this.ReturnsRecord(new Entity(CaseTable, this.recordId) { [Name] = " Case 1 ", [Description] = "Tidy" });

            var outputs = this.Invoke(nameof(TrimTextFields.AttributeNames), Name + ", " + Description);

            outputs[nameof(TrimTextFields.AttributesChanged)].Should().Be(1);
            columns.Should().ContainSingle().Which.Columns.Should().BeEquivalentTo(Name, Description);
            var update = this.updates.Should().ContainSingle().Which;
            update.ToEntityReference().Should().BeEquivalentTo(new EntityReference(CaseTable, this.recordId));
            update.Attributes.Keys.Should().BeEquivalentTo(Name);
            update[Name].Should().Be("Case 1");
        }

        [TestMethod]
        public void Invoke_ForAProcessOnAnotherTable_TrimsThatTablesRecord()
        {
            const string ApplicantTable = "abc_applicant";
            this.Runtime.Context.SetupGet(context => context.PrimaryEntityName).Returns(ApplicantTable);
            this.Runtime.Service
                .Setup(value => value.Retrieve(ApplicantTable, this.recordId, It.IsAny<ColumnSet>()))
                .Returns(new Entity(ApplicantTable, this.recordId) { [Name] = "Applicant 1 " });

            var outputs = this.Invoke(nameof(TrimTextFields.AttributeNames), Name);

            outputs[nameof(TrimTextFields.AttributesChanged)].Should().Be(1);
            this.updates.Should().ContainSingle().Which.LogicalName.Should().Be(ApplicantTable);
        }

        [TestMethod]
        public void Invoke_WithARepeatedName_ReadsItOnce()
        {
            var columns = this.ReturnsRecord(new Entity(CaseTable, this.recordId) { [Name] = "Case 1" });

            var outputs = this.Invoke(nameof(TrimTextFields.AttributeNames), Name + "," + Name);

            outputs[nameof(TrimTextFields.AttributesChanged)].Should().Be(0);
            columns.Should().ContainSingle().Which.Columns.Should().Equal(Name);
            this.updates.Should().BeEmpty();
        }

        [TestMethod]
        public void Invoke_WithNoAttributeNames_FailsWithoutCallingTheService()
        {
            this.AssertInvokeFailsWithoutCallingService<ArgumentException>(new Dictionary<string, object>());
        }

        [TestMethod]
        public void Invoke_WithOnlyBlankAttributeNames_FailsWithoutCallingTheService()
        {
            this.AssertInvokeFailsWithoutCallingService<InvalidPluginExecutionException>(nameof(TrimTextFields.AttributeNames), " , ");
        }

        private List<ColumnSet> ReturnsRecord(Entity record)
        {
            var columns = new List<ColumnSet>();
            this.Runtime.Service
                .Setup(value => value.Retrieve(CaseTable, this.recordId, It.IsAny<ColumnSet>()))
                .Callback<string, Guid, ColumnSet>((name, id, columnSet) => columns.Add(columnSet))
                .Returns(record);
            return columns;
        }
    }
}
```

Test that the root resolves the handler, and add a line to `Root_WithTheInvocationsServices_ResolvesEveryHandler` for each new handler, registering its activity first:

```csharp
namespace Abc.UnitTests.Workflows
{
    using System.Activities;
    using System.Runtime.Serialization;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Execution;
    using Abc.UnitTests.Support;
    using Abc.Workflows;
    using Abc.Workflows.TextTrimming;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Workflow;

    [TestClass]
    public sealed class WorkflowCompositionRootTests
    {
        private readonly WorkflowRuntime runtime = new WorkflowRuntime();

        [TestMethod]
        public void Root_Always_ReturnsTheSameContainer()
        {
            WorkflowCompositionRoot.Root.Should().BeSameAs(WorkflowCompositionRoot.Root);
        }

        [TestMethod]
        public void Root_WithTheInvocationsServices_ResolvesEveryHandler()
        {
            using (var scope = this.CreateScope())
            {
                scope.Register<TrimTextFields>(new TrimTextFields());

                scope.Resolve<TrimTextFieldsHandler>().Should().NotBeNull();
            }
        }

        // Registers what WorkflowActivityBase registers for each invocation. Only the workflow runtime can create a
        // CodeActivityContext, and resolving a handler doesn't use it, so an uninitialised one stands in.
        private PluginContainer CreateScope()
        {
            var scope = WorkflowCompositionRoot.Root.CreateExecutionScope();
            scope.Register<CodeActivityContext>((CodeActivityContext)FormatterServices.GetUninitializedObject(typeof(CodeActivityContext)));
            scope.Register<IWorkflowContext>(this.runtime.Context.Object);
            scope.Register<IOrganizationServiceFactory>(this.runtime.Factory.Object);
            scope.Register<IOrganizationService>(this.runtime.Service.Object);
            scope.Register<ITracingService>(this.runtime.Tracing);
            scope.Register<IExecutionServiceProvider>(new WorkflowExecutionServiceProvider(this.runtime.Factory.Object, this.runtime.Context.Object));
            return scope;
        }
    }
}
```

The activity is the class registered with the assembly. It declares its arguments and registers itself in each invocation's scope, so that its handler can read and set them. It holds no other code.

```csharp
namespace Abc.Workflows.TextTrimming
{
    using System.Activities;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Workflows;
    using Microsoft.Xrm.Sdk.Workflow;

    /// <summary>
    /// Removes leading and trailing white space from named text attributes of the process's primary record, and
    /// outputs how many changed.
    /// </summary>
    public sealed class TrimTextFields : WorkflowActivityBase<TrimTextFieldsHandler>
    {
        /// <summary>Initializes a new instance of the <see cref="TrimTextFields"/> class.</summary>
        public TrimTextFields()
            : base(WorkflowCompositionRoot.Root)
        {
        }

        /// <summary>Gets or sets the logical names of the attributes to trim, separated by commas.</summary>
        [RequiredArgument]
        [Input("Attribute logical names (comma-separated)")]
        public InArgument<string> AttributeNames { get; set; }

        /// <summary>Gets or sets the number of attributes that changed.</summary>
        [Output("Attributes changed")]
        public OutArgument<int> AttributesChanged { get; set; }

        /// <inheritdoc/>
        protected override void RegisterActivity(PluginContainer scope)
        {
            scope.Register<TrimTextFields>(this);
        }
    }
}
```

The handler splits the input into distinct names, ignoring blanks, and fails with a message makers can act on if none is left. It acts on the primary record, because an `EntityReference` input must name one table (see [workflow-activity-contract.md](workflow-activity-contract.md)). It catches nothing, so a failure fails the process.

```csharp
namespace Abc.Workflows.TextTrimming
{
    using System;
    using System.Activities;
    using System.Linq;
    using Abc.Application.TextTrimming;
    using Abc.Infrastructure.Workflows;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Workflow;

    /// <summary>
    /// Adapts <see cref="TrimTextFields"/> to <see cref="ITextFieldTrimmer"/>, for the primary record of a process on
    /// any table. A failure fails the process.
    /// </summary>
    public sealed class TrimTextFieldsHandler : IWorkflowActivityHandler
    {
        private readonly TrimTextFields activity;
        private readonly CodeActivityContext context;
        private readonly IWorkflowContext workflowContext;
        private readonly ITextFieldTrimmer trimmer;

        /// <summary>Initializes a new instance of the <see cref="TrimTextFieldsHandler"/> class.</summary>
        /// <param name="activity">The activity, whose arguments this handler reads and sets.</param>
        /// <param name="context">The activity's context, through which its arguments are read and set.</param>
        /// <param name="workflowContext">The process context, which names the primary record.</param>
        /// <param name="trimmer">The service that trims the record.</param>
        public TrimTextFieldsHandler(
            TrimTextFields activity,
            CodeActivityContext context,
            IWorkflowContext workflowContext,
            ITextFieldTrimmer trimmer)
        {
            this.activity = activity ?? throw new ArgumentNullException(nameof(activity));
            this.context = context ?? throw new ArgumentNullException(nameof(context));
            this.workflowContext = workflowContext ?? throw new ArgumentNullException(nameof(workflowContext));
            this.trimmer = trimmer ?? throw new ArgumentNullException(nameof(trimmer));
        }

        /// <inheritdoc/>
        public void Execute()
        {
            var names = (this.activity.AttributeNames.Get(this.context) ?? string.Empty)
                .Split(',')
                .Select(name => name.Trim())
                .Where(name => name.Length > 0)
                .Distinct()
                .ToList();
            if (names.Count == 0)
            {
                throw new InvalidPluginExecutionException("Supply at least one attribute logical name.");
            }

            // An EntityReference argument must name its table, so an activity for any table acts on the primary record.
            var record = new EntityReference(this.workflowContext.PrimaryEntityName, this.workflowContext.PrimaryEntityId);
            var changed = this.trimmer.Trim(record, names);
            this.activity.AttributesChanged.Set(this.context, changed);
        }
    }
}
```

The workflow head's composition root registers the service and the handler, but not the activity: the host creates the activity, which registers itself.

```csharp
namespace Abc.Workflows
{
    using System;
    using Abc.Application.TextTrimming;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Logging;
    using Abc.Workflows.TextTrimming;

    /// <summary>The registrations that every activity in this assembly resolves its handler from.</summary>
    internal static class WorkflowCompositionRoot
    {
        private static readonly Lazy<PluginContainer> Container = new Lazy<PluginContainer>(BuildRoot);

        /// <summary>Gets the root, built once per loaded assembly and frozen when the first invocation uses it.</summary>
        public static PluginContainer Root => Container.Value;

        // Registrations only. The host creates each activity, which registers itself in each invocation's scope, so
        // only its handler is registered here.
        private static PluginContainer BuildRoot()
        {
            var root = new PluginContainer();

            root.Register<ILogWriter, TracingLogWriter>();

            root.Register<ITextFieldTrimmer, TextFieldTrimmer>();
            root.Register<TrimTextFieldsHandler>();

            return root;
        }
    }
}
```

## Hand-off for this example

Update the plug-in assembly in the development environment. Makers then see this activity in the process designer:

| Item                   | Value                                                                                               |
| ---------------------- | --------------------------------------------------------------------------------------------------- |
| Activity type          | `Abc.Workflows.TextTrimming.TrimTextFields`                                                         |
| Name and friendly name | `TrimTextFields`, "Trim text fields"                                                                |
| Group                  | "Text utilities"                                                                                    |
| Description            | Removes leading and trailing white space from named text attributes of the process's primary record |
| Input                  | "Attribute logical names (comma-separated)", required, for example `abc_name, abc_description`      |
| Output                 | "Attributes changed", the number of attributes updated                                              |

It acts on the record the process runs on, so it works in a process on any table.
