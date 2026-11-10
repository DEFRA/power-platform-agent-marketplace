namespace Abc.UnitTests.Support
{
    using System.Collections.Generic;
    using System.Linq;
    using Microsoft.Xrm.Sdk;
    using Microsoft.Xrm.Sdk.Messages;
    using Microsoft.Xrm.Sdk.Query;
    using Moq;

    internal static class OrganizationServiceMockExtensions
    {
        // The early-bound LINQ provider issues RetrieveMultipleRequest through Execute, not RetrieveMultiple.
        // Supplying no records simulates a query that matches nothing. The returned list records each query
        // for the table, so tests can assert what was asked for. Return early-bound entities when the code
        // under test reads typed properties.
        public static IList<QueryExpression> ReturnsRecords(
            this Mock<IOrganizationService> service, string logicalName, params Entity[] records)
        {
            var queries = new List<QueryExpression>();
            var response = CreateResponse(logicalName, records);

            service
                .Setup(value => value.Execute(It.Is<OrganizationRequest>(request => IsFor(request, logicalName))))
                .Callback<OrganizationRequest>(request => queries.Add((QueryExpression)((RetrieveMultipleRequest)request).Query))
                .Returns(response);
            return queries;
        }

        // Returns each set of records in turn, one per query for the table, so a test can supply different results to
        // successive reads of the same table. A further query than there are sets fails the test.
        public static IList<QueryExpression> ReturnsRecordsInSequence(
            this Mock<IOrganizationService> service, string logicalName, params Entity[][] sets)
        {
            var queries = new List<QueryExpression>();
            var responses = new Queue<OrganizationResponse>(sets.Select(records => CreateResponse(logicalName, records)));

            service
                .Setup(value => value.Execute(It.Is<OrganizationRequest>(request => IsFor(request, logicalName))))
                .Callback<OrganizationRequest>(request => queries.Add((QueryExpression)((RetrieveMultipleRequest)request).Query))
                .Returns(() => responses.Dequeue());
            return queries;
        }

        // Counts the queries sent for a table.
        public static void VerifyQueried(this Mock<IOrganizationService> service, string logicalName, Times times)
        {
            service.Verify(value => value.Execute(It.Is<OrganizationRequest>(request => IsFor(request, logicalName))), times);
        }

        // Counts all queries sent, whichever table they were for.
        public static void VerifyQueriedAny(this Mock<IOrganizationService> service, Times times)
        {
            service.Verify(value => value.Execute(It.IsAny<RetrieveMultipleRequest>()), times);
        }

        private static OrganizationResponse CreateResponse(string logicalName, Entity[] records)
        {
            return new RetrieveMultipleResponse
            {
                Results = new ParameterCollection
                {
                    { "EntityCollection", new EntityCollection(records.ToList()) { EntityName = logicalName } },
                },
            };
        }

        private static bool IsFor(OrganizationRequest request, string logicalName)
        {
            return request is RetrieveMultipleRequest retrieve
                && retrieve.Query is QueryExpression expression
                && expression.EntityName == logicalName;
        }
    }
}
