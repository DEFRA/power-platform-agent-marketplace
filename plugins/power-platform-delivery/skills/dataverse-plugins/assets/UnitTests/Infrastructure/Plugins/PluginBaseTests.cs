namespace Abc.UnitTests.Infrastructure.Plugins
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Threading.Tasks;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Plugins;
    using Abc.UnitTests.Support;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.PluginTelemetry;
    using Moq;

    [TestClass]
    public sealed class PluginBaseTests
    {
        private const string FailKey = "fail";
        private const string CompletedKey = "completed";
        private const string DisposedKey = "disposed";
        private const string ExecutionContextKey = "execution.Context";
        private const string ExecutionServiceKey = "execution.Service";
        private const string ExecutionTracingKey = "execution.Tracing";
        private const string ServiceKey = "service";
        private const string TracingKey = "tracing";
        private const string LoggerKey = "logger";
        private const string ConfigurationKey = "configuration";
        private const string UnsecureConfiguration = "{\"setting\":\"unsecure value\"}";
        private const string SecureConfiguration = "secure-configuration-value";

        // Dependencies are constructed before the handler, so they are disposed after it, in reverse order.
        private static readonly string[] CleanupOrder =
        {
            CleanupFailure.HandlerName,
            SecondCleanupService.Name,
            FirstCleanupService.Name,
        };

        private readonly PluginContainer root = new PluginContainer();
        private readonly PluginRuntime runtime = new PluginRuntime();

        [TestCleanup]
        public void Cleanup()
        {
            this.root.Dispose();
        }

        [TestMethod]
        public void Constructor_NullContainer_ThrowsArgumentNullException()
        {
            Action create = () => new Adapter<RecordingHandler>(null);

            create.Should().ThrowExactly<ArgumentNullException>();
        }

        [TestMethod]
        public void Constructor_NullContainerWithStepConfiguration_ThrowsArgumentNullException()
        {
            Action create = () => new Adapter<RecordingHandler>(null, UnsecureConfiguration, SecureConfiguration);

            create.Should().ThrowExactly<ArgumentNullException>();
        }

        [TestMethod]
        public void Execute_NullServiceProvider_ThrowsArgumentNullException()
        {
            var plugin = new Adapter<RecordingHandler>(this.root);

            Action execute = () => plugin.Execute(null);

            execute.Should().ThrowExactly<ArgumentNullException>();
        }

        [TestMethod]
        public void Execute_ValidInvocation_ExecutesHandler()
        {
            this.root.Register<RecordingHandler>();
            var plugin = new Adapter<RecordingHandler>(this.root);

            plugin.Execute(this.runtime.Provider.Object);

            this.runtime.OutputParameters[CompletedKey].Should().Be(true);
        }

        [TestMethod]
        public void Execute_ValidInvocation_CreatesServiceForExecutingUser()
        {
            this.root.Register<RecordingHandler>();
            var plugin = new Adapter<RecordingHandler>(this.root);

            plugin.Execute(this.runtime.Provider.Object);

            this.runtime.Factory.Verify(factory => factory.CreateOrganizationService(this.runtime.UserId), Times.Once);
        }

        [TestMethod]
        public void Execute_ValidInvocation_InjectsInvocationServicesIntoHandler()
        {
            this.root.Register<RecordingHandler>();
            var plugin = new Adapter<RecordingHandler>(this.root);

            plugin.Execute(this.runtime.Provider.Object);

            this.runtime.OutputParameters[ServiceKey].Should().BeSameAs(this.runtime.Service.Object);
            this.runtime.OutputParameters[TracingKey].Should().BeSameAs(this.runtime.Tracing);
        }

        [TestMethod]
        public void Execute_ValidInvocation_ProvidesSameServicesThroughPluginExecution()
        {
            this.root.Register<RecordingHandler>();
            var plugin = new Adapter<RecordingHandler>(this.root);

            plugin.Execute(this.runtime.Provider.Object);

            this.runtime.OutputParameters[ExecutionContextKey].Should().BeSameAs(this.runtime.Context.Object);
            this.runtime.OutputParameters[ExecutionServiceKey].Should().BeSameAs(this.runtime.Service.Object);
            this.runtime.OutputParameters[ExecutionTracingKey].Should().BeSameAs(this.runtime.Tracing);
        }

        [TestMethod]
        public void Execute_ValidInvocation_TracesStartAndCompletion()
        {
            this.root.Register<RecordingHandler>();
            var plugin = new Adapter<RecordingHandler>(this.root);

            plugin.Execute(this.runtime.Provider.Object);

            var handlerName = typeof(RecordingHandler).FullName;
            this.runtime.Tracing.Messages.Should().Equal(
                "Starting handler " + handlerName + ".",
                "Completed handler " + handlerName + ".");
        }

        [TestMethod]
        [DataRow("Starting handler")]
        [DataRow("Completed handler")]
        public void Execute_TracingFailsOnStartOrCompletion_DoesNotFailTheStep(string failingPrefix)
        {
            this.root.Register<RecordingHandler>();
            this.runtime.Tracing.ThrowWhenMessageStartsWith(failingPrefix);
            var plugin = new Adapter<RecordingHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().NotThrow();
            this.runtime.OutputParameters[ServiceKey].Should().BeSameAs(this.runtime.Service.Object);
        }

        [TestMethod]
        public void Execute_PluginReusedAcrossInvocations_GivesEachInvocationItsOwnServices()
        {
            this.root.Register<RecordingHandler>();
            var plugin = new Adapter<RecordingHandler>(this.root);
            var secondRuntime = new PluginRuntime();

            plugin.Execute(this.runtime.Provider.Object);
            plugin.Execute(secondRuntime.Provider.Object);

            this.runtime.OutputParameters[ServiceKey].Should().BeSameAs(this.runtime.Service.Object);
            secondRuntime.OutputParameters[ServiceKey].Should().BeSameAs(secondRuntime.Service.Object);
        }

        [TestMethod]
        public void Execute_ConcurrentInvocations_IsolateExecutionState()
        {
            const int invocationCount = 10;
            this.root.Register<RecordingHandler>();
            var plugin = new Adapter<RecordingHandler>(this.root);
            var runtimes = Enumerable.Range(0, invocationCount).Select(index => new PluginRuntime()).ToArray();

            Parallel.ForEach(runtimes, invocation => plugin.Execute(invocation.Provider.Object));

            runtimes.Should().AllSatisfy(invocation =>
            {
                invocation.OutputParameters[ServiceKey].Should().BeSameAs(invocation.Service.Object);
                invocation.OutputParameters[CompletedKey].Should().Be(true);
            });
        }

        [TestMethod]
        public void Execute_LoggerAvailable_InjectsLoggerIntoHandler()
        {
            var logger = Mock.Of<ILogger>();
            this.runtime.WithLogger(logger);
            this.root.Register<LoggingHandler>();
            var plugin = new Adapter<LoggingHandler>(this.root);

            plugin.Execute(this.runtime.Provider.Object);

            this.runtime.OutputParameters[LoggerKey].Should().BeSameAs(logger);
        }

        [TestMethod]
        public void Execute_LoggerUnavailable_FailsHandlerThatRequiresIt()
        {
            this.root.Register<LoggingHandler>();
            var plugin = new Adapter<LoggingHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>()
                .Which.InnerException.Message.Should().Contain(typeof(ILogger).Name);
        }

        [TestMethod]
        [DataRow(typeof(ITracingService))]
        [DataRow(typeof(IPluginExecutionContext))]
        [DataRow(typeof(IOrganizationServiceFactory))]
        public void Execute_MissingRuntimeService_ThrowsInvalidPluginExecutionNamingTheService(Type missingService)
        {
            this.runtime.WithoutService(missingService);
            this.root.Register<RecordingHandler>();
            var plugin = new Adapter<RecordingHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>()
                .WithInnerExceptionExactly<InvalidOperationException>()
                .WithMessage("*" + missingService.FullName + "*");
        }

        [TestMethod]
        public void Execute_FactoryReturnsNoService_ThrowsInvalidPluginExecutionException()
        {
            this.runtime.WithoutOrganizationService();
            this.root.Register<RecordingHandler>();
            var plugin = new Adapter<RecordingHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>()
                .WithInnerExceptionExactly<InvalidOperationException>();
        }

        [TestMethod]
        public void Execute_HandlerThrows_WrapsFailureInInvalidPluginExecutionException()
        {
            this.root.Register<FailingHandler>();
            var plugin = new Adapter<FailingHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>()
                .WithInnerExceptionExactly<SimulatedFailureException>()
                .WithMessage("handler failed");
        }

        [TestMethod]
        public void Execute_HandlerThrows_TracesFailure()
        {
            this.root.Register<FailingHandler>();
            var plugin = new Adapter<FailingHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>();
            this.runtime.Tracing.Messages.Should().Contain(
                message => message.StartsWith("Handler ", StringComparison.Ordinal) && message.Contains("handler failed"));
        }

        [TestMethod]
        public void Execute_HandlerThrowsPlatformException_RethrowsSameInstance()
        {
            this.root.Register<PlatformFailureHandler>();
            var plugin = new Adapter<PlatformFailureHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>().Which.Should().BeSameAs(CleanupFailure.BusinessFailure);
        }

        [TestMethod]
        public void Execute_StepConfiguration_InjectsTheValuesDataverseSupplied()
        {
            this.root.Register<ConfigurationHandler>();
            var plugin = new Adapter<ConfigurationHandler>(this.root, UnsecureConfiguration, SecureConfiguration);

            plugin.Execute(this.runtime.Provider.Object);

            var configuration = (PluginStepConfiguration)this.runtime.OutputParameters[ConfigurationKey];
            configuration.Unsecure.Should().Be(UnsecureConfiguration);
            configuration.Secure.Should().Be(SecureConfiguration);
        }

        [TestMethod]
        public void Execute_NoStepConfiguration_InjectsEmptyValues()
        {
            this.root.Register<ConfigurationHandler>();
            var plugin = new Adapter<ConfigurationHandler>(this.root);

            plugin.Execute(this.runtime.Provider.Object);

            var configuration = (PluginStepConfiguration)this.runtime.OutputParameters[ConfigurationKey];
            configuration.Unsecure.Should().BeNull();
            configuration.Secure.Should().BeNull();
        }

        [TestMethod]
        public void Execute_StepConfiguration_NeverTracesTheSecureConfiguration()
        {
            this.root.Register<ConfigurationHandler>();
            var plugin = new Adapter<ConfigurationHandler>(this.root, UnsecureConfiguration, SecureConfiguration);

            plugin.Execute(this.runtime.Provider.Object);

            this.runtime.Tracing.Messages.Should().NotContain(message => message.Contains(SecureConfiguration));
        }

        [TestMethod]
        public void Execute_HandlerWithStepConfigurationFails_NeverTracesTheSecureConfiguration()
        {
            this.runtime.OutputParameters[FailKey] = true;
            this.root.Register<ConfigurationHandler>();
            var plugin = new Adapter<ConfigurationHandler>(this.root, UnsecureConfiguration, SecureConfiguration);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>();
            this.runtime.Tracing.Messages.Should().NotContain(message => message.Contains(SecureConfiguration));
        }

        [TestMethod]
        public void Execute_DisposableHandlerSucceeds_DisposesHandler()
        {
            this.root.Register<DisposableHandler>();
            var plugin = new Adapter<DisposableHandler>(this.root);

            plugin.Execute(this.runtime.Provider.Object);

            this.runtime.OutputParameters[DisposedKey].Should().Be(true);
        }

        [TestMethod]
        public void Execute_DisposableHandlerFails_DisposesHandler()
        {
            this.runtime.OutputParameters[FailKey] = true;
            this.root.Register<DisposableHandler>();
            var plugin = new Adapter<DisposableHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>();
            this.runtime.OutputParameters[DisposedKey].Should().Be(true);
        }

        [TestMethod]
        public void Execute_ExecutionAndCleanupBothFail_RethrowsExecutionFailure()
        {
            this.RegisterCleanupGraph();
            this.runtime.OutputParameters[FailKey] = true;
            var plugin = new Adapter<CleanupFailureHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>().Which.Should().BeSameAs(CleanupFailure.BusinessFailure);
        }

        [TestMethod]
        public void Execute_ExecutionAndCleanupBothFail_StillAttemptsEveryCleanup()
        {
            this.RegisterCleanupGraph();
            this.runtime.OutputParameters[FailKey] = true;
            var plugin = new Adapter<CleanupFailureHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>();
            this.DisposalMessages().Should().Equal(CleanupOrder.Select(CleanupFailure.DisposedMessage));
        }

        [TestMethod]
        public void Execute_ExecutionAndCleanupBothFailAndTracingFails_StillRethrowsExecutionFailure()
        {
            this.RegisterCleanupGraph();
            this.runtime.OutputParameters[FailKey] = true;
            this.runtime.Tracing.ThrowWhenMessageStartsWith("Cleanup after handler");
            var plugin = new Adapter<CleanupFailureHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>().Which.Should().BeSameAs(CleanupFailure.BusinessFailure);
        }

        [TestMethod]
        public void Execute_ExecutionAndCleanupBothFail_TracesCleanupFailure()
        {
            this.RegisterCleanupGraph();
            this.runtime.OutputParameters[FailKey] = true;
            var plugin = new Adapter<CleanupFailureHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>();
            this.runtime.Tracing.Messages.Should().Contain(message => message.StartsWith("Cleanup after handler", StringComparison.Ordinal));
        }

        [TestMethod]
        public void Execute_OnlyCleanupFails_ThrowsAggregateOfEveryCleanupFailure()
        {
            this.RegisterCleanupGraph();
            var plugin = new Adapter<CleanupFailureHandler>(this.root);

            Action execute = () => plugin.Execute(this.runtime.Provider.Object);

            execute.Should().ThrowExactly<InvalidPluginExecutionException>()
                .Which.InnerException.Should().BeOfType<AggregateException>()
                .Which.InnerExceptions.Select(inner => inner.Message)
                .Should().Equal(CleanupOrder.Select(CleanupFailure.FailureMessage));
        }

        private void RegisterCleanupGraph()
        {
            this.root.Register<CleanupFailureHandler>();
            this.root.Register<FirstCleanupService>();
            this.root.Register<SecondCleanupService>();
        }

        private IEnumerable<string> DisposalMessages()
        {
            return this.runtime.Tracing.Messages
                .Where(message => message.StartsWith("Disposed ", StringComparison.Ordinal));
        }

        private sealed class Adapter<THandler> : PluginBase<THandler>
            where THandler : IPluginHandler
        {
            public Adapter(PluginContainer container)
                : base(container)
            {
            }

            public Adapter(PluginContainer container, string unsecureConfiguration, string secureConfiguration)
                : base(container, unsecureConfiguration, secureConfiguration)
            {
            }
        }

        private sealed class RecordingHandler : IPluginHandler
        {
            private readonly IPluginExecution execution;
            private readonly IPluginExecutionContext context;
            private readonly IOrganizationService service;
            private readonly ITracingService tracing;

            public RecordingHandler(IPluginExecution execution, IPluginExecutionContext context, IOrganizationService service, ITracingService tracing)
            {
                this.execution = execution;
                this.context = context;
                this.service = service;
                this.tracing = tracing;
            }

            public void Execute()
            {
                var output = this.context.OutputParameters;
                output[CompletedKey] = true;
                output[ServiceKey] = this.service;
                output[TracingKey] = this.tracing;
                output[ExecutionContextKey] = this.execution.Context;
                output[ExecutionServiceKey] = this.execution.Service;
                output[ExecutionTracingKey] = this.execution.Tracing;
            }
        }

        private sealed class LoggingHandler : IPluginHandler
        {
            private readonly IPluginExecutionContext context;
            private readonly ILogger logger;

            public LoggingHandler(IPluginExecutionContext context, ILogger logger)
            {
                this.context = context;
                this.logger = logger;
            }

            public void Execute()
            {
                this.context.OutputParameters[LoggerKey] = this.logger;
            }
        }

        private sealed class ConfigurationHandler : IPluginHandler
        {
            private readonly IPluginExecutionContext context;
            private readonly PluginStepConfiguration configuration;

            public ConfigurationHandler(IPluginExecutionContext context, PluginStepConfiguration configuration)
            {
                this.context = context;
                this.configuration = configuration;
            }

            public void Execute()
            {
                this.context.OutputParameters[ConfigurationKey] = this.configuration;
                if (this.context.OutputParameters.Contains(FailKey))
                {
                    throw new SimulatedFailureException("handler failed");
                }
            }
        }

        private sealed class FailingHandler : IPluginHandler
        {
            public void Execute()
            {
                throw new SimulatedFailureException("handler failed");
            }
        }

        private sealed class PlatformFailureHandler : IPluginHandler
        {
            public void Execute()
            {
                throw CleanupFailure.BusinessFailure;
            }
        }

        private sealed class DisposableHandler : IPluginHandler, IDisposable
        {
            private readonly IPluginExecutionContext context;

            public DisposableHandler(IPluginExecutionContext context)
            {
                this.context = context;
            }

            public void Execute()
            {
                if (this.context.OutputParameters.Contains(FailKey))
                {
                    throw new SimulatedFailureException("handler failed");
                }
            }

            public void Dispose()
            {
                this.context.OutputParameters[DisposedKey] = true;
            }
        }

        private sealed class CleanupFailureHandler : IPluginHandler, IDisposable
        {
            private readonly IPluginExecutionContext context;
            private readonly ITracingService tracing;

            public CleanupFailureHandler(
                IPluginExecutionContext context,
                ITracingService tracing,
                FirstCleanupService first,
                SecondCleanupService second)
            {
                this.context = context;
                this.tracing = tracing;
                this.First = first;
                this.Second = second;
            }

            public FirstCleanupService First { get; }

            public SecondCleanupService Second { get; }

            public void Execute()
            {
                if (this.context.OutputParameters.Contains(FailKey))
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
