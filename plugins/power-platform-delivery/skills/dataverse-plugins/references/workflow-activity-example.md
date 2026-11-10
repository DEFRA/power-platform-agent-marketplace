# Worked example: a configurable custom workflow activity

The capability is **trim whitespace from named text attributes of any record**. It is named for that capability, and everything that varies (the record and the attributes) is an input, so makers reuse it across processes. It is one small job, not a business process.

The code compiles on .NET Framework 4.8 with C# 13, and the tests pass with MSTest, FluentAssertions 7 and Moq. XML documentation is omitted for brevity: add it if the project's analysers require it. It uses the sketch classes in [base-classes.md](base-classes.md) (`WorkflowActivityBase`, `IPluginLogger`). Namespaces are placeholders.

Build it in this order: the business logic class, tested directly, then the activity, tested through `WorkflowInvoker`.

## 1. Business logic

Test:

```csharp
namespace Abc.Plugins.Tests;

using System;
using System.Activities;
using System.Collections.Generic;
using FluentAssertions;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using Microsoft.Xrm.Sdk.Workflow;
using Moq;

[TestClass]
public sealed class TrimTextFieldsTests
{
    private readonly Mock<IOrganizationService> service = new();
    private readonly EntityReference applicant = new("abc_applicant", Guid.NewGuid());

    [TestMethod]
    public void TextFieldTrimmer_Trim_UpdatesOnlyTheAttributesThatNeedTrimming()
    {
        this.service.Setup(s => s.Retrieve("abc_applicant", this.applicant.Id, It.IsAny<ColumnSet>()))
            .Returns(new Entity("abc_applicant", this.applicant.Id) { ["abc_name"] = "  Ada ", ["abc_town"] = "Leeds" });
        var subject = new TextFieldTrimmer(this.service.Object, Mock.Of<IPluginLogger>());

        var changed = subject.Trim(this.applicant, new[] { "abc_name", "abc_town" });

        changed.Should().Be(1);
        this.service.Verify(s => s.Update(It.Is<Entity>(e => e.Attributes.Count == 1 && (string)e["abc_name"] == "Ada")), Times.Once);
    }

    // The activity tests follow in section 2.
}
```

Code:

```csharp
namespace Abc.Plugins;

using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

public sealed class TextFieldTrimmer
{
    private readonly IOrganizationService service;
    private readonly IPluginLogger logger;

    public TextFieldTrimmer(IOrganizationService service, IPluginLogger logger)
    {
        this.service = service ?? throw new ArgumentNullException(nameof(service));
        this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public int Trim(EntityReference record, IReadOnlyCollection<string> attributeNames)
    {
        var current = this.service.Retrieve(record.LogicalName, record.Id, new ColumnSet(attributeNames.ToArray()));
        var update = new Entity(record.LogicalName, record.Id);

        foreach (var name in attributeNames)
        {
            if (current.GetAttributeValue<string>(name) is { } value && value.Trim() != value)
            {
                update[name] = value.Trim();
            }
        }

        if (update.Attributes.Count == 0)
        {
            this.logger.Info($"{record.LogicalName} {record.Id} needed no trimming.");
            return 0;
        }

        this.service.Update(update);
        return update.Attributes.Count;
    }
}
```

## 2. Activity

Add these tests to `TrimTextFieldsTests`. Inputs are keyed by the argument property names, and the second test uses different inputs from the first, so the activity isn't tied to one use:

```csharp
    [TestMethod]
    public void Invoke_WithARecordAndAttributeNames_TrimsThemAndSetsTheOutput()
    {
        this.service.Setup(s => s.Retrieve("abc_applicant", this.applicant.Id, It.IsAny<ColumnSet>()))
            .Returns(new Entity("abc_applicant", this.applicant.Id) { ["abc_name"] = " Ada " });

        var outputs = this.CreateInvoker().Invoke(new Dictionary<string, object>
        {
            [nameof(TrimTextFields.Record)] = this.applicant,
            [nameof(TrimTextFields.AttributeNames)] = "abc_name, abc_name",
        });

        outputs[nameof(TrimTextFields.AttributesChanged)].Should().Be(1);
        this.service.Verify(s => s.Update(It.Is<Entity>(e => (string)e["abc_name"] == "Ada")), Times.Once);
    }

    [TestMethod]
    public void Invoke_WithARequiredInputMissing_Fails()
    {
        var act = () => this.CreateInvoker().Invoke(new Dictionary<string, object> { [nameof(TrimTextFields.Record)] = this.applicant });

        act.Should().Throw<ArgumentException>();
    }

    [TestMethod]
    public void Invoke_WithBlankAttributeNames_FailsWithAClearMessage()
    {
        var act = () => this.CreateInvoker().Invoke(new Dictionary<string, object>
        {
            [nameof(TrimTextFields.Record)] = this.applicant,
            [nameof(TrimTextFields.AttributeNames)] = " , ",
        });

        act.Should().Throw<InvalidPluginExecutionException>().WithMessage("*at least one*");
    }

    private WorkflowInvoker CreateInvoker()
    {
        var workflowContext = new Mock<IWorkflowContext>();
        var factory = new Mock<IOrganizationServiceFactory>();
        factory.Setup(f => f.CreateOrganizationService(It.IsAny<Guid?>())).Returns(this.service.Object);

        var invoker = new WorkflowInvoker(new TrimTextFields());
        invoker.Extensions.Add<ITracingService>(() => Mock.Of<ITracingService>());
        invoker.Extensions.Add<IWorkflowContext>(() => workflowContext.Object);
        invoker.Extensions.Add<IOrganizationServiceFactory>(() => factory.Object);

        return invoker;
    }
```

Code. It reads inputs, calls the logic and sets the output:

```csharp
namespace Abc.Plugins;

using System;
using System.Activities;
using System.Linq;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Workflow;

public sealed class TrimTextFields : WorkflowActivityBase
{
    [Input("Record")]
    [RequiredArgument]
    public InArgument<EntityReference> Record { get; set; }

    [Input("Attribute logical names (comma-separated)")]
    [RequiredArgument]
    public InArgument<string> AttributeNames { get; set; }

    [Output("Attributes changed")]
    public OutArgument<int> AttributesChanged { get; set; }

    protected override void ExecuteActivity(
        CodeActivityContext context,
        IWorkflowContext workflowContext,
        IOrganizationService service,
        IPluginLogger logger)
    {
        var names = this.AttributeNames.Get(context)
            .Split(',')
            .Select(n => n.Trim())
            .Where(n => n.Length > 0)
            .Distinct()
            .ToList();

        if (names.Count == 0)
        {
            throw new InvalidPluginExecutionException("Supply at least one attribute logical name.");
        }

        var changed = new TextFieldTrimmer(service, logger).Trim(this.Record.Get(context), names);

        this.AttributesChanged.Set(context, changed);
    }
}
```

## Hand-off for this example

Update the plug-in assembly in the development environment. Makers then see this activity in the process designer:

| Item | Value |
| --- | --- |
| Name and friendly name | `TrimTextFields`, "Trim text fields" |
| Group | "Text utilities" |
| Description | Removes leading and trailing whitespace from the named text attributes of a record |
| Inputs | Record (required), attribute logical names (required) |
| Output | Attributes changed |
