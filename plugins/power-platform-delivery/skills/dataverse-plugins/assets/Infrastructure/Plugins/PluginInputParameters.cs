namespace Abc.Infrastructure.Plugins
{
    /// <summary>The names of the input parameters that plug-in handlers read.</summary>
    public static class PluginInputParameters
    {
        /// <summary>The entity or entity reference the message acts on.</summary>
        public const string Target = "Target";

        /// <summary>The reference to the record whose state a SetState message changes.</summary>
        public const string EntityMoniker = "EntityMoniker";
    }
}
