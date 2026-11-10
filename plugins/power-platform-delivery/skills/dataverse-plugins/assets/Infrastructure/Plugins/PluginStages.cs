namespace Abc.Infrastructure.Plugins
{
    /// <summary>The event pipeline stages, as <c>IExecutionContext.Stage</c> reports them.</summary>
    public static class PluginStages
    {
        /// <summary>The pre-validation stage, which runs before the main transaction.</summary>
        public const int PreValidation = 10;

        /// <summary>The pre-operation stage, which runs in the transaction before the database operation.</summary>
        public const int PreOperation = 20;

        /// <summary>The post-operation stage, which runs after the database operation.</summary>
        public const int PostOperation = 40;
    }
}
