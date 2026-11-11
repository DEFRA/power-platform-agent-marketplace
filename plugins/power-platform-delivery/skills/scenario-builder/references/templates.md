# Templates

A worked example in the neutral domain: an applicant submits a case, and an inspector assigns and records an inspection. The structure is the guidance. Change the namespaces, the early-bound model types and the API calls to match the real process and the project's ScenarioBuilder version.

Know who owns each client: a persona client is released by the factory, so an event doesn't dispose it. See [clients.md](../../test-foundations/references/clients.md).

## 1. Leaf event

```csharp
namespace Abc.Scenarios.Events
{
    using System;
    using System.Threading.Tasks;
    using Abc.Model;
    using Microsoft.Extensions.Logging;
    using ScenarioBuilder;

    /// <summary>
    /// An event for an applicant submitting a case.
    /// </summary>
    /// <param name="eventId">The event ID.</param>
    /// <param name="clientFactory">The service client factory.</param>
    /// <param name="logger">The logger.</param>
    public class ApplicantSubmitsCaseEvent(string eventId, ServiceClientFactory clientFactory, ILogger<ApplicantSubmitsCaseEvent> logger)
        : Event(eventId)
    {
        private readonly ServiceClientFactory clientFactory = clientFactory;
        private readonly ILogger<ApplicantSubmitsCaseEvent> logger = logger;
        private CaseFaker caseFaker = new CaseFaker();
        private bool? isUrgent;

        /// <inheritdoc/>
        public override async Task ExecuteAsync(ScenarioContext context)
        {
            var @case = this.caseFaker.Generate();
            @case.abc_IsUrgent = this.isUrgent ?? false;

            this.logger.LogInformation("Submitting case {CaseId} (urgent: {IsUrgent}).", @case.Id, @case.abc_IsUrgent);

            var client = await this.clientFactory.GetClientAsync(Persona.Applicant);
            var caseId = await client.CreateAsync(@case);

            this.logger.LogInformation("Submitted case {CaseId}.", caseId);

            context.Set(nameof(ApplicantSubmitsCaseEvent), new Info { CaseId = caseId });
        }

        /// <summary>
        /// The outputs captured by the <see cref="ApplicantSubmitsCaseEvent"/> event.
        /// </summary>
        public class Info
        {
            /// <summary>
            /// Gets or sets the ID of the submitted case.
            /// </summary>
            public Guid CaseId { get; set; }
        }

        /// <summary>
        /// A builder for the <see cref="ApplicantSubmitsCaseEvent"/> event.
        /// </summary>
        /// <param name="eventFactory">The event factory.</param>
        /// <param name="eventId">The event ID.</param>
        /// <param name="constructorArgs">The constructor args.</param>
        public class Builder(EventFactory eventFactory, string eventId, object[] constructorArgs = null)
            : Builder<ApplicantSubmitsCaseEvent>(eventFactory, eventId, constructorArgs)
        {
            // The name and type must match the event's field: the base builder copies it across by name.
            private CaseFaker caseFaker;

            // bool? rather than bool, so the event can tell "not configured" from an explicit false.
            private bool? isUrgent;

            /// <summary>
            /// Overrides the faker used to generate the case.
            /// </summary>
            /// <param name="caseFaker">The faker to use.</param>
            /// <returns>The builder.</returns>
            public Builder WithCase(CaseFaker caseFaker)
            {
                this.caseFaker = caseFaker;

                return this;
            }

            /// <summary>
            /// Overrides whether the case is urgent.
            /// </summary>
            /// <param name="isUrgent">Whether the case is urgent.</param>
            /// <returns>The builder.</returns>
            public Builder WithIsUrgent(bool isUrgent)
            {
                this.isUrgent = isUrgent;

                return this;
            }
        }
    }
}
```

A later event reads an earlier event's outputs with `context.Get<ApplicantSubmitsCaseEvent.Info>(nameof(ApplicantSubmitsCaseEvent))`. Wrap that in a helper that names the missing dependency when the key isn't found ("the inspector event depends on the applicant event"), so a mis-ordered scenario fails clearly.

## 2. Scenario

```csharp
namespace Abc.Scenarios
{
    using System;
    using Abc.Scenarios.Events;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Logging;
    using ScenarioBuilder;

    /// <summary>
    /// A scenario for a case.
    /// </summary>
    [ComposeUsing(0, EventIds.CaseSubmission, typeof(ApplicantSubmitsCaseEvent))]
    [ComposeUsing(1, EventIds.CaseProcessing, typeof(InspectorProcessesCaseEvent))]
    public class CaseScenario : Scenario
    {
        /// <summary>
        /// Gets the outputs of the applicant submitting a case.
        /// </summary>
        /// <remarks>
        /// Named to match <see cref="ApplicantSubmitsCaseEvent"/> so it's filled from <see cref="ScenarioContext"/>.
        /// </remarks>
        public ApplicantSubmitsCaseEvent.Info ApplicantSubmitsCaseEvent { get; internal set; }

        /// <summary>
        /// Gets the outputs of the inspector processing a case.
        /// </summary>
        public InspectorProcessesCaseEvent.Info InspectorProcessesCaseEvent { get; internal set; }

        /// <summary>
        /// The IDs of the events in the <see cref="CaseScenario"/>.
        /// </summary>
        public static class EventIds
        {
            /// <summary>
            /// The ID of the case submission event.
            /// </summary>
            public const string CaseSubmission = nameof(CaseSubmission);

            /// <summary>
            /// The ID of the case processing event.
            /// </summary>
            public const string CaseProcessing = nameof(CaseProcessing);
        }

        /// <summary>
        /// A builder for the <see cref="CaseScenario"/>.
        /// </summary>
        /// <param name="clientFactory">The client factory.</param>
        /// <param name="loggerProvider">Routes the loggers injected into events to the test framework's output.</param>
        public class Builder(ServiceClientFactory clientFactory, ILoggerProvider loggerProvider) : Builder<CaseScenario>
        {
            private readonly ServiceClientFactory clientFactory = clientFactory;
            private readonly ILoggerProvider loggerProvider = loggerProvider;

            /// <summary>
            /// Configures the applicant submitting a case.
            /// </summary>
            /// <param name="configurator">The configurator.</param>
            /// <returns>The builder.</returns>
            public Builder ApplicantSubmitsCase(Action<ApplicantSubmitsCaseEvent.Builder> configurator = null)
            {
                this.ConfigureEvent<ApplicantSubmitsCaseEvent, ApplicantSubmitsCaseEvent.Builder>(EventIds.CaseSubmission, configurator);

                return this;
            }

            /// <summary>
            /// Configures the inspector processing a case.
            /// </summary>
            /// <param name="configurator">The configurator.</param>
            /// <returns>The builder.</returns>
            public Builder InspectorProcessesCase(Action<InspectorProcessesCaseEvent.Builder> configurator = null)
            {
                this.ConfigureEvent<InspectorProcessesCaseEvent, InspectorProcessesCaseEvent.Builder>(EventIds.CaseProcessing, configurator);

                return this;
            }

            /// <inheritdoc/>
            protected override IServiceCollection InitializeServices(ServiceCollection serviceCollection)
            {
                return serviceCollection
                    .AddSingleton(this.clientFactory)
                    .AddLogging(builder => builder.AddProvider(this.loggerProvider));
            }
        }
    }
}
```

## 3. Composite event

Use one only when a process has several steps that callers may stop between.

```csharp
namespace Abc.Scenarios.Events
{
    using System;
    using ScenarioBuilder;

    /// <summary>
    /// A composite event for an inspector processing a case through to an outcome.
    /// </summary>
    /// <param name="eventsFactory">The event factory.</param>
    /// <param name="eventId">The ID of the event.</param>
    [ComposeUsing(0, EventIds.InspectionAssignment, typeof(InspectorAssignsInspectionEvent))]
    [ComposeUsing(1, EventIds.OutcomeRecording, typeof(InspectorRecordsOutcomeEvent))]
    public class InspectorProcessesCaseEvent(EventFactory eventsFactory, string eventId)
        : CompositeEvent(eventsFactory, eventId)
    {
        /// <summary>
        /// The IDs of the events in the <see cref="InspectorProcessesCaseEvent"/>.
        /// </summary>
        public static class EventIds
        {
            /// <summary>
            /// The ID of the inspection assignment event.
            /// </summary>
            public const string InspectionAssignment = nameof(InspectionAssignment);

            /// <summary>
            /// The ID of the outcome recording event.
            /// </summary>
            public const string OutcomeRecording = nameof(OutcomeRecording);
        }

        /// <summary>
        /// A builder for the <see cref="InspectorProcessesCaseEvent"/>.
        /// </summary>
        /// <param name="eventBuilderFactory">The event builder factory.</param>
        /// <param name="eventFactory">The event factory.</param>
        /// <param name="eventId">The ID of the event.</param>
        public class Builder(EventBuilderFactory eventBuilderFactory, EventFactory eventFactory, string eventId)
            : Builder<InspectorProcessesCaseEvent>(eventBuilderFactory, eventFactory, eventId)
        {
            /// <summary>
            /// Configures the assignment of the inspection.
            /// </summary>
            /// <param name="configurator">The configurator.</param>
            /// <returns>The builder.</returns>
            public Builder ByAssigningInspection(Action<InspectorAssignsInspectionEvent.Builder> configurator = null)
            {
                this.ConfigureEvent<InspectorAssignsInspectionEvent, InspectorAssignsInspectionEvent.Builder>(EventIds.InspectionAssignment, configurator);

                return this;
            }

            /// <summary>
            /// Configures the recording of the outcome.
            /// </summary>
            /// <param name="configurator">The configurator.</param>
            /// <returns>The builder.</returns>
            public Builder ByRecordingOutcome(Action<InspectorRecordsOutcomeEvent.Builder> configurator = null)
            {
                this.ConfigureEvent<InspectorRecordsOutcomeEvent, InspectorRecordsOutcomeEvent.Builder>(EventIds.OutcomeRecording, configurator);

                return this;
            }
        }
    }
}
```

If one event type appears twice in a composite, give each `[ComposeUsing]` its own ID and a constructor argument (such as the type of check), and give each `By*` method its own ID.

Calling these builders is covered in [usage.md](usage.md).
