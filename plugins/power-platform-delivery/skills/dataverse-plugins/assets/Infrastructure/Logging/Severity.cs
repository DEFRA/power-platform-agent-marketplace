namespace Abc.Infrastructure.Logging
{
    /// <summary>The severity of a log message.</summary>
    public enum Severity
    {
        /// <summary>Detail that helps diagnose a problem.</summary>
        Verbose,

        /// <summary>A decision or event in the normal flow.</summary>
        Info,

        /// <summary>Something unexpected that the code handled.</summary>
        Warning,

        /// <summary>A failure.</summary>
        Error,
    }
}
