namespace Abc.Infrastructure.Logging
{
    /// <summary>Writes diagnostic messages for the current invocation.</summary>
    public interface ILogWriter
    {
        /// <summary>Writes a message to the log.</summary>
        /// <param name="severity">The severity of the message.</param>
        /// <param name="tag">Where the message comes from, usually the name of the calling class.</param>
        /// <param name="message">The message. It is written as text, never used as a format string.</param>
        void Log(Severity severity, string tag, string message);
    }
}
