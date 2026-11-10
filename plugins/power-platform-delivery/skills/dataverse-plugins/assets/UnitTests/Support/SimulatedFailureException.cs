namespace Abc.UnitTests.Support
{
    using System;

    // A distinctive exception type, so tests can tell a simulated failure from one raised by the code under test.
    internal sealed class SimulatedFailureException : Exception
    {
        public SimulatedFailureException(string message)
            : base(message)
        {
        }
    }
}
