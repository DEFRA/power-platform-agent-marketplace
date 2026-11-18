Feature: Submit a case

    Scenario: Submitting a draft case allocates a case number
        Given I am logged in to the 'Case Management' app as 'CaseOfficer'
        And a draft case exists for an applicant
        When I submit the case
        Then the case has a case number starting with 'CAS-'

    Scenario: A case without an applicant cannot be submitted
        Given I am logged in to the 'Case Management' app as 'CaseOfficer'
        And a draft case exists with no applicant
        When I submit the case
        Then I am told that an applicant is required
