namespace Abc.UnitTests.Infrastructure
{
    using System;
    using Microsoft.Xrm.Sdk;

    internal sealed class SecondCleanupService : IDisposable
    {
        public const string Name = "second";

        private readonly ITracingService tracing;

        public SecondCleanupService(ITracingService tracing)
        {
            this.tracing = tracing;
        }

        public void Dispose()
        {
            CleanupFailure.DisposeAndFail(this.tracing, Name);
        }
    }
}
