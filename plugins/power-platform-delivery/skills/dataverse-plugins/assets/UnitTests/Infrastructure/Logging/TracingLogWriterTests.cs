namespace Abc.UnitTests.Infrastructure.Logging
{
    using System;
    using Abc.Infrastructure.DependencyInjection;
    using Abc.Infrastructure.Logging;
    using Abc.UnitTests.Support;
    using FluentAssertions;
    using Microsoft.VisualStudio.TestTools.UnitTesting;
    using Microsoft.Xrm.Sdk;

    [TestClass]
    public sealed class TracingLogWriterTests
    {
        private readonly RecordingTracingService tracing = new RecordingTracingService();

        [TestMethod]
        public void Constructor_NullTracingService_ThrowsArgumentNullException()
        {
            Action create = () => new TracingLogWriter(null);

            create.Should().ThrowExactly<ArgumentNullException>();
        }

        [TestMethod]
        public void Log_AnyMessage_PrefixesAnIsoTimestamp()
        {
            new TracingLogWriter(this.tracing).Log(Severity.Warning, "Tag", "Message");

            this.tracing.Messages.Should().ContainSingle()
                .Which.Should().MatchRegex(@"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z?: Tag: Warning: Message$");
        }

        [TestMethod]
        [DataRow(Severity.Verbose)]
        [DataRow(Severity.Info)]
        [DataRow(Severity.Warning)]
        [DataRow(Severity.Error)]
        public void Log_EachSeverity_NamesTheSeverity(Severity severity)
        {
            new TracingLogWriter(this.tracing).Log(severity, "Tag", "Message");

            this.tracing.Messages.Should().ContainSingle()
                .Which.Should().EndWith(": Tag: " + severity + ": Message");
        }

        [TestMethod]
        public void Log_MessageContainsBraces_TracesThemLiterally()
        {
            new TracingLogWriter(this.tracing).Log(Severity.Info, "Tag", "Value {0}");

            this.tracing.Messages.Should().ContainSingle()
                .Which.Should().EndWith(": Tag: Info: Value {0}");
        }

        [TestMethod]
        public void Type_HasExactlyOnePublicConstructorSoTheContainerCanResolveIt()
        {
            typeof(TracingLogWriter).GetConstructors().Should().ContainSingle();
        }

        [TestMethod]
        public void Resolve_RegisteredAsALogWriter_ReturnsItWithTheScopesTracingService()
        {
            using (var root = new PluginContainer())
            {
                root.Register<ILogWriter, TracingLogWriter>();
                using (var scope = root.CreateExecutionScope())
                {
                    scope.Register<ITracingService>(this.tracing);

                    scope.Resolve<ILogWriter>().Log(Severity.Info, "Tag", "Message");

                    this.tracing.Messages.Should().ContainSingle()
                        .Which.Should().EndWith(": Tag: Info: Message");
                }
            }
        }
    }
}
