namespace Abc.UnitTests.Infrastructure
{
    using System;
    using Microsoft.Xrm.Sdk;

    internal sealed class FirstCleanupService : IDisposable
    {
        public const string Name = "first";

        private readonly ITracingService tracing;

        public FirstCleanupService(ITracingService tracing)
        {
            this.tracing = tracing;
        }

        public void Dispose()
        {
            CleanupFailure.DisposeAndFail(this.tracing, Name);
        }
    }
}
