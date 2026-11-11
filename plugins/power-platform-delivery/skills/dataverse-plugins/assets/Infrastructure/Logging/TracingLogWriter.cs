namespace Abc.Infrastructure.Logging
{
    using System;
    using System.Globalization;
    using Microsoft.Xrm.Sdk;

    /// <summary>
    /// Writes timestamped messages to the plug-in trace log. It has exactly one public constructor, as
    /// <see cref="DependencyInjection.PluginContainer"/> requires.
    /// </summary>
    public sealed class TracingLogWriter : ILogWriter
    {
        private readonly ITracingService tracing;

        /// <summary>Initializes a new instance of the <see cref="TracingLogWriter"/> class.</summary>
        /// <param name="tracing">The current invocation's tracing service.</param>
        public TracingLogWriter(ITracingService tracing)
        {
            this.tracing = tracing ?? throw new ArgumentNullException(nameof(tracing));
        }

        /// <inheritdoc/>
        public void Log(Severity severity, string tag, string message)
        {
            // The message is an argument, not the format, so braces in it can't break formatting.
            this.tracing.Trace(
                "{0}: {1}: {2}: {3}",
                DateTime.UtcNow.ToString("o", CultureInfo.InvariantCulture),
                tag,
                severity,
                message);
        }
    }
}
