namespace Abc.UnitTests.Infrastructure.Plugins
{
    using Abc.Infrastructure.Plugins;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;

    // The values are the platform's, so they are pinned against the documented registration values.
    [TestClass]
    public sealed class PluginConstantsTests
    {
        [TestMethod]
        public void PluginStages_HaveTheDataversePipelineStageNumbers()
        {
            PluginStages.PreValidation.Should().Be(10);
            PluginStages.PreOperation.Should().Be(20);
            PluginStages.PostOperation.Should().Be(40);
        }

        [TestMethod]
        public void PluginModes_HaveTheDataverseModeNumbers()
        {
            PluginModes.Synchronous.Should().Be(0);
            PluginModes.Asynchronous.Should().Be(1);
        }

        [TestMethod]
        public void PluginMessages_HaveTheDataverseMessageNames()
        {
            PluginMessages.Create.Should().Be("Create");
            PluginMessages.Update.Should().Be("Update");
            PluginMessages.Delete.Should().Be("Delete");
            PluginMessages.SetState.Should().Be("SetState");
        }

        [TestMethod]
        public void PluginInputParameters_HaveTheDataverseParameterNames()
        {
            PluginInputParameters.Target.Should().Be("Target");
            PluginInputParameters.EntityMoniker.Should().Be("EntityMoniker");
        }
    }
}
