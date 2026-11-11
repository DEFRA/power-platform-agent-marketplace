namespace Abc.Infrastructure.Workflows
{
    using System;
    using System.Activities;
    using System.Runtime.ExceptionServices;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Execution;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Workflow;

    /// <summary>
    /// The base class for custom workflow activities. Each call creates an execution scope from the composition
    /// root, registers the services the workflow host supplied and the activity itself, then resolves and runs the
    /// handler. It traces the handler's completion and failure, and rethrows failures unchanged.
    /// </summary>
    /// <typeparam name="THandler">The handler, registered in the composition root.</typeparam>
    public abstract class WorkflowActivityBase<THandler> : CodeActivity
        where THandler : IWorkflowActivityHandler
    {
        private readonly PluginContainer root;

        /// <summary>Initializes a new instance of the <see cref="WorkflowActivityBase{THandler}"/> class.</summary>
        /// <param name="root">The composition root. It holds registrations only and is never an execution scope.</param>
        protected WorkflowActivityBase(PluginContainer root)
        {
            this.root = root ?? throw new ArgumentNullException(nameof(root));
        }

        /// <summary>
        /// Registers this activity instance in the current execution scope, so the handler can read its arguments.
        /// Implement it as <c>scope.Register&lt;MyActivity&gt;(this);</c>.
        /// </summary>
        /// <param name="scope">The current execution scope.</param>
        protected abstract void RegisterActivity(PluginContainer scope);

        /// <inheritdoc/>
        protected sealed override void Execute(CodeActivityContext context)
        {
            if (context == null)
            {
                throw new ArgumentNullException(nameof(context));
            }

            ITracingService tracing = null;
            PluginContainer scope = null;
            Exception executionFailure = null;
            try
            {
                var workflowContext = GetRequiredExtension<IWorkflowContext>(context);
                tracing = GetRequiredExtension<ITracingService>(context);
                var factory = GetRequiredExtension<IOrganizationServiceFactory>(context);
                var service = factory.CreateOrganizationService(workflowContext.UserId)
                    ?? throw new InvalidOperationException("The organisation service factory returned no service.");
                scope = this.root.CreateExecutionScope();
                scope.Register<CodeActivityContext>(context);
                scope.Register<IWorkflowContext>(workflowContext);
                scope.Register<IOrganizationServiceFactory>(factory);
                scope.Register<IOrganizationService>(service);
                scope.Register<ITracingService>(tracing);
                scope.Register<IExecutionServiceProvider>(new WorkflowExecutionServiceProvider(factory, workflowContext));
                this.RegisterActivity(scope);
                scope.Resolve<THandler>().Execute();
            }
            catch (Exception exception)
            {
                executionFailure = exception;
            }

            var failure = ExecutionGuard.DisposeScope(scope, executionFailure, tracing, "Workflow handler {0} cleanup failed: {1}", typeof(THandler).FullName);
            if (failure != null)
            {
                ExecutionGuard.TraceWithoutMasking(tracing, "Workflow handler {0} failed: {1}", typeof(THandler).FullName, failure);
                ExceptionDispatchInfo.Capture(failure).Throw();
            }

            ExecutionGuard.TraceWithoutMasking(tracing, "Completed workflow handler {0}.", typeof(THandler).FullName);
        }

        private static TExtension GetRequiredExtension<TExtension>(CodeActivityContext context)
            where TExtension : class
        {
            var extension = context.GetExtension<TExtension>();
            if (extension == null)
            {
                throw new InvalidOperationException("The workflow host did not provide " + typeof(TExtension).FullName + ".");
            }

            return extension;
        }
    }
}
