namespace Abc.UnitTests.Infrastructure.Execution
{
    using System;
    using Abc.Infrastructure.Execution;
    using Abc.UnitTests.Support;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;

    [TestClass]
    public sealed class ExecutionGuardTests
    {
        private const string CleanupFormat = "Cleanup of {0} failed: {1}";
        private const string HandlerName = "Handler";

        private readonly RecordingTracingService tracing = new RecordingTracingService();

        [TestMethod]
        public void TraceWithoutMasking_NoTracingService_DoesNothing()
        {
            Action trace = () => ExecutionGuard.TraceWithoutMasking(null, "Message");

            trace.Should().NotThrow();
        }

        [TestMethod]
        public void TraceWithoutMasking_TracingFails_DoesNotThrow()
        {
            this.tracing.ThrowWhenMessageStartsWith("Message");

            Action trace = () => ExecutionGuard.TraceWithoutMasking(this.tracing, "Message {0}", 1);

            trace.Should().NotThrow();
            this.tracing.Messages.Should().Equal("Message 1");
        }

        [TestMethod]
        public void DisposeScope_NoScope_ReturnsTheExecutionFailure()
        {
            var failure = new SimulatedFailureException("Execution");

            var result = ExecutionGuard.DisposeScope(null, failure, this.tracing, CleanupFormat, HandlerName);

            result.Should().BeSameAs(failure);
        }

        [TestMethod]
        public void DisposeScope_NothingFails_DisposesTheScopeAndReturnsNull()
        {
            var scope = new Scope(null);

            var result = ExecutionGuard.DisposeScope(scope, null, this.tracing, CleanupFormat, HandlerName);

            result.Should().BeNull();
            scope.Disposed.Should().BeTrue();
        }

        [TestMethod]
        public void DisposeScope_OnlyCleanupFails_ReturnsTheCleanupFailure()
        {
            var cleanupFailure = new SimulatedFailureException("Cleanup");

            var result = ExecutionGuard.DisposeScope(new Scope(cleanupFailure), null, this.tracing, CleanupFormat, HandlerName);

            result.Should().BeSameAs(cleanupFailure);
            this.tracing.Messages.Should().BeEmpty();
        }

        [TestMethod]
        public void DisposeScope_ExecutionAndCleanupBothFail_ReturnsExecutionFailureAndTracesCleanupFailure()
        {
            var failure = new SimulatedFailureException("Execution");
            var cleanupFailure = new SimulatedFailureException("Cleanup");

            var result = ExecutionGuard.DisposeScope(new Scope(cleanupFailure), failure, this.tracing, CleanupFormat, HandlerName);

            result.Should().BeSameAs(failure);
            this.tracing.Messages.Should().ContainSingle().Which.Should().StartWith("Cleanup of Handler failed: ").And.Contain("Cleanup");
        }

        [TestMethod]
        public void DisposeScope_ExecutionAndCleanupBothFailAndTracingFails_StillReturnsExecutionFailure()
        {
            var failure = new SimulatedFailureException("Execution");
            this.tracing.ThrowWhenMessageStartsWith("Cleanup of");

            var result = ExecutionGuard.DisposeScope(new Scope(new SimulatedFailureException("Cleanup")), failure, this.tracing, CleanupFormat, HandlerName);

            result.Should().BeSameAs(failure);
        }

        private sealed class Scope : IDisposable
        {
            private readonly Exception disposeFailure;

            public Scope(Exception disposeFailure)
            {
                this.disposeFailure = disposeFailure;
            }

            public bool Disposed { get; private set; }

            public void Dispose()
            {
                this.Disposed = true;
                if (this.disposeFailure != null)
                {
                    throw this.disposeFailure;
                }
            }
        }
    }
}
