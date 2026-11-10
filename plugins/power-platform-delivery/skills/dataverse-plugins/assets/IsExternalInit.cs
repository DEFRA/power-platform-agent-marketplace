// Lets C# 9 and later `init` accessors and records compile on .NET Framework 4.8.
// Copy this file into the plug-in project once. It is internal, so each assembly carries its own copy.
namespace System.Runtime.CompilerServices
{
    using System.ComponentModel;

    /// <summary>
    /// Reserved for the compiler. Marks the return type of an <c>init</c> accessor.
    /// </summary>
    [EditorBrowsable(EditorBrowsableState.Never)]
    internal static class IsExternalInit
    {
    }
}
