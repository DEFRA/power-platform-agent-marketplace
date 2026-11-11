namespace Abc.Infrastructure.Execution
{
    using System;
    using Microsoft.Xrm.Sdk;

    /// <summary>
    /// The failure rules that <c>PluginBase</c> and <c>WorkflowActivityBase</c> share: diagnostics and cleanup must
    /// never replace the failure that matters.
    /// </summary>
    public static class ExecutionGuard
    {
        /// <summary>Writes a trace message and swallows any failure of the tracing service itself.</summary>
        /// <param name="tracing">The tracing service, or null when the host supplied none.</param>
        /// <param name="format">The trace format.</param>
        /// <param name="args">The trace arguments.</param>
        public static void TraceWithoutMasking(ITracingService tracing, string format, params object[] args)
        {
            if (tracing == null)
            {
                return;
            }

            try
            {
                tracing.Trace(format, args);
            }
            catch (Exception)
            {
                // Diagnostics must not replace an execution or cleanup failure.
            }
        }

        /// <summary>
        /// Disposes an execution scope and returns the failure to report. An execution failure always wins, and a
        /// cleanup failure that it hides is traced. Without an execution failure, the cleanup failure is returned.
        /// </summary>
        /// <param name="scope">The execution scope, or null when it was never created.</param>
        /// <param name="executionFailure">The failure of the handler or of setting it up, if any.</param>
        /// <param name="tracing">The tracing service, or null when the host supplied none.</param>
        /// <param name="cleanupFailureFormat">The trace format for a hidden cleanup failure: {0} is the handler name and {1} the failure.</param>
        /// <param name="handlerName">The handler's name.</param>
        /// <returns>The failure to report, or null when there was none.</returns>
        public static Exception DisposeScope(
            IDisposable scope,
            Exception executionFailure,
            ITracingService tracing,
            string cleanupFailureFormat,
            string handlerName)
        {
            if (scope == null)
            {
                return executionFailure;
            }

            try
            {
                scope.Dispose();
            }
            catch (Exception cleanupFailure)
            {
                if (executionFailure == null)
                {
                    return cleanupFailure;
                }

                TraceWithoutMasking(tracing, cleanupFailureFormat, handlerName, cleanupFailure);
            }

            return executionFailure;
        }
    }
}
