# Base classes and logger

Use the project's own plug-in base class, CWA base class and logger. Don't rename them or replace them. This page says what they must provide, and gives a minimal sketch to propose **only when the project has none**. The human approves it before you add it.

## What they must provide

**Logger** (an interface the business logic depends on, so tests can substitute it):

- Writes informational messages and errors with their exception to the plug-in trace log.
- Is backed by `ITracingService`. It passes the message as a format argument (`Trace("{0}", message)`) so braces in it can't throw.
- Is the only way business logic writes diagnostics.

**Plug-in base class** (`IPlugin`):

- Takes the step's unsecure and secure configuration in a `(string, string)` constructor and exposes them to the derived class. The platform passes `null` when a step has none.
- Resolves `ITracingService`, `IPluginExecutionContext` and `IOrganizationServiceFactory` once for each execution and creates the organisation service for the context's user.
- Traces entry (message, table, stage, depth) and failure.
- Rethrows `InvalidPluginExecutionException` as is, and wraps any other exception in one whose message points at the trace log.
- Is stateless, and calls one abstract method with a context object.

**CWA base class** (`CodeActivity`):

- Does the same for `CodeActivityContext`: resolves `ITracingService`, `IWorkflowContext` and `IOrganizationServiceFactory`, creates the service for the workflow's user, traces failure, and calls one abstract method.
- Is stateless.

## Minimal sketch

Namespace and names are placeholders. Adopt the project's. It compiles on .NET Framework 4.8 with C# 13 and is used by both worked examples.

```csharp
namespace Abc.Plugins;

public interface IPluginLogger
{
    void Info(string message);

    void Error(string message, Exception exception);
}

public sealed class TracingLogger : IPluginLogger
{
    private readonly ITracingService tracing;

    public TracingLogger(ITracingService tracing)
    {
        this.tracing = tracing ?? throw new ArgumentNullException(nameof(tracing));
    }

    public void Info(string message) => this.tracing.Trace("{0}", message);

    public void Error(string message, Exception exception) => this.tracing.Trace("{0}: {1}", message, exception);
}
```

```csharp
namespace Abc.Plugins;

public sealed class PluginContext
{
    public PluginContext(
        IPluginExecutionContext execution,
        IOrganizationService organizationService,
        IPluginLogger logger,
        string unsecureConfig,
        string secureConfig)
    {
        this.Execution = execution;
        this.OrganizationService = organizationService;
        this.Logger = logger;
        this.UnsecureConfig = unsecureConfig;
        this.SecureConfig = secureConfig;
    }

    public IPluginExecutionContext Execution { get; }

    public IOrganizationService OrganizationService { get; }

    public IPluginLogger Logger { get; }

    public string UnsecureConfig { get; }

    public string SecureConfig { get; } // Never log it.
}

public abstract class PluginBase : IPlugin
{
    private readonly string unsecureConfig;
    private readonly string secureConfig;

    protected PluginBase(string unsecureConfig, string secureConfig)
    {
        this.unsecureConfig = unsecureConfig;
        this.secureConfig = secureConfig;
    }

    public void Execute(IServiceProvider serviceProvider)
    {
        if (serviceProvider is null)
        {
            throw new ArgumentNullException(nameof(serviceProvider));
        }

        var logger = new TracingLogger((ITracingService)serviceProvider.GetService(typeof(ITracingService)));
        var execution = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
        var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
        var name = this.GetType().Name;

        logger.Info($"{name}: {execution.MessageName} on {execution.PrimaryEntityName}, stage {execution.Stage}, depth {execution.Depth}.");

        try
        {
            var service = factory.CreateOrganizationService(execution.UserId);
            this.ExecutePlugin(new PluginContext(execution, service, logger, this.unsecureConfig, this.secureConfig));
        }
        catch (InvalidPluginExecutionException exception)
        {
            logger.Error($"{name} failed.", exception);
            throw;
        }
        catch (Exception exception)
        {
            logger.Error($"{name} failed unexpectedly.", exception);
            throw new InvalidPluginExecutionException($"{name} failed. See the plug-in trace log.", exception);
        }
    }

    protected abstract void ExecutePlugin(PluginContext context);
}
```

```csharp
namespace Abc.Plugins;

public abstract class WorkflowActivityBase : CodeActivity
{
    protected abstract void ExecuteActivity(
        CodeActivityContext context,
        IWorkflowContext workflowContext,
        IOrganizationService service,
        IPluginLogger logger);

    protected sealed override void Execute(CodeActivityContext context)
    {
        var logger = new TracingLogger(context.GetExtension<ITracingService>());
        var workflowContext = context.GetExtension<IWorkflowContext>();
        var factory = context.GetExtension<IOrganizationServiceFactory>();
        var name = this.GetType().Name;

        try
        {
            this.ExecuteActivity(context, workflowContext, factory.CreateOrganizationService(workflowContext.UserId), logger);
        }
        catch (InvalidPluginExecutionException exception)
        {
            logger.Error($"{name} failed.", exception);
            throw;
        }
        catch (Exception exception)
        {
            logger.Error($"{name} failed unexpectedly.", exception);
            throw new InvalidPluginExecutionException($"{name} failed. See the plug-in trace log.", exception);
        }
    }
}
```

The `using` directives are `System`, `System.Activities`, `Microsoft.Xrm.Sdk` and `Microsoft.Xrm.Sdk.Workflow`.
