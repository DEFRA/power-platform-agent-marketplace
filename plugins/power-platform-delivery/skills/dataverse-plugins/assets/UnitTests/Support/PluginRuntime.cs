namespace Abc.UnitTests.Support
{
    using System;
    using Abc.Infrastructure.Plugins;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.PluginTelemetry;
    using Moq;

    // Simulates the services Dataverse supplies to a single plug-in invocation.
    public sealed class PluginRuntime
    {
        public PluginRuntime()
        {
            this.Context.SetupGet(context => context.UserId).Returns(this.UserId);
            this.Context.SetupGet(context => context.InitiatingUserId).Returns(this.InitiatingUserId);
            this.Context.SetupGet(context => context.Depth).Returns(1);
            this.Context.SetupGet(context => context.OutputParameters).Returns(new ParameterCollection());
            this.Context.SetupGet(context => context.InputParameters).Returns(this.InputParameters);
            this.Context.SetupGet(context => context.PreEntityImages).Returns(this.PreImages);
            this.Context.SetupGet(context => context.PostEntityImages).Returns(this.PostImages);
            this.Factory.Setup(factory => factory.CreateOrganizationService(this.UserId)).Returns(this.Service.Object);
            this.Provider.Setup(provider => provider.GetService(typeof(IPluginExecutionContext))).Returns(this.Context.Object);
            this.Provider.Setup(provider => provider.GetService(typeof(IOrganizationServiceFactory))).Returns(this.Factory.Object);
            this.Provider.Setup(provider => provider.GetService(typeof(ITracingService))).Returns(this.Tracing);
        }

        public Guid UserId { get; } = Guid.NewGuid();

        public Guid InitiatingUserId { get; } = Guid.NewGuid();

        public Mock<IServiceProvider> Provider { get; } = new Mock<IServiceProvider>();

        public Mock<IPluginExecutionContext> Context { get; } = new Mock<IPluginExecutionContext>();

        public Mock<IOrganizationServiceFactory> Factory { get; } = new Mock<IOrganizationServiceFactory>();

        // Strict, so a test fails on any read or write it did not set up.
        public Mock<IOrganizationService> Service { get; } = new Mock<IOrganizationService>(MockBehavior.Strict);

        public RecordingTracingService Tracing { get; } = new RecordingTracingService();

        // The step's input parameters, such as the Target entity of a Create.
        public ParameterCollection InputParameters { get; } = new ParameterCollection();

        // The step's pre-entity images, empty unless the step registers one.
        public EntityImageCollection PreImages { get; } = new EntityImageCollection();

        // The step's post-entity images, empty unless the step registers one.
        public EntityImageCollection PostImages { get; } = new EntityImageCollection();

        // Doubles as the channel through which test handlers report what they observed.
        public ParameterCollection OutputParameters => this.Context.Object.OutputParameters;

        public PluginRuntime ForMessage(string messageName, string entityName, Guid entityId)
        {
            this.Context.SetupGet(context => context.MessageName).Returns(messageName);
            this.Context.SetupGet(context => context.PrimaryEntityName).Returns(entityName);
            this.Context.SetupGet(context => context.PrimaryEntityId).Returns(entityId);
            return this;
        }

        // Describes a step registration. See PluginStages and PluginModes for the values.
        public PluginRuntime ForStep(string messageName, string entityName, int stage, int mode)
        {
            this.Context.SetupGet(context => context.Stage).Returns(stage);
            this.Context.SetupGet(context => context.Mode).Returns(mode);
            return this.ForMessage(messageName, entityName, Guid.Empty);
        }

        // A synchronous pre-operation Create of the entity, the shape the pipeline presents to a stage 20 plug-in.
        public PluginRuntime ForPreOperationCreate(Entity target)
        {
            return this
                .ForStep(PluginMessages.Create, target.LogicalName, PluginStages.PreOperation, PluginModes.Synchronous)
                .WithTarget(target);
        }

        // 1 for an operation a user or API call started; higher when another plug-in or workflow caused it.
        public PluginRuntime WithDepth(int depth)
        {
            this.Context.SetupGet(context => context.Depth).Returns(depth);
            return this;
        }

        public PluginRuntime WithTarget(Entity target)
        {
            this.InputParameters[PluginInputParameters.Target] = target;
            return this;
        }

        public PluginRuntime WithoutTarget()
        {
            this.InputParameters.Remove(PluginInputParameters.Target);
            return this;
        }

        public PluginRuntime WithPreImage(string name, Entity image)
        {
            this.PreImages[name] = image;
            return this;
        }

        public PluginRuntime WithPostImage(string name, Entity image)
        {
            this.PostImages[name] = image;
            return this;
        }

        public PluginRuntime WithLogger(ILogger logger)
        {
            this.Provider.Setup(provider => provider.GetService(typeof(ILogger))).Returns(logger);
            return this;
        }

        public PluginRuntime WithoutService(Type serviceType)
        {
            this.Provider.Setup(provider => provider.GetService(serviceType)).Returns(null);
            return this;
        }

        public PluginRuntime WithoutOrganizationService()
        {
            this.Factory.Setup(factory => factory.CreateOrganizationService(It.IsAny<Guid?>())).Returns((IOrganizationService)null);
            return this;
        }

        // The execution a handler receives, for testing a handler without its plug-in.
        public PluginExecution CreateExecution()
        {
            return new PluginExecution(this.Context.Object, this.Service.Object, this.Tracing);
        }
    }
}
