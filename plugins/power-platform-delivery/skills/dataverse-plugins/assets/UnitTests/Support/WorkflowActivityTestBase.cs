namespace Abc.UnitTests.Support
{
    using System;
    using System.Activities;
    using System.Collections.Generic;
    using FluentAssertions;

    // Base class for tests of CodeActivity entry points. It supplies a simulated workflow host and the
    // assertions most activity tests need, so derived tests describe only the activity's contract.
    public abstract class WorkflowActivityTestBase<TActivity>
        where TActivity : CodeActivity, new()
    {
        protected WorkflowRuntime Runtime { get; } = new WorkflowRuntime();

        protected TActivity Activity { get; } = new TActivity();

        protected IDictionary<string, object> Invoke(string inputName, object input)
        {
            return this.Runtime.Invoke(this.Activity, inputName, input);
        }

        protected IDictionary<string, object> Invoke(IDictionary<string, object> inputs)
        {
            return this.Runtime.Invoke(this.Activity, inputs);
        }

        // Hosts may wrap failures, so the expected exception is searched for among the inner exceptions.
        // The strict service mock proves nothing was read or written.
        protected void AssertInvokeFailsWithoutCallingService<TInner>(string inputName, object input)
            where TInner : Exception
        {
            this.AssertInvokeFailsWithoutCallingService<TInner>(new Dictionary<string, object> { { inputName, input } });
        }

        protected void AssertInvokeFailsWithoutCallingService<TInner>(IDictionary<string, object> inputs)
            where TInner : Exception
        {
            Action invoke = () => this.Invoke(inputs);

            var exception = invoke.Should().Throw<Exception>().Which;

            exception.Flatten().Should().Contain(inner => inner is TInner);
            this.Runtime.Service.VerifyNoOtherCalls();
        }
    }
}
