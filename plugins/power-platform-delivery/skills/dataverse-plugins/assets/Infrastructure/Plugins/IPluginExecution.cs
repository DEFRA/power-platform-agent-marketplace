namespace Abc.Infrastructure.Plugins
{
    using Microsoft.Xrm.Sdk;

    /// <summary>The current invocation's SDK services, for a handler that needs several of them.</summary>
    public interface IPluginExecution
    {
        /// <summary>Gets the current plug-in execution context.</summary>
        IPluginExecutionContext Context { get; }

        /// <summary>Gets the organisation service for the step's executing user.</summary>
        IOrganizationService Service { get; }

        /// <summary>Gets the current invocation's tracing service.</summary>
        ITracingService Tracing { get; }
    }
}
