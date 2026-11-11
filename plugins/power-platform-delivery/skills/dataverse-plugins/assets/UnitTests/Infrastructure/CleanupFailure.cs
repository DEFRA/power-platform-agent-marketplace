namespace Abc.UnitTests.Infrastructure
{
    using System;
    using Microsoft.Xrm.Sdk;

    // Shared by the plug-in and workflow cleanup tests: each double traces its disposal, then fails it.
    internal static class CleanupFailure
    {
        public const string HandlerName = "handler";

        public static InvalidPluginExecutionException BusinessFailure { get; } =
            new InvalidPluginExecutionException("business validation failed");

        public static string DisposedMessage(string name)
        {
            return "Disposed " + name;
        }

        public static string FailureMessage(string name)
        {
            return name + " cleanup failed";
        }

        public static void DisposeAndFail(ITracingService tracing, string name)
        {
            tracing.Trace(DisposedMessage(name));
            throw new InvalidOperationException(FailureMessage(name));
        }
    }
}
