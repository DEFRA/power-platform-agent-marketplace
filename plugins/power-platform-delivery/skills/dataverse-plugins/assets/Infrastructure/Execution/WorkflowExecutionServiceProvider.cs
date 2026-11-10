namespace Abc.Infrastructure.Execution
{
    using System;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Workflow;

    /// <summary>
    /// Creates services for the identities a custom workflow activity host supports: the executing user, and the
    /// initiating user only when it is the same user. The host can't create a SYSTEM service.
    /// </summary>
    public sealed class WorkflowExecutionServiceProvider : IExecutionServiceProvider
    {
        private readonly IOrganizationServiceFactory factory;
        private readonly IWorkflowContext context;

        /// <summary>Initializes a new instance of the <see cref="WorkflowExecutionServiceProvider"/> class.</summary>
        /// <param name="factory">The current invocation's organisation service factory.</param>
        /// <param name="context">The current workflow execution context.</param>
        public WorkflowExecutionServiceProvider(IOrganizationServiceFactory factory, IWorkflowContext context)
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
            if (this.context.InitiatingUserId != this.context.UserId)
            {
                throw new NotSupportedException("This workflow host cannot request a service for a different initiating user.");
            }

            return this.GetExecutingUserService();
        }

        /// <inheritdoc/>
        public IOrganizationService GetSystemService()
        {
            throw new NotSupportedException("This workflow host cannot request a SYSTEM organisation service.");
        }

        private IOrganizationService CreateRequiredService(Guid userId)
        {
            return this.factory.CreateOrganizationService(userId)
                ?? throw new InvalidOperationException("The organisation service factory returned no service.");
        }
    }
}
