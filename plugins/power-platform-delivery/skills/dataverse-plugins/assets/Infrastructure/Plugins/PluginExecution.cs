namespace Abc.Infrastructure.Plugins
{
    using System;
    using Microsoft.Xrm.Sdk;

    /// <summary>Holds the borrowed SDK services for one invocation.</summary>
    public sealed class PluginExecution : IPluginExecution
    {
        /// <summary>Initializes a new instance of the <see cref="PluginExecution"/> class.</summary>
        /// <param name="context">The current execution context.</param>
        /// <param name="service">The executing user's organisation service.</param>
        /// <param name="tracing">The current tracing service.</param>
        public PluginExecution(IPluginExecutionContext context, IOrganizationService service, ITracingService tracing)
        {
            this.Context = context ?? throw new ArgumentNullException(nameof(context));
            this.Service = service ?? throw new ArgumentNullException(nameof(service));
            this.Tracing = tracing ?? throw new ArgumentNullException(nameof(tracing));
        }

        /// <inheritdoc/>
        public IPluginExecutionContext Context { get; }

        /// <inheritdoc/>
        public IOrganizationService Service { get; }

        /// <inheritdoc/>
        public ITracingService Tracing { get; }
    }
}
