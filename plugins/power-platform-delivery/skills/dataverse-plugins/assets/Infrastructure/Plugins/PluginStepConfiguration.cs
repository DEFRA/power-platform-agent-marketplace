namespace Abc.Infrastructure.Plugins
{
    /// <summary>
    /// The configuration registered on the current plug-in step, exactly as Dataverse passed it to the plug-in's
    /// constructor. Each execution scope can resolve it. A handler parses it on each invocation and passes the
    /// settings to the application service as an argument.
    /// </summary>
    public sealed class PluginStepConfiguration
    {
        /// <summary>Initializes a new instance of the <see cref="PluginStepConfiguration"/> class.</summary>
        /// <param name="unsecure">The step's unsecure configuration.</param>
        /// <param name="secure">The step's secure configuration.</param>
        public PluginStepConfiguration(string unsecure, string secure)
        {
            this.Unsecure = unsecure;
            this.Secure = secure;
        }

        /// <summary>Gets the step's unsecure configuration. It is null or empty when the step has none.</summary>
        public string Unsecure { get; }

        /// <summary>Gets the step's secure configuration. It is null or empty when the step has none. Never log it.</summary>
        public string Secure { get; }
    }
}
