namespace Abc.UnitTests.Support
{
    using System;
    using FluentAssertions;
    using FluentAssertions.Specialized;
    using Microsoft.Xrm.Sdk;

    // Base class for tests of IPlugin entry points. It supplies a simulated Dataverse invocation and the
    // assertions most plug-in tests need, so derived tests describe only the step they are exercising.
    public abstract class PluginTestBase<TPlugin>
        where TPlugin : class, IPlugin
    {
        private TPlugin plugin;

        protected PluginRuntime Runtime { get; } = new PluginRuntime();

        protected TPlugin Plugin
        {
            get
            {
                if (this.plugin == null)
                {
                    this.plugin = this.CreatePlugin();
                }

                return this.plugin;
            }
        }

        // Override to pass step configuration, as Dataverse does when the step has some.
        protected virtual TPlugin CreatePlugin()
        {
            return Activator.CreateInstance<TPlugin>();
        }

        protected void Execute()
        {
            this.Plugin.Execute(this.Runtime.Provider.Object);
        }

        // The strict service mock proves nothing was read or written when the step contract was not met.
        protected ExceptionAssertions<InvalidPluginExecutionException> AssertExecuteFailsWithoutCallingService()
        {
            Action execute = this.Execute;

            var assertion = execute.Should().Throw<InvalidPluginExecutionException>();
            this.Runtime.Service.VerifyNoOtherCalls();
            return assertion;
        }
    }
}
