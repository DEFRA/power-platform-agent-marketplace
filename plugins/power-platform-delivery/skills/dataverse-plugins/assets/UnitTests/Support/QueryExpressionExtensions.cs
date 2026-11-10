namespace Abc.UnitTests.Support
{
    using System.Collections.Generic;
    using System.Linq;
    using Microsoft.Xrm.Sdk.Query;

    internal static class QueryExpressionExtensions
    {
        // The early-bound LINQ provider nests combined where clauses in child filters, so tests read every condition.
        public static IReadOnlyList<ConditionExpression> GetAllConditions(this QueryExpression query)
        {
            return Flatten(query.Criteria).SelectMany(filter => filter.Conditions).ToList();
        }

        // True when every condition must hold, so no OR group can widen the match.
        public static bool UsesOnlyAndFilters(this QueryExpression query)
        {
            return Flatten(query.Criteria).All(filter => filter.FilterOperator == LogicalOperator.And);
        }

        private static IEnumerable<FilterExpression> Flatten(FilterExpression filter)
        {
            yield return filter;
            foreach (var child in filter.Filters.SelectMany(Flatten))
            {
                yield return child;
            }
        }
    }
}
