using System;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace Abc.Cases.Plugins
{
    public static class CaseNumberSequence
    {
        private static readonly Guid SequenceId = new Guid("00000000-0000-0000-0000-000000000001");

        public static int Next(IOrganizationService service)
        {
            var sequence = service.Retrieve("abc_sequence", SequenceId, new ColumnSet("abc_value"));
            var value = sequence.GetAttributeValue<int>("abc_value") + 1;
            sequence["abc_value"] = value;
            service.Update(sequence);
            return value;
        }

        public static string Format(int value)
        {
            return "CAS-" + value.ToString("D6");
        }
    }
}
