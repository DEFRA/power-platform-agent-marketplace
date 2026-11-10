namespace Abc.Infrastructure.Plugins
{
    /// <summary>A plug-in use case. The container builds it, with its dependencies, for each invocation.</summary>
    public interface IPluginHandler
    {
        /// <summary>Runs the use case for the current invocation.</summary>
        void Execute();
    }
}
