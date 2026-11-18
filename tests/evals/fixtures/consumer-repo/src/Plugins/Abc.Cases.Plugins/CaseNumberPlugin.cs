using System;
using Microsoft.Xrm.Sdk;

namespace Abc.Cases.Plugins
{
    /// <summary>Pre-update step on abc_case. Allocates the next case number when a Case is submitted.</summary>
    public class CaseNumberPlugin : IPlugin
    {
        private const int Submitted = 3;

        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var target = (Entity)context.InputParameters["Target"];

            var status = target.GetAttributeValue<OptionSetValue>("abc_status");
            if (status == null || status.Value != Submitted)
            {
                return;
            }

            var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = factory.CreateOrganizationService(null);

            var next = CaseNumberSequence.Next(service);
            target["abc_casenumber"] = CaseNumberSequence.Format(next);
        }
    }
}
