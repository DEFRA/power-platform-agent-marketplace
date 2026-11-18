using Reqnroll;

namespace Abc.Cases.Acceptance.Steps
{
    [Binding]
    public class CaseSteps
    {
        [Given(@"I am logged in to the '(.*)' app as '(.*)'")]
        public void GivenIAmLoggedInToTheAppAs(string app, string persona) { }

        [Given(@"a draft case exists for an applicant")]
        public void GivenADraftCaseExistsForAnApplicant() { }

        [Given(@"a draft case exists with no applicant")]
        public void GivenADraftCaseExistsWithNoApplicant() { }

        [When(@"I submit the case")]
        public void WhenISubmitTheCase() { }

        [Then(@"the case has a case number starting with '(.*)'")]
        public void ThenTheCaseHasACaseNumberStartingWith(string prefix) { }

        [Then(@"I am told that an applicant is required")]
        public void ThenIAmToldThatAnApplicantIsRequired() { }
    }
}
