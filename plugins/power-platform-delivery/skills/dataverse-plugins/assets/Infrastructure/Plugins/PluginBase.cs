namespace Abc.Infrastructure.Plugins
{
    using System;
    using System.Runtime.ExceptionServices;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Execution;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.PluginTelemetry;

    /// <summary>
    /// The base class for plug-in entry points. Each call creates an execution scope from the composition root,
    /// registers the services Dataverse supplied, then resolves and runs the handler. It traces the handler's start,
    /// completion and failure, and wraps any exception other than <see cref="InvalidPluginExecutionException"/>.
    /// Dataverse caches and shares plug-in instances, so this class holds no per-invocation state.
    /// </summary>
    /// <typeparam name="THandler">The handler, registered in the composition root.</typeparam>
    public abstract class PluginBase<THandler> : IPlugin
        where THandler : IPluginHandler
    {
        private readonly PluginContainer root;
        private readonly PluginStepConfiguration configuration;

        /// <summary>Initializes a new instance of the <see cref="PluginBase{THandler}"/> class for steps without configuration.</summary>
        /// <param name="root">The composition root. It holds registrations only and is never an execution scope.</param>
        protected PluginBase(PluginContainer root)
            : this(root, null, null)
        {
        }

        /// <summary>Initializes a new instance of the <see cref="PluginBase{THandler}"/> class for steps with configuration.</summary>
        /// <param name="root">The composition root. It holds registrations only and is never an execution scope.</param>
        /// <param name="unsecureConfiguration">The step's unsecure configuration, as Dataverse supplied it.</param>
        /// <param name="secureConfiguration">The step's secure configuration, as Dataverse supplied it.</param>
        protected PluginBase(PluginContainer root, string unsecureConfiguration, string secureConfiguration)
        {
            this.root = root ?? throw new ArgumentNullException(nameof(root));
            this.configuration = new PluginStepConfiguration(unsecureConfiguration, secureConfiguration);
        }

        /// <summary>Resolves a new handler for this invocation and runs it.</summary>
        /// <param name="serviceProvider">The services Dataverse supplied.</param>
        public void Execute(IServiceProvider serviceProvider)
        {
            if (serviceProvider == null)
            {
                throw new ArgumentNullException(nameof(serviceProvider));
            }

            ITracingService tracing = null;
            try
            {
                tracing = GetRequiredService<ITracingService>(serviceProvider);
                ExecutionGuard.TraceWithoutMasking(tracing, "Starting handler {0}.", typeof(THandler).FullName);
                var scope = this.root.CreateExecutionScope();
                Exception executionFailure = null;
                try
                {
                    var context = GetRequiredService<IPluginExecutionContext>(serviceProvider);
                    var factory = GetRequiredService<IOrganizationServiceFactory>(serviceProvider);
                    var service = factory.CreateOrganizationService(context.UserId);
                    if (service == null)
                    {
                        throw new InvalidOperationException("The organisation service factory returned no service.");
                    }

                    scope.Register<IPluginExecutionContext>(context);
                    scope.Register<IOrganizationService>(service);
                    scope.Register<ITracingService>(tracing);
                    scope.Register<IOrganizationServiceFactory>(factory);
                    scope.Register<IPluginExecution>(new PluginExecution(context, service, tracing));
                    scope.Register<IExecutionServiceProvider>(new PluginExecutionServiceProvider(factory, context));
                    scope.Register<PluginStepConfiguration>(this.configuration);

                    // Dataverse supplies ILogger only when Application Insights integration is on. A handler that
                    // requires it fails to resolve without it.
                    var logger = serviceProvider.GetService(typeof(ILogger)) as ILogger;
                    if (logger != null)
                    {
                        scope.Register<ILogger>(logger);
                    }

                    scope.Resolve<THandler>().Execute();
                }
                catch (Exception exception)
                {
                    executionFailure = exception;
                }

                var failure = ExecutionGuard.DisposeScope(scope, executionFailure, tracing, "Cleanup after handler {0} failed: {1}", typeof(THandler).FullName);
                if (failure != null)
                {
                    ExceptionDispatchInfo.Capture(failure).Throw();
                }

                ExecutionGuard.TraceWithoutMasking(tracing, "Completed handler {0}.", typeof(THandler).FullName);
            }
            catch (InvalidPluginExecutionException exception)
            {
                ExecutionGuard.TraceWithoutMasking(tracing, "Handler {0} failed: {1}", typeof(THandler).FullName, exception);
                throw;
            }
            catch (Exception exception)
            {
                ExecutionGuard.TraceWithoutMasking(tracing, "Handler {0} failed: {1}", typeof(THandler).FullName, exception);
                throw new InvalidPluginExecutionException("The plug-in could not complete. See the plug-in trace log for details.", exception);
            }
        }

        private static TService GetRequiredService<TService>(IServiceProvider serviceProvider)
            where TService : class
        {
            var service = serviceProvider.GetService(typeof(TService)) as TService;
            if (service == null)
            {
                throw new InvalidOperationException("Dataverse did not provide " + typeof(TService).FullName + ".");
            }

            return service;
        }
    }
}
