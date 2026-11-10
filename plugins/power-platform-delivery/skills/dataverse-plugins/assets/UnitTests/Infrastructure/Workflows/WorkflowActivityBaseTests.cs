namespace Abc.UnitTests.Infrastructure.Workflows
{
    using System;
    using System.Activities;
    using System.Collections.Generic;
    using System.Linq;
    using System.Threading.Tasks;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Workflows;
    using Abc.UnitTests.Support;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Query;
    using Microsoft.Xrm.Sdk.Workflow;
    using Moq;

    [TestClass]
    public sealed class WorkflowActivityBaseTests
    {
        private const string AccountLogicalName = "account";

        // Dependencies are constructed before the handler, so they are disposed after it, in reverse order.
        private static readonly string[] CleanupOrder =
        {
            CleanupFailure.HandlerName,
            SecondCleanupService.Name,
            FirstCleanupService.Name,
        };

        private readonly PluginContainer root = new PluginContainer();
        private readonly WorkflowRuntime runtime = new WorkflowRuntime();

        [TestCleanup]
        public void Cleanup()
        {
            this.root.Dispose();
        }

        [TestMethod]
        public void Constructor_NullContainer_ThrowsArgumentNullException()
        {
            Action create = () => new TestWorkflowActivity(null);

            create.Should().ThrowExactly<ArgumentNullException>();
        }

        [TestMethod]
        public void Invoke_ValidInvocation_MapsInputToOutputThroughHandler()
        {
            var accountId = Guid.NewGuid();
            ArrangeAccount(this.runtime, accountId);

            var output = this.InvokeTestActivity(accountId);

            output["Output"].Should().BeOfType<EntityReference>().Which.Id.Should().Be(accountId);
        }

        [TestMethod]
        public void Invoke_ValidInvocation_InjectsWorkflowContextIntoHandler()
        {
            var accountId = Guid.NewGuid();
            ArrangeAccount(this.runtime, accountId);

            var output = this.InvokeTestActivity(accountId);

            output["ExecutingUser"].Should().Be(this.runtime.UserId);
        }

        [TestMethod]
        public void Invoke_ValidInvocation_InjectsOrganizationServiceIntoHandler()
        {
            var accountId = Guid.NewGuid();
            ArrangeAccount(this.runtime, accountId);

            var output = this.InvokeTestActivity(accountId);

            output["ObservedId"].Should().Be(accountId);
        }

        [TestMethod]
        public void Invoke_ValidInvocation_TracesCompletion()
        {
            var accountId = Guid.NewGuid();
            ArrangeAccount(this.runtime, accountId);

            this.InvokeTestActivity(accountId);

            this.runtime.Tracing.Messages.Should().Equal("Completed workflow handler " + typeof(TestWorkflowHandler).FullName + ".");
        }

        [TestMethod]
        public void Invoke_ActivityReusedConcurrently_KeepsInvocationValuesIsolated()
        {
            const int invocationCount = 8;
            this.root.Register<TestWorkflowHandler>();
            var activity = new TestWorkflowActivity(this.root);
            var invocations = Enumerable.Range(0, invocationCount)
                .Select(index => new { Runtime = new WorkflowRuntime(), AccountId = Guid.NewGuid() })
                .ToArray();
            var outputs = new IDictionary<string, object>[invocationCount];
            foreach (var invocation in invocations)
            {
                ArrangeAccount(invocation.Runtime, invocation.AccountId);
            }

            Parallel.For(0, invocationCount, index =>
            {
                var invocation = invocations[index];
                outputs[index] = invocation.Runtime.Invoke(activity, "Input", new EntityReference(AccountLogicalName, invocation.AccountId));
            });

            for (var index = 0; index < invocationCount; index++)
            {
                outputs[index]["ObservedId"].Should().Be(invocations[index].AccountId);
                outputs[index]["ExecutingUser"].Should().Be(invocations[index].Runtime.UserId);
            }
        }

        [TestMethod]
        public void Invoke_MissingWorkflowContext_FailsNamingTheMissingExtension()
        {
            this.root.Register<TestWorkflowHandler>();
            var activity = new TestWorkflowActivity(this.root);
            this.runtime.WithoutWorkflowContext();

            Action invoke = () => this.runtime.Invoke(activity, "Input", new EntityReference(AccountLogicalName, Guid.NewGuid()));

            invoke.Should().Throw<Exception>()
                .Which.Flatten().Should().Contain(inner => inner.Message.Contains(typeof(IWorkflowContext).FullName));
        }

        [TestMethod]
        public void Invoke_ExecutionAndCleanupBothFail_RethrowsExecutionFailure()
        {
            this.RegisterCleanupGraph();

            Action invoke = () => this.InvokeCleanupActivity(failExecution: true);

            invoke.Should().Throw<Exception>()
                .Which.Flatten().Should().Contain(inner => ReferenceEquals(inner, CleanupFailure.BusinessFailure));
        }

        [TestMethod]
        public void Invoke_ExecutionAndCleanupBothFail_StillAttemptsEveryCleanup()
        {
            this.RegisterCleanupGraph();

            Action invoke = () => this.InvokeCleanupActivity(failExecution: true);

            invoke.Should().Throw<Exception>();
            this.DisposalMessages().Should().Equal(CleanupOrder.Select(CleanupFailure.DisposedMessage));
        }

        [TestMethod]
        public void Invoke_OnlyCleanupFails_FailsTheInvocationWithTheCleanupFailure()
        {
            this.RegisterCleanupGraph();

            Action invoke = () => this.InvokeCleanupActivity(failExecution: false);

            invoke.Should().Throw<Exception>()
                .Which.Flatten().Should().Contain(inner => inner.Message == CleanupFailure.FailureMessage(CleanupFailure.HandlerName));
        }

        [TestMethod]
        public void Invoke_OnlyCleanupFails_TracesEveryCleanupFailure()
        {
            this.RegisterCleanupGraph();

            Action invoke = () => this.InvokeCleanupActivity(failExecution: false);

            invoke.Should().Throw<Exception>();
            this.runtime.Tracing.Messages.Should().Contain(
                message => message.Contains(" failed: ") && CleanupOrder.All(name => message.Contains(CleanupFailure.FailureMessage(name))));
        }

        private static void ArrangeAccount(WorkflowRuntime target, Guid accountId)
        {
            target.Service
                .Setup(service => service.Retrieve(AccountLogicalName, accountId, It.IsAny<ColumnSet>()))
                .Returns(new Entity(AccountLogicalName, accountId));
        }

        private IDictionary<string, object> InvokeTestActivity(Guid accountId)
        {
            this.root.Register<TestWorkflowHandler>();
            var activity = new TestWorkflowActivity(this.root);

            return this.runtime.Invoke(activity, "Input", new EntityReference(AccountLogicalName, accountId));
        }

        private void RegisterCleanupGraph()
        {
            this.root.Register<CleanupWorkflowHandler>();
            this.root.Register<FirstCleanupService>();
            this.root.Register<SecondCleanupService>();
        }

        private void InvokeCleanupActivity(bool failExecution)
        {
            this.runtime.Invoke(new CleanupWorkflowActivity(this.root), "FailExecution", failExecution);
        }

        private IEnumerable<string> DisposalMessages()
        {
            return this.runtime.Tracing.Messages
                .Where(message => message.StartsWith("Disposed ", StringComparison.Ordinal));
        }

        private sealed class TestWorkflowActivity : WorkflowActivityBase<TestWorkflowHandler>
        {
            public TestWorkflowActivity(PluginContainer root)
                : base(root)
            {
            }

            [Input("Input")]
            public InArgument<EntityReference> Input { get; set; }

            [Output("Output")]
            public OutArgument<EntityReference> Output { get; set; }

            [Output("Executing user")]
            public OutArgument<Guid> ExecutingUser { get; set; }

            [Output("Observed id")]
            public OutArgument<Guid> ObservedId { get; set; }

            protected override void RegisterActivity(PluginContainer scope)
            {
                scope.Register<TestWorkflowActivity>(this);
            }
        }

        private sealed class TestWorkflowHandler : IWorkflowActivityHandler
        {
            private readonly TestWorkflowActivity activity;
            private readonly CodeActivityContext context;
            private readonly IWorkflowContext workflowContext;
            private readonly IOrganizationService service;

            public TestWorkflowHandler(
                TestWorkflowActivity activity,
                CodeActivityContext context,
                IWorkflowContext workflowContext,
                IOrganizationService service)
            {
                this.activity = activity;
                this.context = context;
                this.workflowContext = workflowContext;
                this.service = service;
            }

            public void Execute()
            {
                var input = this.activity.Input.Get(this.context);
                var observed = this.service.Retrieve(input.LogicalName, input.Id, new ColumnSet());
                this.activity.Output.Set(this.context, new EntityReference(input.LogicalName, input.Id));
                this.activity.ExecutingUser.Set(this.context, this.workflowContext.UserId);
                this.activity.ObservedId.Set(this.context, observed.Id);
            }
        }

        private sealed class CleanupWorkflowActivity : WorkflowActivityBase<CleanupWorkflowHandler>
        {
            public CleanupWorkflowActivity(PluginContainer root)
                : base(root)
            {
            }

            [Input("Fail execution")]
            public InArgument<bool> FailExecution { get; set; }

            protected override void RegisterActivity(PluginContainer scope)
            {
                scope.Register<CleanupWorkflowActivity>(this);
            }
        }

        private sealed class CleanupWorkflowHandler : IWorkflowActivityHandler, IDisposable
        {
            private readonly CleanupWorkflowActivity activity;
            private readonly CodeActivityContext context;
            private readonly ITracingService tracing;

            public CleanupWorkflowHandler(
                CleanupWorkflowActivity activity,
                CodeActivityContext context,
                ITracingService tracing,
                FirstCleanupService first,
                SecondCleanupService second)
            {
                this.activity = activity;
                this.context = context;
                this.tracing = tracing;
                this.First = first;
                this.Second = second;
            }

            public FirstCleanupService First { get; }

            public SecondCleanupService Second { get; }

            public void Execute()
            {
                if (this.activity.FailExecution.Get(this.context))
                {
                    throw CleanupFailure.BusinessFailure;
                }
            }

            public void Dispose()
            {
                CleanupFailure.DisposeAndFail(this.tracing, CleanupFailure.HandlerName);
            }
        }
    }
}
