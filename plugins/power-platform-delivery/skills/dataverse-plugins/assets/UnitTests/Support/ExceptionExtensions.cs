namespace Abc.UnitTests.Support
{
    using System;
    using System.Collections.Generic;

    internal static class ExceptionExtensions
    {
        // Hosts such as the workflow runtime may wrap failures, so tests search the whole exception tree.
        public static IEnumerable<Exception> Flatten(this Exception exception)
        {
            yield return exception;

            var aggregate = exception as AggregateException;
            if (aggregate != null)
            {
                foreach (var inner in aggregate.InnerExceptions)
                {
                    foreach (var nested in inner.Flatten())
                    {
                        yield return nested;
                    }
                }
            }

            if (exception.InnerException != null)
            {
                foreach (var nested in exception.InnerException.Flatten())
                {
                    yield return nested;
                }
            }
        }
    }
}
