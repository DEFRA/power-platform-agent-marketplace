namespace Abc.UnitTests.Infrastructure.Execution
{
    using System;
    using Abc.Infrastructure.Execution;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Workflow;
    using Moq;

    [TestClass]
    public sealed class WorkflowExecutionServiceProviderTests
    {
        private readonly Guid executingUserId = Guid.NewGuid();
        private readonly Mock<IWorkflowContext> context = new Mock<IWorkflowContext>();
        private readonly Mock<IOrganizationServiceFactory> factory = new Mock<IOrganizationServiceFactory>(MockBehavior.Strict);
        private readonly WorkflowExecutionServiceProvider provider;

        public WorkflowExecutionServiceProviderTests()
        {
            this.context.SetupGet(value => value.UserId).Returns(this.executingUserId);
            this.context.SetupGet(value => value.InitiatingUserId).Returns(this.executingUserId);
            this.provider = new WorkflowExecutionServiceProvider(this.factory.Object, this.context.Object);
        }

        [TestMethod]
        public void Constructor_NullFactory_ThrowsArgumentNullException()
        {
            Action create = () => new WorkflowExecutionServiceProvider(null, this.context.Object);

            create.Should().ThrowExactly<ArgumentNullException>();
        }

        [TestMethod]
        public void Constructor_NullContext_ThrowsArgumentNullException()
        {
            Action create = () => new WorkflowExecutionServiceProvider(this.factory.Object, null);

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
        public void GetExecutingUserService_FactoryReturnsNull_ThrowsInvalidOperationException()
        {
            this.factory.Setup(value => value.CreateOrganizationService(this.executingUserId)).Returns((IOrganizationService)null);

            Action get = () => this.provider.GetExecutingUserService();

            get.Should().ThrowExactly<InvalidOperationException>();
        }

        [TestMethod]
        public void GetInitiatingUserService_InitiatingUserIsExecutingUser_ReturnsExecutingUserService()
        {
            var expected = Mock.Of<IOrganizationService>();
            this.factory.Setup(value => value.CreateOrganizationService(this.executingUserId)).Returns(expected);

            var actual = this.provider.GetInitiatingUserService();

            actual.Should().BeSameAs(expected);
        }

        [TestMethod]
        public void GetInitiatingUserService_InitiatingUserDiffersFromExecutingUser_ThrowsNotSupportedWithoutCreatingService()
        {
            this.context.SetupGet(value => value.InitiatingUserId).Returns(Guid.NewGuid());

            Action get = () => this.provider.GetInitiatingUserService();

            get.Should().ThrowExactly<NotSupportedException>();
            this.factory.VerifyNoOtherCalls();
        }

        [TestMethod]
        public void GetSystemService_Always_ThrowsNotSupportedWithoutCreatingService()
        {
            Action get = () => this.provider.GetSystemService();

            get.Should().ThrowExactly<NotSupportedException>();
            this.factory.VerifyNoOtherCalls();
        }
    }
}
