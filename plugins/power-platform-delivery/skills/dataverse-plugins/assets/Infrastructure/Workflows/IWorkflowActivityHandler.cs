namespace Abc.Infrastructure.Workflows
{
    /// <summary>A custom workflow activity use case. The container builds it, with its dependencies, for each invocation.</summary>
    public interface IWorkflowActivityHandler
    {
        /// <summary>Runs the use case for the current invocation.</summary>
        void Execute();
    }
}
