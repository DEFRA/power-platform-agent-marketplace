namespace Abc.UnitTests.Infrastructure.Plugins
{
    using System;
    using Abc.Infrastructure.Plugins;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Moq;

    [TestClass]
    public sealed class PluginExecutionTests
    {
        private readonly IPluginExecutionContext context = Mock.Of<IPluginExecutionContext>();
        private readonly IOrganizationService service = Mock.Of<IOrganizationService>();
        private readonly ITracingService tracing = Mock.Of<ITracingService>();

        [TestMethod]
        public void Constructor_NullContext_ThrowsArgumentNullException()
        {
            Action create = () => new PluginExecution(null, this.service, this.tracing);

            create.Should().ThrowExactly<ArgumentNullException>().WithParameterName("context");
        }

        [TestMethod]
        public void Constructor_NullService_ThrowsArgumentNullException()
        {
            Action create = () => new PluginExecution(this.context, null, this.tracing);

            create.Should().ThrowExactly<ArgumentNullException>().WithParameterName("service");
        }

        [TestMethod]
        public void Constructor_NullTracing_ThrowsArgumentNullException()
        {
            Action create = () => new PluginExecution(this.context, this.service, null);

            create.Should().ThrowExactly<ArgumentNullException>().WithParameterName("tracing");
        }

        [TestMethod]
        public void Constructor_ValidArguments_ExposesTheBorrowedServices()
        {
            var execution = new PluginExecution(this.context, this.service, this.tracing);

            execution.Context.Should().BeSameAs(this.context);
            execution.Service.Should().BeSameAs(this.service);
            execution.Tracing.Should().BeSameAs(this.tracing);
        }
    }
}
