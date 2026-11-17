using FluentAssertions;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Abc.Cases.Plugins.Tests
{
    [TestClass]
    public class CaseNumberSequenceTests
    {
        [TestMethod]
        public void Format_PadsTheSequenceToSixDigits()
        {
            CaseNumberSequence.Format(42).Should().Be("CAS-000042");
        }
    }
}
