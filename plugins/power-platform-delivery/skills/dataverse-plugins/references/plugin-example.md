# Worked example: a configurable plug-in

The capability is **copy configured attributes from the triggering record to a related record**. It is named for that capability, not for any first use. The lookup and the attributes are in the step's unsecure configuration, so the first requirement (copy an inspection's outcome to its case) is one row of configuration, and the next similar requirement is another step, not another plug-in.

The code compiles on .NET Framework 4.8 with C# 13, and the tests pass with MSTest, FluentAssertions 7 and Moq. XML documentation is omitted here for brevity: add it if the project's analysers require it. Adapt the shape, not the behaviour. It uses the sketch classes in [base-classes.md](base-classes.md) (`PluginBase`, `PluginContext`, `IPluginLogger`) and the polyfill [IsExternalInit.cs](../assets/IsExternalInit.cs) for `init`. Namespaces are placeholders.

## Order of work

1. Settings: configuration is parsed and validated in one place.
2. Business logic: the rule, with a second configuration as proof.
3. Plug-in: the thin adapter.

Run each test and confirm it fails for the right reason before writing its code.

## 1. Settings

Test:

```csharp
namespace Abc.Plugins.Tests;

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
        var act = () => CopyFieldsSettings.Parse(json);

        act.Should().Throw<InvalidPluginExecutionException>();
    }
}
```

Code:

```csharp
namespace Abc.Plugins;

using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Text;
using Microsoft.Xrm.Sdk;

[DataContract]
public sealed class FieldMapping
{
    [DataMember(Name = "from")]
    public string From { get; init; }

    [DataMember(Name = "to")]
    public string To { get; init; }
}

// For example {"lookup":"abc_caseid","mappings":[{"from":"abc_outcome","to":"abc_lastinspectionoutcome"}]}
[DataContract]
public sealed class CopyFieldsSettings
{
    [DataMember(Name = "lookup")]
    public string Lookup { get; init; }

    [DataMember(Name = "mappings")]
    public List<FieldMapping> Mappings { get; init; }

    public static CopyFieldsSettings Parse(string json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            throw new InvalidPluginExecutionException("The step has no configuration. Supply JSON with a lookup and mappings.");
        }

        CopyFieldsSettings settings;
        try
        {
            using var stream = new MemoryStream(Encoding.UTF8.GetBytes(json));
            settings = (CopyFieldsSettings)new DataContractJsonSerializer(typeof(CopyFieldsSettings)).ReadObject(stream);
        }
        catch (SerializationException exception)
        {
            throw new InvalidPluginExecutionException("The step configuration is not valid JSON for this plug-in.", exception);
        }

        if (string.IsNullOrWhiteSpace(settings?.Lookup))
        {
            throw new InvalidPluginExecutionException("The step configuration must set 'lookup'.");
        }

        if (settings.Mappings is null
            || settings.Mappings.Count == 0
            || settings.Mappings.Any(m => string.IsNullOrWhiteSpace(m?.From) || string.IsNullOrWhiteSpace(m.To)))
        {
            throw new InvalidPluginExecutionException("The step configuration must set 'mappings', each with 'from' and 'to'.");
        }

        return settings;
    }
}
```

## 2. Business logic

Test. The second test is the second-configuration proof:

```csharp
namespace Abc.Plugins.Tests;

using System;
using System.Collections.Generic;
using FluentAssertions;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Xrm.Sdk;
using Moq;

[TestClass]
public sealed class CopyFieldsToRelatedRecordTests
{
    private readonly Mock<IOrganizationService> service = new();
    private readonly Mock<IPluginLogger> logger = new();
    private readonly EntityReference parent = new("abc_case", Guid.NewGuid());

    [TestMethod]
    public void Execute_WithASourceHoldingAMappedAttribute_UpdatesOnlyTheRelatedRecordWithThatAttribute()
    {
        var subject = this.CreateSubject("abc_caseid", ("abc_outcome", "abc_lastoutcome"));
        var source = new Entity("abc_inspection") { ["abc_caseid"] = this.parent, ["abc_outcome"] = "Passed", ["abc_notes"] = "ignored" };

        subject.Execute(source);

        this.service.Verify(s => s.Update(It.Is<Entity>(e =>
            e.LogicalName == "abc_case"
            && e.Id == this.parent.Id
            && e.Attributes.Count == 1
            && (string)e["abc_lastoutcome"] == "Passed")), Times.Once);
    }

    [TestMethod]
    public void Execute_WithAnotherConfiguration_CopiesDifferentAttributesWithNoCodeChange()
    {
        var subject = this.CreateSubject("abc_applicantref", ("abc_notes", "abc_lastnotes"), ("abc_outcome", "abc_lastoutcome"));
        var applicant = new EntityReference("abc_applicant", Guid.NewGuid());
        var source = new Entity("abc_inspection") { ["abc_applicantref"] = applicant, ["abc_notes"] = "Follow up", ["abc_outcome"] = "Failed" };

        subject.Execute(source);

        this.service.Verify(s => s.Update(It.Is<Entity>(e =>
            e.LogicalName == "abc_applicant"
            && e.Id == applicant.Id
            && (string)e["abc_lastnotes"] == "Follow up"
            && (string)e["abc_lastoutcome"] == "Failed")), Times.Once);
    }

    [TestMethod]
    public void Execute_WithNoValueInTheLookup_WritesNothing()
    {
        var subject = this.CreateSubject("abc_caseid", ("abc_outcome", "abc_lastoutcome"));

        subject.Execute(new Entity("abc_inspection") { ["abc_outcome"] = "Passed" });

        this.service.Verify(s => s.Update(It.IsAny<Entity>()), Times.Never);
    }

    [TestMethod]
    public void Execute_WhenTheSourceHoldsNoMappedAttribute_WritesNothing()
    {
        var subject = this.CreateSubject("abc_caseid", ("abc_outcome", "abc_lastoutcome"));

        subject.Execute(new Entity("abc_inspection") { ["abc_caseid"] = this.parent });

        this.service.Verify(s => s.Update(It.IsAny<Entity>()), Times.Never);
    }

    [TestMethod]
    public void Execute_Always_DoesNotModifyTheSource()
    {
        var subject = this.CreateSubject("abc_caseid", ("abc_outcome", "abc_lastoutcome"));
        var source = new Entity("abc_inspection") { ["abc_caseid"] = this.parent, ["abc_outcome"] = "Passed" };

        subject.Execute(source);

        source.Attributes.Keys.Should().BeEquivalentTo("abc_caseid", "abc_outcome");
    }

    private CopyFieldsToRelatedRecord CreateSubject(string lookup, params (string From, string To)[] mappings)
    {
        var settings = new CopyFieldsSettings
        {
            Lookup = lookup,
            Mappings = new List<FieldMapping>(),
        };

        foreach (var (from, to) in mappings)
        {
            settings.Mappings.Add(new FieldMapping { From = from, To = to });
        }

        return new CopyFieldsToRelatedRecord(this.service.Object, this.logger.Object, settings);
    }
}
```

Code. It never sees a plug-in type, and it receives parsed, validated settings:

```csharp
namespace Abc.Plugins;

using System;
using Microsoft.Xrm.Sdk;

public sealed class CopyFieldsToRelatedRecord
{
    private readonly IOrganizationService service;
    private readonly IPluginLogger logger;
    private readonly CopyFieldsSettings settings;

    public CopyFieldsToRelatedRecord(IOrganizationService service, IPluginLogger logger, CopyFieldsSettings settings)
    {
        this.service = service ?? throw new ArgumentNullException(nameof(service));
        this.logger = logger ?? throw new ArgumentNullException(nameof(logger));
        this.settings = settings ?? throw new ArgumentNullException(nameof(settings));
    }

    public void Execute(Entity source)
    {
        if (source is null)
        {
            throw new ArgumentNullException(nameof(source));
        }

        var related = source.GetAttributeValue<EntityReference>(this.settings.Lookup);
        if (related is null)
        {
            this.logger.Info($"{source.LogicalName} has no value for {this.settings.Lookup}. Nothing to copy.");
            return;
        }

        var update = new Entity(related.LogicalName, related.Id);
        foreach (var mapping in this.settings.Mappings)
        {
            if (source.Contains(mapping.From))
            {
                update[mapping.To] = source[mapping.From];
            }
        }

        if (update.Attributes.Count == 0)
        {
            this.logger.Info($"{source.LogicalName} holds none of the mapped attributes. Nothing to copy.");
            return;
        }

        this.service.Update(update);
    }
}
```

## 3. Plug-in

Test, end to end through `IServiceProvider`:

```csharp
namespace Abc.Plugins.Tests;

using System;
using FluentAssertions;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Xrm.Sdk;
using Moq;

[TestClass]
public sealed class CopyFieldsToRelatedRecordPluginTests
{
    private const string Config = """{"lookup":"abc_caseid","mappings":[{"from":"abc_outcome","to":"abc_lastoutcome"}]}""";

    private readonly Mock<IOrganizationService> service = new();
    private readonly Mock<IPluginExecutionContext> execution = new();
    private readonly Mock<IServiceProvider> serviceProvider = new();
    private readonly EntityReference parent = new("abc_case", Guid.NewGuid());

    public CopyFieldsToRelatedRecordPluginTests()
    {
        var factory = new Mock<IOrganizationServiceFactory>();
        factory.Setup(f => f.CreateOrganizationService(It.IsAny<Guid?>())).Returns(this.service.Object);

        this.serviceProvider.Setup(p => p.GetService(typeof(ITracingService))).Returns(Mock.Of<ITracingService>());
        this.serviceProvider.Setup(p => p.GetService(typeof(IPluginExecutionContext))).Returns(this.execution.Object);
        this.serviceProvider.Setup(p => p.GetService(typeof(IOrganizationServiceFactory))).Returns(factory.Object);
    }

    [TestMethod]
    public void Execute_OnUpdateOfAnInspection_CopiesTheOutcomeToTheCase()
    {
        this.SetTarget(new Entity("abc_inspection") { ["abc_caseid"] = this.parent, ["abc_outcome"] = "Passed" });

        new CopyFieldsToRelatedRecordPlugin(Config, null).Execute(this.serviceProvider.Object);

        this.service.Verify(s => s.Update(It.Is<Entity>(e => e.Id == this.parent.Id && (string)e["abc_lastoutcome"] == "Passed")), Times.Once);
    }

    [TestMethod]
    public void Execute_WithNoConfiguration_FailsWithAClearMessageAndWritesNothing()
    {
        this.SetTarget(new Entity("abc_inspection") { ["abc_caseid"] = this.parent, ["abc_outcome"] = "Passed" });

        var act = () => new CopyFieldsToRelatedRecordPlugin(null, null).Execute(this.serviceProvider.Object);

        act.Should().Throw<InvalidPluginExecutionException>().WithMessage("*no configuration*");
        this.service.Verify(s => s.Update(It.IsAny<Entity>()), Times.Never);
    }

    [TestMethod]
    public void Execute_WhenTheServiceThrows_WrapsTheExceptionSoTheTraceLogHoldsTheDetail()
    {
        this.SetTarget(new Entity("abc_inspection") { ["abc_caseid"] = this.parent, ["abc_outcome"] = "Passed" });
        this.service.Setup(s => s.Update(It.IsAny<Entity>())).Throws(new InvalidOperationException("boom"));

        var act = () => new CopyFieldsToRelatedRecordPlugin(Config, null).Execute(this.serviceProvider.Object);

        act.Should().Throw<InvalidPluginExecutionException>().WithInnerException<InvalidOperationException>();
    }

    private void SetTarget(Entity target)
    {
        this.execution.SetupGet(c => c.InputParameters).Returns(new ParameterCollection { ["Target"] = target });
        this.execution.SetupGet(c => c.MessageName).Returns("Update");
        this.execution.SetupGet(c => c.PrimaryEntityName).Returns("abc_inspection");
    }
}
```

Code. It reads the context, parses the configuration, calls the logic and nothing else:

```csharp
namespace Abc.Plugins;

using Microsoft.Xrm.Sdk;

public sealed class CopyFieldsToRelatedRecordPlugin : PluginBase
{
    public CopyFieldsToRelatedRecordPlugin(string unsecureConfig, string secureConfig)
        : base(unsecureConfig, secureConfig)
    {
    }

    protected override void ExecutePlugin(PluginContext context)
    {
        var settings = CopyFieldsSettings.Parse(context.UnsecureConfig);
        var target = (Entity)context.Execution.InputParameters["Target"];

        new CopyFieldsToRelatedRecord(context.OrganizationService, context.Logger, settings).Execute(target);
    }
}
```

## Hand-off for this example

Register one step against the plug-in assembly in the development environment:

| Item | Value |
| --- | --- |
| Message and table | `Update` on `abc_inspection` |
| Stage and mode | Post-operation, synchronous |
| Filtering attributes | `abc_outcome` |
| Unsecure configuration | `{"lookup":"abc_caseid","mappings":[{"from":"abc_outcome","to":"abc_lastinspectionoutcome"}]}` |

A second use is another step with its own configuration. The plug-in doesn't change.
