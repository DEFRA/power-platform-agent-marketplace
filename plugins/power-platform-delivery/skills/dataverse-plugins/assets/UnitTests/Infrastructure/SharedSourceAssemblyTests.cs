namespace Abc.UnitTests.Infrastructure
{
    using System;
    using Abc.Dataverse;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Plugins;
    using Abc.Infrastructure.Workflows;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;

    // In the UnitTest configuration the heads stop compiling the shared projects and reference one assembly that
    // compiles them all. Add a type from each shared project you create, such as a query and an application service.
    [TestClass]
    public sealed class SharedSourceAssemblyTests
    {
        private static readonly Type[] SharedTypes =
        {
            typeof(IPluginHandler),
            typeof(IWorkflowActivityHandler),
            typeof(PluginContainer),
            typeof(PluginBase<>),
            typeof(WorkflowActivityBase<>),
            typeof(EntityExtensions),
        };

        [TestMethod]
        public void UnitTestConfiguration_SharedSourceTypes_ComeFromOneAssembly()
        {
            var expected = typeof(IPluginHandler).Assembly;

            SharedTypes.Should().AllSatisfy(type => type.Assembly.Should().BeSameAs(expected));
        }

        [TestMethod]
        public void UnitTestConfiguration_SharedSourceTypes_AreNotCompiledIntoTheTestAssembly()
        {
            typeof(IPluginHandler).Assembly.Should().NotBeSameAs(typeof(SharedSourceAssemblyTests).Assembly);
        }
    }
}
