namespace Abc.UnitTests.Infrastructure.Execution
{
    using System;
    using Abc.Infrastructure.Execution;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Moq;

    [TestClass]
    public sealed class PluginExecutionServiceProviderTests
    {
        private readonly Guid executingUserId = Guid.NewGuid();
        private readonly Guid initiatingUserId = Guid.NewGuid();
        private readonly Mock<IPluginExecutionContext> context = new Mock<IPluginExecutionContext>();
        private readonly Mock<IOrganizationServiceFactory> factory = new Mock<IOrganizationServiceFactory>(MockBehavior.Strict);
        private readonly PluginExecutionServiceProvider provider;

        public PluginExecutionServiceProviderTests()
        {
            this.context.SetupGet(value => value.UserId).Returns(this.executingUserId);
            this.context.SetupGet(value => value.InitiatingUserId).Returns(this.initiatingUserId);
            this.provider = new PluginExecutionServiceProvider(this.factory.Object, this.context.Object);
        }

        [TestMethod]
        public void Constructor_NullFactory_ThrowsArgumentNullException()
        {
            Action create = () => new PluginExecutionServiceProvider(null, this.context.Object);

            create.Should().ThrowExactly<ArgumentNullException>();
        }

        [TestMethod]
        public void Constructor_NullContext_ThrowsArgumentNullException()
        {
            Action create = () => new PluginExecutionServiceProvider(this.factory.Object, null);

            create.Should().ThrowExactly<ArgumentNullException>();
        }

        [TestMethod]
        public void GetExecutingUserService_ContextHasUserId_CreatesServiceForThatUser()
        {
            var expected = Mock.Of<IOrganizationService>();
            this.factory.Setup(value => value.CreateOrganizationService(this.executingUserId)).Returns(expected);

            var actual = this.provider.GetExecutingUserService();

            actual.Should().BeSameAs(expected);
        }

        [TestMethod]
        public void GetExecutingUserService_ContextHasEmptyUserId_PassesEmptyGuidToFactory()
        {
            var expected = Mock.Of<IOrganizationService>();
            this.context.SetupGet(value => value.UserId).Returns(Guid.Empty);
            this.factory.Setup(value => value.CreateOrganizationService(Guid.Empty)).Returns(expected);

            var actual = this.provider.GetExecutingUserService();

            actual.Should().BeSameAs(expected);
        }

        [TestMethod]
        public void GetInitiatingUserService_ContextHasInitiatingUserId_CreatesServiceForThatUser()
        {
            var expected = Mock.Of<IOrganizationService>();
            this.factory.Setup(value => value.CreateOrganizationService(this.initiatingUserId)).Returns(expected);

            var actual = this.provider.GetInitiatingUserService();

            actual.Should().BeSameAs(expected);
        }

        [TestMethod]
        public void GetSystemService_Always_CreatesServiceWithoutUserId()
        {
            var expected = Mock.Of<IOrganizationService>();
            this.factory.Setup(value => value.CreateOrganizationService((Guid?)null)).Returns(expected);

            var actual = this.provider.GetSystemService();

            actual.Should().BeSameAs(expected);
        }

        [TestMethod]
        public void GetExecutingUserService_FactoryReturnsNull_ThrowsInvalidOperationException()
        {
            this.factory.Setup(value => value.CreateOrganizationService(this.executingUserId)).Returns((IOrganizationService)null);

            Action get = () => this.provider.GetExecutingUserService();

            get.Should().ThrowExactly<InvalidOperationException>();
        }

        [TestMethod]
        public void GetInitiatingUserService_FactoryReturnsNull_ThrowsInvalidOperationException()
        {
            this.factory.Setup(value => value.CreateOrganizationService(this.initiatingUserId)).Returns((IOrganizationService)null);

            Action get = () => this.provider.GetInitiatingUserService();

            get.Should().ThrowExactly<InvalidOperationException>();
        }

        [TestMethod]
        public void GetSystemService_FactoryReturnsNull_ThrowsInvalidOperationException()
        {
            this.factory.Setup(value => value.CreateOrganizationService((Guid?)null)).Returns((IOrganizationService)null);

            Action get = () => this.provider.GetSystemService();

            get.Should().ThrowExactly<InvalidOperationException>();
        }
    }
}
