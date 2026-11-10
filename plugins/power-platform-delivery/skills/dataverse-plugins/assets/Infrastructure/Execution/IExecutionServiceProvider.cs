namespace Abc.Infrastructure.Execution
{
    using Microsoft.Xrm.Sdk;

    /// <summary>Creates organisation services for the identities the current host supports.</summary>
    public interface IExecutionServiceProvider
    {
        /// <summary>Creates a service for the user the step or process runs as.</summary>
        /// <returns>A service running as the executing user.</returns>
        IOrganizationService GetExecutingUserService();

        /// <summary>Creates a service for the user who started the operation, when the host supports it.</summary>
        /// <returns>A service running as the initiating user.</returns>
        IOrganizationService GetInitiatingUserService();

        /// <summary>Creates a service running as SYSTEM, when the host supports it.</summary>
        /// <returns>A service running as SYSTEM.</returns>
        IOrganizationService GetSystemService();
    }
}
