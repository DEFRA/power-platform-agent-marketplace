namespace Abc.UnitTests.Support
{
    using System;
    using System.Collections.Generic;
    using System.Globalization;
    using Microsoft.Xrm.Sdk;

    // Records each traced message, formatted as Dataverse would, for assertions.
    public sealed class RecordingTracingService : ITracingService
    {
        private readonly object gate = new object();
        private readonly List<string> messages = new List<string>();
        private string failingPrefix;

        public IReadOnlyList<string> Messages
        {
            get
            {
                lock (this.gate)
                {
                    return this.messages.ToArray();
                }
            }
        }

        // Records the message before throwing so tests can prove the attempt was made.
        public void ThrowWhenMessageStartsWith(string prefix)
        {
            this.failingPrefix = prefix;
        }

        public void Trace(string format, params object[] args)
        {
            var message = args == null || args.Length == 0
                ? format
                : string.Format(CultureInfo.InvariantCulture, format, args);

            lock (this.gate)
            {
                this.messages.Add(message);
            }

            if (this.failingPrefix != null && message.StartsWith(this.failingPrefix, StringComparison.Ordinal))
            {
                throw new InvalidOperationException("Tracing failed.");
            }
        }
    }
}
