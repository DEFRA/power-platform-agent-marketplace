namespace Abc.Infrastructure.Execution
{
    using System;
    using Microsoft.Xrm.Sdk;

    /// <summary>Creates identity-specific services from a plug-in invocation's service factory.</summary>
    public sealed class PluginExecutionServiceProvider : IExecutionServiceProvider
    {
        private readonly IOrganizationServiceFactory factory;
        private readonly IPluginExecutionContext context;

        /// <summary>Initializes a new instance of the <see cref="PluginExecutionServiceProvider"/> class.</summary>
        /// <param name="factory">The current invocation's organisation service factory.</param>
        /// <param name="context">The current plug-in execution context.</param>
        public PluginExecutionServiceProvider(IOrganizationServiceFactory factory, IPluginExecutionContext context)
        {
            this.factory = factory ?? throw new ArgumentNullException(nameof(factory));
            this.context = context ?? throw new ArgumentNullException(nameof(context));
        }

        /// <inheritdoc/>
        public IOrganizationService GetExecutingUserService()
        {
            return this.CreateRequiredService(this.context.UserId);
        }

        /// <inheritdoc/>
        public IOrganizationService GetInitiatingUserService()
        {
            return this.CreateRequiredService(this.context.InitiatingUserId);
        }

        /// <inheritdoc/>
        public IOrganizationService GetSystemService()
        {
            return this.CreateRequiredService(null);
        }

        private IOrganizationService CreateRequiredService(Guid? userId)
        {
            return this.factory.CreateOrganizationService(userId)
                ?? throw new InvalidOperationException("The organisation service factory returned no service.");
        }
    }
}
